import SwiftUI
import Charts

struct FinancesView: View {
    @StateObject private var service = FinanceService.shared
    @State private var showAdd = false
    @State private var selectedPeriod: FinancePeriod = .month
    @State private var isRefreshing = false
    @State private var showOfflineAlert = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    // Перечисление периодов для фильтрации
    enum FinancePeriod: String, CaseIterable, Identifiable {
        case week = "Неделя"
        case month = "Месяц"
        case quarter = "Квартал"
        case year = "Год"

        var id: String { rawValue }
    }

    // Структура для группировки финансовых данных
    struct FinanceDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let income: Double
        let expense: Double
    }

    // Группировка записей по выбранному периоду
    private func groupFinanceData() -> [FinanceDataPoint] {
        let calendar = Calendar.current

        // Фильтрация записей по выбранному периоду
        let startDate: Date
        switch selectedPeriod {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: Date())!
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: Date())!
        case .quarter:
            startDate = calendar.date(byAdding: .month, value: -3, to: Date())!
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: Date())!
        }

        // Группировка по дням/неделям/месяцам в зависимости от выбранного периода
        let filteredRecords = service.records.filter { $0.date >= startDate }

        // Группировка данных
        var groupedData: [FinanceDataPoint] = []

        switch selectedPeriod {
        case .week:
            // Группировка по дням за неделю
            let groupedByDay = Dictionary(grouping: filteredRecords) { record in
                calendar.startOfDay(for: record.date)
            }

            groupedByDay.forEach { (date, records) in
                let income = records.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
                let expense = records.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }

                groupedData.append(FinanceDataPoint(date: date, income: income, expense: expense))
            }

        case .month:
            // Группировка по неделям за месяц
            let groupedByWeek = Dictionary(grouping: filteredRecords) { record in
                calendar.component(.weekOfYear, from: record.date)
            }

            groupedByWeek.forEach { (week, records) in
                let income = records.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
                let expense = records.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }

                // Берем дату первой записи в неделе
                let date = records.first?.date ?? Date()
                groupedData.append(FinanceDataPoint(date: date, income: income, expense: expense))
            }

        case .quarter, .year:
            // Группировка по месяцам за квартал/год
            let groupedByMonth = Dictionary(grouping: filteredRecords) { record in
                calendar.component(.month, from: record.date)
            }

            groupedByMonth.forEach { (month, records) in
                let income = records.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
                let expense = records.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }

                // Берем дату первой записи в месяце
                let date = records.first?.date ?? Date()
                groupedData.append(FinanceDataPoint(date: date, income: income, expense: expense))
            }
        }

        return groupedData.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Переключатель периодов                    // Переключатель периодов
                    Picker("Период", selection: $selectedPeriod) {selection: $selectedPeriod) {
                        ForEach(FinancePeriod.allCases) { period in.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())erStyle(SegmentedPickerStyle())
                    .padding(.horizontal)padding(.horizontal)

                    // Графики финансовых данных с адаптивной высотой данных с адаптивной высотой
                    VStack {                    VStack {
                        Chart(groupFinanceData()) { dataPoint in
                            BarMark(BarMark(
                                x: .value("Дата", dataPoint.date, unit: .day),, unit: .day),
                                y: .value("Доходы", dataPoint.income)value("Доходы", dataPoint.income)
                            )
                            .foregroundStyle(.green)
                            .cornerRadius(6)cornerRadius(6)

                            BarMark(
                                x: .value("Дата", dataPoint.date, unit: .day),                                x: .value("Дата", dataPoint.date, unit: .day),
                                y: .value("Расходы", dataPoint.expense)value("Расходы", dataPoint.expense)
                            )
                            .foregroundStyle(.red)
                            .cornerRadius(6)cornerRadius(6)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)   AxisMarks(position: .leading)
                        }
                        .chartLegend(position: .top)
                        .chartXAxis {chartXAxis {
                            AxisMarks { value in
                                let date = value.as(Date.self)!ate = value.as(Date.self)!
                                switch selectedPeriod {eriod {
                                case .week:
                                    AxisValueLabel(formatDate(date, format: "EEE"))atDate(date, format: "EEE"))
                                case .month::
                                    AxisValueLabel(formatDate(date, format: "d MMM"))))
                                case .quarter, .year:r, .year:
                                    AxisValueLabel(formatDate(date, format: "MMM"))
                                }
                            }
                        }
                        .frame(height: sizeClass == .regular ? 250 : 180)e(height: sizeClass == .regular ? 250 : 180)
                        .padding(.vertical, 8)padding(.vertical, 8)

                        if isOfflineDataShown() {) {
                            Text("Отображаются кэшированные данные")                            Text("Отображаются кэшированные данные")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, -8)-8)
                        }
                    }
                    .padding()ing()
                    .background(Color.secondary.opacity(0.1))background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)ius(12)
                    .padding(.horizontal)

                    // Итоговая статистикаа
                    summaryCard                    summaryCard

                    // Список транзакцийранзакций
                    transactionsList                    transactionsList
                }
                .padding(.vertical)
            }
            .refreshable {
                // Прямая интеграция с системным refreshable   RefreshControl(isRefreshing: $isRefreshing, onRefresh: refreshData)
                if let groupId = AppState.shared.user?.groupId {ight: 0)
                    service.fetch(for: groupId)lipped()
                }
                service.loadCachedRecordsIfNeeded()("Финансы")
            }
            .navigationTitle("Финансы")acement: .navigationBarTrailing) {
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {   showAdd = true
                    Button {   } label: {
                        showAdd = true           Label("Добавить", systemImage: "plus")
                    } label: {
                        Label("Добавить", systemImage: "plus")
                    }
                }pear {
            }er?.groupId {
            .onAppear {       service.fetch(for: groupId)
                if let groupId = AppState.shared.user?.groupId {
                    service.fetch(for: groupId)cordsIfNeeded()
                }
                service.loadCachedRecordsIfNeeded()
            }
            .sheet(isPresented: $showAdd) {
                AddTransactionView()
            }   Button("OK", role: .cancel) {}
            .alert("Работа в оффлайн режиме", isPresented: $showOfflineAlert) {   } message: {
                Button("OK", role: .cancel) {}           Text("Данные будут синхронизированы при появлении подключения")
            } message: {            }
                Text("Данные будут синхронизированы при появлении подключения")
            }
        }
    }
ard: some View {
    // Карточка с итогами
    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                VStack {
                    Text("Доходы")ary)
                        .font(.caption)   Text("\(Int(service.totalIncome))")
                        .foregroundColor(.secondary)                        .font(.headline)
                    Text("\(Int(service.totalIncome))")foregroundColor(.green)
                        .font(.headline)
                        .foregroundColor(.green)
                })
30)
                Divider()
                    .frame(height: 30)

                VStack {
                    Text("Расходы")ndary)
                        .font(.caption)   Text("\(Int(service.totalExpense))")
                        .foregroundColor(.secondary)                        .font(.headline)
                    Text("\(Int(service.totalExpense))")foregroundColor(.red)
                        .font(.headline)
                        .foregroundColor(.red)
                })
30)
                Divider()
                    .frame(height: 30)

                VStack {
                    Text("Прибыль")
                        .font(.caption)   Text("\(Int(service.profit))")
                        .foregroundColor(.secondary)           .font(.headline)
                    Text("\(Int(service.profit))")  .foregroundColor(service.profit >= 0 ? .green : .red)
                        .font(.headline)
                        .foregroundColor(service.profit >= 0 ? .green : .red)
                }
            }inity)
            .padding()   .background(Color.secondary.opacity(0.1))
            .frame(maxWidth: .infinity)       .cornerRadius(12)
            .background(Color.secondary.opacity(0.1))            .padding(.horizontal)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
: some View {
    // Список транзакцийpacing: 8) {
    private var transactionsList: some View {            Text("Последние операции")
        VStack(alignment: .leading, spacing: 8) {
            Text("Последние операции")
                .font(.headline)
                .padding(.horizontal)

            if service.records.isEmpty {                    Image(systemName: "doc.text")
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)т финансовых операций")
or(.gray)
                    Text("Нет финансовых операций")
                        .foregroundColor(.gray)
   showAdd = true
                    Button {
                        showAdd = true       Text("Добавить операцию")
                    } label: {
                        Text("Добавить операцию")red)
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)refix(5))) { record in
            } else {) {
                ForEach(Array(service.records.sorted(by: { $0.date > $1.date }).prefix(5))) { record in
                    NavigationLink(destination: TransactionDetailView(record: record)) {
                        HStack {(categoryColor(for: record.category))
                            Image(systemName: categoryIcon(for: record.category))                                .frame(width: 30, height: 30)
                                .foregroundColor(categoryColor(for: record.category))(for: record.category).opacity(0.2))
                                .frame(width: 30, height: 30)
                                .background(categoryColor(for: record.category).opacity(0.2))
                                .cornerRadius(8)
y)
                            VStack(alignment: .leading) {
                                Text(record.category)ls.isEmpty ? "Без описания" : record.details)
                                    .font(.headline)                                    .font(.caption)
                                Text(record.details.isEmpty ? "Без описания" : record.details)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)   Text(formatDate(record.date, format: "d MMMM yyyy"))
                                    .font(.caption2)
                                Text(formatDate(record.date, format: "d MMMM yyyy")).foregroundColor(.secondary)
                                    .font(.caption2)                            }
                                    .foregroundColor(.secondary)
                            }

                            Spacer()   Text("\(record.type == .income ? "+" : "-")\(Int(record.amount)) \(record.currency)")
oregroundColor(record.type == .income ? .green : .red)
                            Text("\(record.type == .income ? "+" : "-")\(Int(record.amount)) \(record.currency)")
                                .foregroundColor(record.type == .income ? .green : .red)
                                .font(.headline)   .padding()
                        }opacity(0.05))
                        .padding()       .cornerRadius(12)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(12)                    .buttonStyle(PlainButtonStyle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
tination: AllTransactionsView(records: service.records)) {
                if service.records.count > 5 { (\(service.records.count))")
                    NavigationLink(destination: AllTransactionsView(records: service.records)) {       .frame(maxWidth: .infinity)
                        Text("Показать все операции (\(service.records.count))")
                            .frame(maxWidth: .infinity)           .foregroundColor(.blue)
                            .padding()       }
                            .foregroundColor(.blue)           .buttonStyle(PlainButtonStyle())
                    }           }
                    .buttonStyle(PlainButtonStyle())            }
                }
            }
        }
    }ера - меняем на стабильный подход
    private func refreshData() {
    // Обновление данных с сервера - меняем на стабильный подход
    private func refreshData() {
        // Эту функцию мы больше не используем, так как переходим на встроенный refreshable
        if let groupId = AppState.shared.user?.groupId {дотвращения потенциальных ошибок
            isRefreshing = true
            service.fetch(for: groupId)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {/ Через 1.5 секунды завершаем обновление
                isRefreshing = falseatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            }alse
        } else {   }
            isRefreshing = false   } else {
        }            isRefreshing = false
    }

    // Проверка, отображаются ли кэшированные данные
    private func isOfflineDataShown() -> Bool {/ Проверка, отображаются ли кэшированные данные
        return !service.records.filter { $0.isCached }.isEmpty    private func isOfflineDataShown() -> Bool {
    }cords.filter { $0.isCached }.isEmpty

    // Форматирование даты
    private func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()ormat: String) -> String {
        formatter.dateFormat = format   let formatter = DateFormatter()
        return formatter.string(from: date)        formatter.dateFormat = format
    }ring(from: date)

    // Иконки для категорий
    private func categoryIcon(for category: String) -> String {
        switch category { String) -> String {
        case "Логистика": return "car.fill"
        case "Питание": return "fork.knife"
        case "Оборудование": return "guitars"
        case "Площадка": return "building.2.fill"
        case "Промо": return "megaphone.fill"l"
        case "Другое": return "ellipsis.circle.fill"ill"
        case "Выступление": return "music.note"le.fill"
        case "Мерч": return "tshirt.fill"e"
        case "Стриминг": return "headphones"ase "Мерч": return "tshirt.fill"
        default: return "questionmark.circle"   case "Стриминг": return "headphones"
        }        default: return "questionmark.circle"
    }

    // Цвета для категорий
    private func categoryColor(for category: String) -> Color {
        switch category {egory: String) -> Color {
        case "Логистика": return .blue
        case "Питание": return .orangee
        case "Оборудование": return .purplenge
        case "Площадка": return .grayple
        case "Промо": return .green
        case "Другое": return .secondary
        case "Выступление": return .redary
        case "Мерч": return .indigorn .red
        case "Стриминг": return .cyanase "Мерч": return .indigo
        default: return .primary   case "Стриминг": return .cyan
        }       default: return .primary
    }        }
}

// Новое представление для просмотра всех транзакций
struct AllTransactionsView: View {RefreshControl
    let records: [FinanceRecord]struct RefreshControl: UIViewRepresentable {
    @State private var searchText = ""

    var filteredRecords: [FinanceRecord] {
        if searchText.isEmpty {Context) -> UIRefreshControl {
            return records.sorted(by: { $0.date > $1.date })   let refreshControl = UIRefreshControl()
        } else {        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefreshControl), for: .valueChanged)
            return records
                .filter { record in
                    record.category.lowercased().contains(searchText.lowercased()) ||
                    record.details.lowercased().contains(searchText.lowercased())IView(_ uiView: UIRefreshControl, context: Context) {
                }
                .sorted(by: { $0.date > $1.date })   uiView.beginRefreshing()
        }   } else {
    }            uiView.endRefreshing()

    var body: some View {
        List {
            ForEach(filteredRecords) { record in    func makeCoordinator() -> Coordinator {
                NavigationLink(destination: TransactionDetailView(record: record)) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(record.category)
                                .font(.headline)l
                            Text(record.details)
                                .font(.caption)        init(_ control: RefreshControl) {
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("\(record.type == .income ? "+" : "-")\(Int(record.amount)) \(record.currency)")   @objc func handleRefreshControl(sender: UIRefreshControl) {
                            .foregroundColor(record.type == .income ? .green : .red)           control.onRefresh()
                    }        }
                }
            }
        }
        .navigationTitle("Все операции")сех транзакций
        .searchable(text: $searchText, prompt: "Поиск по категории или описанию")struct AllTransactionsView: View {
    }
}xt = ""
    }
}
