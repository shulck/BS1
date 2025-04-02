//
//  FinanceChartView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//


//
//  FinanceChartView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI
import Charts

struct FinanceChartView: View {
    @StateObject private var financeService = FinanceService.shared
    @State private var selectedPeriod: ChartPeriod = .month
    @State private var selectedChartType: ChartType = .bar
    
    // Определение периодов для графика
    enum ChartPeriod: String, CaseIterable, Identifiable {
        case week = "Неделя"
        case month = "Месяц"
        case quarter = "Квартал"
        case year = "Год"
        case all = "Все время"
        
        var id: String { rawValue }
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            case .all: return 3650 // Примерно 10 лет
            }
        }
    }
    
    // Типы графиков
    enum ChartType: String, CaseIterable, Identifiable {
        case bar = "Столбчатый"
        case line = "Линейный"
        case pie = "Круговой"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .bar: return "chart.bar"
            case .line: return "waveform.path"
            case .pie: return "chart.pie"
            }
        }
    }
    
    // Данные для графиков
    struct ChartData: Identifiable {
        var id = UUID()
        var date: Date
        var income: Double
        var expense: Double
        var category: String?
        
        var profit: Double {
            income - expense
        }
    }
    
    // Данные для круговой диаграммы
    struct PieChartData: Identifiable {
        var id = UUID()
        var category: String
        var amount: Double
        var isIncome: Bool
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Селектор периода и типа графика
            HStack {
                Picker("Период", selection: $selectedPeriod) {
                    ForEach(ChartPeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Spacer()
                
                // Переключатель типа графика
                Picker("Тип", selection: $selectedChartType) {
                    ForEach(ChartType.allCases) { type in
                        Image(systemName: type.icon).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 120)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Разделитель для размера
            Divider()
                .padding(.vertical, 8)
            
            // Финансовая сводка
            financialSummaryView
                .padding(.horizontal)
                .padding(.bottom, 8)
            
            // График
            if financeService.records.isEmpty {
                emptyStateView
            } else {
                chartView
            }
        }
        .navigationTitle("Финансовая аналитика")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let groupId = AppState.shared.user?.groupId {
                financeService.fetch(for: groupId)
            }
        }
    }
    
    // MARK: - Представления компонентов
    
    // Финансовая сводка
    private var financialSummaryView: some View {
        HStack(spacing: 20) {
            // Доходы
            VStack(alignment: .leading) {
                Text("Доходы")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(Int(incomeForSelectedPeriod()))")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            // Расходы
            VStack(alignment: .leading) {
                Text("Расходы")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(Int(expenseForSelectedPeriod()))")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            // Прибыль
            VStack(alignment: .leading) {
                Text("Прибыль")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(Int(incomeForSelectedPeriod() - expenseForSelectedPeriod()))")
                    .font(.headline)
                    .foregroundColor(incomeForSelectedPeriod() >= expenseForSelectedPeriod() ? .green : .red)
            }
        }
    }
    
    // Состояние пустого графика
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("Нет данных для отображения")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Добавьте финансовые операции для визуализации")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // График в зависимости от выбранного типа
    @ViewBuilder
    private var chartView: some View {
        if #available(iOS 16.0, *) {
            switch selectedChartType {
            case .bar:
                barChartView
            case .line:
                lineChartView
            case .pie:
                pieChartView
            }
        } else {
            // Для iOS ниже 16.0
            Text("Графики доступны в iOS 16 и выше")
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Графики
    
    @available(iOS 16.0, *)
    private var barChartView: some View {
        let chartData = getChartData()
        
        return Chart(chartData) { item in
            BarMark(
                x: .value("Дата", item.date),
                y: .value("Сумма", item.income),
                width: .fixed(20)
            )
            .foregroundStyle(.green)
            
            BarMark(
                x: .value("Дата", item.date),
                y: .value("Сумма", item.expense),
                width: .fixed(20)
            )
            .foregroundStyle(.red)
        }
        .chartForegroundStyleScale([
            "Доходы": .green,
            "Расходы": .red
        ])
        .chartLegend(position: .top)
        .padding()
        .frame(height: 300)
    }
    
    @available(iOS 16.0, *)
    private var lineChartView: some View {
        let chartData = getChartData()
        
        return Chart {
            ForEach(chartData) { item in
                LineMark(
                    x: .value("Дата", item.date),
                    y: .value("Доходы", item.income)
                )
                .foregroundStyle(.green)
                .interpolationMethod(.catmullRom)
                
                PointMark(
                    x: .value("Дата", item.date),
                    y: .value("Доходы", item.income)
                )
                .foregroundStyle(.green)
                
                LineMark(
                    x: .value("Дата", item.date),
                    y: .value("Расходы", item.expense)
                )
                .foregroundStyle(.red)
                .interpolationMethod(.catmullRom)
                
                PointMark(
                    x: .value("Дата", item.date),
                    y: .value("Расходы", item.expense)
                )
                .foregroundStyle(.red)
                
                // Линия прибыли
                LineMark(
                    x: .value("Дата", item.date),
                    y: .value("Прибыль", item.profit)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartForegroundStyleScale([
            "Доходы": .green,
            "Расходы": .red,
            "Прибыль": .blue
        ])
        .chartLegend(position: .top)
        .padding()
        .frame(height: 300)
    }
    
    @available(iOS 16.0, *)
    private var pieChartView: some View {
        let pieData = getPieChartData()
        
        return VStack {
            // Переключатель доходов/расходов для круговой диаграммы
            Picker("Показать", selection: $pieChartType) {
                Text("Доходы").tag(PieChartType.income)
                Text("Расходы").tag(PieChartType.expense)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            Chart(pieData.filter { $0.isIncome == (pieChartType == .income) }) { item in
                SectorMark(
                    angle: .value("Сумма", item.amount),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .cornerRadius(5)
                .foregroundStyle(by: .value("Категория", item.category))
            }
            .chartLegend(position: .bottom)
            .padding()
            .frame(height: 250)
        }
    }
    
    // MARK: - Функции данных
    
    // Получение отфильтрованных записей для выбранного периода
    private func filteredRecords() -> [FinanceRecord] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: Date()) ?? Date()
        return financeService.records.filter { $0.date >= cutoffDate }
    }
    
    // Расчет суммы доходов за выбранный период
    private func incomeForSelectedPeriod() -> Double {
        let records = filteredRecords()
        return records.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    
    // Расчет суммы расходов за выбранный период
    private func expenseForSelectedPeriod() -> Double {
        let records = filteredRecords()
        return records.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    
    // Получение данных для графика
    private func getChartData() -> [ChartData] {
        let records = filteredRecords()
        let calendar = Calendar.current
        
        var result: [ChartData] = []
        
        // Определяем интервал группировки в зависимости от выбранного периода
        let groupingInterval: Calendar.Component
        
        switch selectedPeriod {
        case .week:
            groupingInterval = .day
        case .month:
            groupingInterval = .day
        case .quarter:
            groupingInterval = .weekOfYear
        case .year, .all:
            groupingInterval = .month
        }
        
        // Группируем записи по выбранному интервалу
        var recordsByInterval: [Date: [FinanceRecord]] = [:]
        
        for record in records {
            var components: DateComponents
            
            switch groupingInterval {
            case .day:
                components = calendar.dateComponents([.year, .month, .day], from: record.date)
            case .weekOfYear:
                components = calendar.dateComponents([.year, .weekOfYear], from: record.date)
            case .month:
                components = calendar.dateComponents([.year, .month], from: record.date)
            default:
                components = calendar.dateComponents([.year, .month], from: record.date)
            }
            
            if let date = calendar.date(from: components) {
                if recordsByInterval[date] == nil {
                    recordsByInterval[date] = []
                }
                recordsByInterval[date]?.append(record)
            }
        }
        
        // Создаем точки данных из сгруппированных записей
        for (date, intervalRecords) in recordsByInterval.sorted(by: { $0.key < $1.key }) {
            let income = intervalRecords.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            let expense = intervalRecords.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            
            result.append(ChartData(date: date, income: income, expense: expense))
        }
        
        return result
    }
    
    // Тип данных для переключения круговой диаграммы
    enum PieChartType {
        case income, expense
    }
    @State private var pieChartType: PieChartType = .income
    
    // Получение данных для круговой диаграммы
    private func getPieChartData() -> [PieChartData] {
        let records = filteredRecords()
        var result: [PieChartData] = []
        
        // Группировка записей по категориям и типу (доход/расход)
        var amountByCategory: [String: [FinanceType: Double]] = [:]
        
        for record in records {
            if amountByCategory[record.category] == nil {
                amountByCategory[record.category] = [.income: 0, .expense: 0]
            }
            
            amountByCategory[record.category]?[record.type, default: 0] += record.amount
        }
        
        // Преобразование в массив для графика
        for (category, amounts) in amountByCategory {
            if let incomeAmount = amounts[.income], incomeAmount > 0 {
                result.append(PieChartData(category: category, amount: incomeAmount, isIncome: true))
            }
            
            if let expenseAmount = amounts[.expense], expenseAmount > 0 {
                result.append(PieChartData(category: category, amount: expenseAmount, isIncome: false))
            }
        }
        
        return result
    }
}