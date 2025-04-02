import SwiftUI
import Charts

struct FinanceChartView: View {
    @ObservedObject var service = FinanceService.shared
    @State private var selectedPeriod: ChartPeriod = .month
    @State private var selectedChart: ChartType = .income
    
    enum ChartPeriod: String, CaseIterable, Identifiable {
        case week = "Неделя"
        case month = "Месяц"
        case quarter = "Квартал"
        case year = "Год"
        
        var id: String { self.rawValue }
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            }
        }
    }
    
    enum ChartType: String, CaseIterable, Identifiable {
        case income = "Доходы"
        case expense = "Расходы"
        case balance = "Баланс"
        case category = "Категории"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        VStack {
            // Селектор типа графика
            Picker("Тип графика", selection: $selectedChart) {
                ForEach(ChartType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Селектор периода
            Picker("Период", selection: $selectedPeriod) {
                ForEach(ChartPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // График
            chartView
                .frame(height: 250)
                .padding()
            
            // Легенда
            legendView
        }
    }
    
    // Разные типы графиков в зависимости от выбора
    private var chartView: some View {
        Group {
            switch selectedChart {
            case .income:
                incomeChartView
            case .expense:
                expenseChartView
            case .balance:
                balanceChartView
            case .category:
                categoryChartView
            }
        }
    }
    
    // График доходов
    private var incomeChartView: some View {
        Chart {
            ForEach(getGroupedData(for: .income), id: \.date) { item in
                BarMark(
                    x: .value("Дата", item.date, unit: .day),
                    y: .value("Сумма", item.amount)
                )
                .foregroundStyle(.green)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: getStrideCount())) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month())
            }
        }
    }
    
    // График расходов
    private var expenseChartView: some View {
        Chart {
            ForEach(getGroupedData(for: .expense), id: \.date) { item in
                BarMark(
                    x: .value("Дата", item.date, unit: .day),
                    y: .value("Сумма", item.amount)
                )
                .foregroundStyle(.red)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: getStrideCount())) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month())
            }
        }
    }
    
    // График баланса
    private var balanceChartView: some View {
        Chart {
            ForEach(getBalanceData(), id: \.date) { item in
                LineMark(
                    x: .value("Дата", item.date, unit: .day),
                    y: .value("Баланс", item.amount)
                )
                .foregroundStyle(item.amount >= 0 ? .green : .red)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                PointMark(
                    x: .value("Дата", item.date, unit: .day),
                    y: .value("Баланс", item.amount)
                )
                .foregroundStyle(item.amount >= 0 ? .green : .red)
            }
            
            RuleMark(y: .value("Ноль", 0))
                .foregroundStyle(.gray.opacity(0.5))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: getStrideCount())) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month())
            }
        }
    }
    
    // График категорий
    private var categoryChartView: some View {
        Chart {
            ForEach(getCategoryData(), id: \.category) { item in
                SectorMark(
                    angle: .value("Сумма", abs(item.amount)),
                    innerRadius: .ratio(0.5),
                    angularInset: 1
                )
                .foregroundStyle(by: .value("Категория", item.category))
                .cornerRadius(5)
            }
        }
    }
    
    // Легенда
    private var legendView: some View {
        if selectedChart == .category {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(getCategoryData(), id: \.category) { item in
                        HStack {
                            Circle()
                                .fill(colorForCategory(item.category))
                                .frame(width: 10, height: 10)
                            Text(item.category)
                                .font(.caption)
                            Text("\(Int(item.amount))")
                                .font(.caption)
                                .bold()
                                .foregroundColor(item.type == .income ? .green : .red)
                        }
                    }
                }
                .padding(.horizontal)
            }
        } else {
            // Для других графиков показываем итоги
            HStack(spacing: 20) {
                VStack {
                    Text("Всего доходов:")
                        .font(.caption)
                    Text("\(Int(service.totalIncome))")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                VStack {
                    Text("Всего расходов:")
                        .font(.caption)
                    Text("\(Int(service.totalExpense))")
                        .font(.headline)
                        .foregroundColor(.red)
                }
                
                VStack {
                    Text("Баланс:")
                        .font(.caption)
                    Text("\(Int(service.profit))")
                        .font(.headline)
                        .foregroundColor(service.profit >= 0 ? .green : .red)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Вспомогательные методы
    
    // Получение шага для оси X в зависимости от периода
    private func getStrideCount() -> Int {
        switch selectedPeriod {
        case .week: return 1
        case .month: return 5
        case .quarter: return 15
        case .year: return 60
        }
    }
    
    // Структура для данных графика
    private struct ChartData {
        let date: Date
        let amount: Double
        let type: FinanceType
        let category: String
    }
    
    // Фильтрация данных по периоду
    private func filterRecordsByPeriod() -> [FinanceRecord] {
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: endDate) else {
            return service.records
        }
        
        return service.records.filter { $0.date >= startDate && $0.date <= endDate }
    }
    
    // Группировка данных по дате для графиков доходов и расходов
    private func getGroupedData(for type: FinanceType) -> [ChartData] {
        let filteredRecords = filterRecordsByPeriod().filter { $0.type == type }
        
        // Группируем записи по дате (только день, без времени)
        let calendar = Calendar.current
        var groupedData: [Date: Double] = [:]
        
        for record in filteredRecords {
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: record.date)
            if let date = calendar.date(from: dateComponents) {
                groupedData[date, default: 0] += record.amount
            }
        }
        
        // Сортируем по дате
        return groupedData.map { ChartData(date: $0.key, amount: $0.value, type: type, category: "") }
            .sorted { $0.date < $1.date }
    }
    
    // Данные для графика баланса
    private func getBalanceData() -> [ChartData] {
        let incomeData = getGroupedData(for: .income)
        let expenseData = getGroupedData(for: .expense)
        
        // Собираем все уникальные даты
        var allDates = Set<Date>()
        incomeData.forEach { allDates.insert($0.date) }
        expenseData.forEach { allDates.insert($0.date) }
        
        // Создаем словари для быстрого доступа
        let incomeDictionary = Dictionary(uniqueKeysWithValues: incomeData.map { ($0.date, $0.amount) })
        let expenseDictionary = Dictionary(uniqueKeysWithValues: expenseData.map { ($0.date, $0.amount) })
        
        // Создаем итоговые данные
        var result: [ChartData] = []
        var runningBalance: Double = 0
        
        for date in allDates.sorted() {
            let income = incomeDictionary[date] ?? 0
            let expense = expenseDictionary[date] ?? 0
            runningBalance += income - expense
            result.append(ChartData(date: date, amount: runningBalance, type: runningBalance >= 0 ? .income : .expense, category: ""))
        }
        
        return result.sorted { $0.date < $1.date }
    }
    
    // Данные для графика категорий
    private func getCategoryData() -> [ChartData] {
        let filteredRecords = filterRecordsByPeriod()
        
        // Группируем по категориям
        var categoryData: [String: (amount: Double, type: FinanceType)] = [:]
        
        for record in filteredRecords {
            let currentAmount = categoryData[record.category]?.amount ?? 0
            let type = record.type
            let amount = record.type == .income ? record.amount : -record.amount
            categoryData[record.category] = (currentAmount + amount, type)
        }
        
        // Преобразуем в ChartData
        return categoryData.map { ChartData(date: Date(), amount: $0.value.amount, type: $0.value.type, category: $0.key) }
            .sorted { abs($0.amount) > abs($1.amount) }
    }
    
    // Цвет для категории
    private func colorForCategory(_ category: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .yellow, .gray, .red]
        let hash = abs(category.hash % colors.count)
        return colors[hash]
    }
}
