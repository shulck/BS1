import SwiftUI
import Charts

struct FinancesView: View {
    @StateObject private var service = FinanceService.shared
    @State private var showAdd = false
    @State private var showScanner = false
    @State private var showChart = false
    @State private var scannedText = ""
    @State private var extractedFinanceRecord: FinanceRecord?

    // Состояния для фильтрации
    @State private var showFilter = false
    @State private var filterType: FilterType = .all
    @State private var filterPeriod: FilterPeriod = .allTime

    // Перечисления для фильтрации
    enum FilterType: String, CaseIterable {
        case all = "Все"
        case income = "Доходы"
        case expense = "Расходы"
    }

    enum FilterPeriod: String, CaseIterable {
        case allTime = "Всё время"
        case thisMonth = "Текущий месяц"
        case last3Months = "3 месяца"
        case thisYear = "Текущий год"
    }

    // Отфильтрованные записи
    private var filteredRecords: [FinanceRecord] {
        let filtered = service.records

        // Фильтрация по типу
        let typeFiltered = filtered.filter { record in
            switch filterType {
            case .all: return true
            case .income: return record.type == .income
            case .expense: return record.type == .expense
            }
        }

        // Фильтрация по периоду
        return typeFiltered.filter { record in
            let calendar = Calendar.current
            let now = Date()
            let recordDate = record.date

            switch filterPeriod {
            case .allTime:
                return true
            case .thisMonth:
                let components = calendar.dateComponents([.year, .month], from: now)
                let startOfMonth = calendar.date(from: components)!
                return recordDate >= startOfMonth
            case .last3Months:
                let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now)!
                return recordDate >= threeMonthsAgo
            case .thisYear:
                let components = calendar.dateComponents([.year], from: now)
                let startOfYear = calendar.date(from: components)!
                return recordDate >= startOfYear
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Сводная секция
                summarySection

                // Секция фильтрации
                filterSection

                // Список транзакций с улучшенным дизайном
                transactionListSection
            }
            .navigationTitle("Финансы")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Кнопка сканера чеков
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "doc.text.viewfinder")
                    }

                    // Кнопка графика
                    Button {
                        showChart.toggle()
                    } label: {
                        Image(systemName: "chart.bar")
                    }

                    // Кнопка добавления транзакции
                    Button {
                        showAdd = true
                    } label: {
                        Label("Добавить", systemImage: "plus")
                    }
                }
            }
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    service.fetch(for: groupId)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddTransactionView()
            }
            .sheet(isPresented: $showScanner) {
                ReceiptScannerView(recognizedText: $scannedText, extractedFinanceRecord: $extractedFinanceRecord)
            }
            .sheet(isPresented: $showChart) {
                FinanceChartView(records: filteredRecords)
            }
        }
    }

    // Улучшенная секция сводной статистики
    private var summarySection: some View {
        VStack(spacing: 0) {
            // Информационная панель с общими данными
            HStack(spacing: 20) {
                // Доходы
                VStack(spacing: 8) {
                    Text("Доходы")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("+\(Int(totalIncome))")
                        .font(.title3.bold())
                        .foregroundColor(.green)

                    // Небольшая визуализация доходов
                    Capsule()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 60, height: 4)
                        .overlay(
                            Capsule()
                                .fill(Color.green)
                                .frame(width: totalIncome > 0 ? min(60, 60 * CGFloat(totalIncome / (totalIncome + totalExpense))) : 0, height: 4),
                            alignment: .leading
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.05))
                .cornerRadius(10)

                // Расходы
                VStack(spacing: 8) {
                    Text("Расходы")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("-\(Int(totalExpense))")
                        .font(.title3.bold())
                        .foregroundColor(.red)

                    // Небольшая визуализация расходов
                    Capsule()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 60, height: 4)
                        .overlay(
                            Capsule()
                                .fill(Color.red)
                                .frame(width: totalExpense > 0 ? min(60, 60 * CGFloat(totalExpense / (totalIncome + totalExpense))) : 0, height: 4),
                            alignment: .leading
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.05))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 10)

            Divider()
                .padding(.horizontal)
                .padding(.top, 10)

            // Итоговая прибыль
            HStack {
                Text("Прибыль")
                    .font(.headline)
                Spacer()
                Text("\(Int(profit))")
                    .font(.headline)
                    .foregroundColor(profit >= 0 ? .green : .red)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(profit >= 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    )
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            // Мини-график изменения баланса
            if !filteredRecords.isEmpty {
                let balanceHistory = calculateBalanceHistory()

                HStack {
                    Text("Динамика баланса")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Динамика в процентах
                    if balanceHistory.count > 1 {
                        let change = balanceHistory.last! - balanceHistory.first!
                        let percentage = balanceHistory.first! != 0 ? (change / abs(balanceHistory.first!)) * 100 : 0

                        Text(percentage >= 0 ? "+\(Int(percentage))%" : "\(Int(percentage))%")
                            .font(.caption)
                            .foregroundColor(percentage >= 0 ? .green : .red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(percentage >= 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 5)

                GeometryReader { geometry in
                    Path { path in
                        guard balanceHistory.count > 1 else { return }

                        let width = geometry.size.width
                        let height = geometry.size.height - 5

                        // Находим минимальное и максимальное значение для масштабирования
                        let minValue = balanceHistory.min() ?? 0
                        let maxValue = balanceHistory.max() ?? 0
                        let range = max(1.0, maxValue - minValue) // избегаем деления на ноль

                        // Начальная точка графика
                        let firstX: CGFloat = 0
                        let firstY = height - (CGFloat(balanceHistory[0] - minValue) / CGFloat(range)) * height
                        path.move(to: CGPoint(x: firstX, y: firstY))

                        // Рисуем линию графика
                        for i in 1..<balanceHistory.count {
                            let x = width * CGFloat(i) / CGFloat(balanceHistory.count - 1)
                            let y = height - (CGFloat(balanceHistory[i] - minValue) / CGFloat(range)) * height
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [profit >= 0 ? .green : .red, .blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                }
                .frame(height: 30)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }

            Divider()
        }
        .background(Color.gray.opacity(0.05))
    }

    // Улучшенная секция фильтрации
    private var filterSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut) {
                    showFilter.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .foregroundColor(filterType != .all || filterPeriod != .allTime ? .blue : .gray)

                    Text("Фильтр")
                        .font(.subheadline)

                    if filterType != .all || filterPeriod != .allTime {
                        Text("активен")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.1))
                            )
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    Image(systemName: showFilter ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .buttonStyle(PlainButtonStyle())

            if showFilter {
                VStack(spacing: 12) {
                    // Тип транзакции
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Тип:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("", selection: $filterType) {
                            ForEach(FilterType.allCases, id: \.self) { type in
                                HStack {
                                    Circle()
                                        .fill(type == .income ? Color.green : type == .expense ? Color.red : Color.gray)
                                        .frame(width: 8, height: 8)
                                    Text(type.rawValue).tag(type)
                                }
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Период
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Период:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            ForEach(FilterPeriod.allCases, id: \.self) { period in
                                Button {
                                    filterPeriod = period
                                } label: {
                                    Text(period.rawValue)
                                        .font(.caption)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(filterPeriod == period ? Color.blue : Color.gray.opacity(0.1))
                                        )
                                        .foregroundColor(filterPeriod == period ? .white : .primary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // Кнопка сброса фильтра
                    Button {
                        filterType = .all
                        filterPeriod = .allTime
                    } label: {
                        Text("Сбросить фильтр")
                            .font(.footnote)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(filterType != .all || filterPeriod != .allTime ? 1 : 0.5))
                            )
                    }
                    .disabled(filterType == .all && filterPeriod == .allTime)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.opacity)
            }

            Divider()
        }
    }

    // Улучшенный список транзакций
    private var transactionListSection: some View {
        List {
            // Если есть записи - показываем их
            if !filteredRecords.isEmpty {
                // Группировка записей по дате (месяцу)
                ForEach(groupedByMonth(), id: \.key) { monthData in
                    // Используем более простой синтаксис Section
                    Section {
                        ForEach(monthData.records) { record in
                            NavigationLink {
                                TransactionDetailView(record: record)
                            } label: {
                                transactionRowView(for: record)
                            }
                            .contextMenu {
                                Button(action: {
                                    // Создает копию для повтора транзакции
                                }) {
                                    Label("Повторить", systemImage: "arrow.triangle.2.circlepath")
                                }
                            }
                        }
                    } header: {
                        monthHeaderView(for: monthData.key)
                    }
                }
            } else {
                // Пустое состояние
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.top, 40)

                    Text("Нет финансовых записей")
                        .font(.headline)
                        .foregroundColor(.gray)

                    Text("Добавьте доход или расход, нажав кнопку «+» в верхнем правом углу")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.horizontal)

                    Button {
                        showAdd = true
                    } label: {
                        Text("Добавить запись")
                            .font(.headline)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top, 10)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(PlainListStyle())
    }

    // Вспомогательные функции для улучшенного дизайна

    // Группировка по месяцам
    private func groupedByMonth() -> [MonthRecords] {
        let grouped = Dictionary(grouping: filteredRecords) { record -> Date in
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: record.date)
            return calendar.date(from: components) ?? record.date
        }

        return grouped.map { (key, value) in
            MonthRecords(key: key, records: value)
        }.sorted { $0.key > $1.key }
    }

    // Структура группировки месяцев
    struct MonthRecords {
        let key: Date
        let records: [FinanceRecord]
    }

    // Шапка для месяца
    private func monthHeaderView(for date: Date) -> some View {
        HStack {
            // Индикатор месяца
            Text(monthFormatter.string(from: date))
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            // Общая сумма за месяц
            let monthSummary = calculateMonthSummary(for: date)
            Text(monthSummary >= 0 ? "+\(Int(monthSummary))" : "\(Int(monthSummary))")
                .foregroundColor(monthSummary >= 0 ? .green : .red)
                .font(.subheadline.bold())
        }
        .padding(.vertical, 5)
    }

    // Расчет общей суммы за месяц
    private func calculateMonthSummary(for date: Date) -> Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)

        return filteredRecords
            .filter {
                let recordComponents = calendar.dateComponents([.year, .month], from: $0.date)
                return recordComponents.year == components.year && recordComponents.month == components.month
            }
            .reduce(0) { sum, record in
                sum + (record.type == .income ? record.amount : -record.amount)
            }
    }

    // Форматтер для отображения месяца
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    // Строка транзакции
    private func transactionRowView(for record: FinanceRecord) -> some View {
        HStack(spacing: 12) {
            // Иконка категории
            ZStack {
                Circle()
                    .fill(record.type == .income ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: categoryIcon(for: record.category))
                    .font(.system(size: 16))
                    .foregroundColor(record.type == .income ? .green : .red)
            }

            // Информация о транзакции
            VStack(alignment: .leading, spacing: 4) {
                Text(record.category)
                    .font(.headline)

                HStack {
                    Text(dateFormatter.string(from: record.date))
                        .font(.caption)
                        .foregroundColor(.gray)

                    if !record.details.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Text(record.details)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Сумма
            Text("\(record.type == .income ? "+" : "-")\(Int(record.amount))")
                .font(.headline)
                .foregroundColor(record.type == .income ? .green : .red)
        }
        .padding(.vertical, 4)
    }

    // Форматтер для даты в строке
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    // Получение иконки для категории
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Логистика": return "car.fill"
        case "Питание": return "fork.knife"
        case "Оборудование": return "guitars"
        case "Проживание": return "house.fill"
        case "Продвижение": return "megaphone.fill"
        case "Другое": return "ellipsis.circle.fill"
        case "Выступления": return "music.note"
        case "Мерч": return "tshirt.fill"
        case "Роялти": return "music.quarternote.3"
        case "Спонсорство": return "dollarsign.circle"
        default: return "questionmark.circle"
        }
    }

    // Расчет истории баланса для мини-графика
    private func calculateBalanceHistory() -> [Double] {
        var sortedRecords = filteredRecords.sorted { $0.date < $1.date }

        // Ограничиваем количество точек для графика
        if sortedRecords.count > 15 {
            let step = sortedRecords.count / 15
            sortedRecords = stride(from: 0, to: sortedRecords.count, by: step).map { sortedRecords[$0] }
        }

        var balance: Double = 0
        var history: [Double] = []

        for record in sortedRecords {
            if record.type == .income {
                balance += record.amount
            } else {
                balance -= record.amount
            }
            history.append(balance)
        }

        // Если у нас меньше двух точек, добавляем дополнительные
        if history.count < 2 {
            if history.isEmpty {
                history = [0, 0]
            } else {
                history.append(history[0])
            }
        }

        return history
    }

    // Вычисляемые свойства для статистики (используем фильтрованные данные)
    private var totalIncome: Double {
        filteredRecords.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpense: Double {
        filteredRecords.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var profit: Double {
        totalIncome - totalExpense
    }
}
