import SwiftUI
import Charts

struct FinancesView: View {
    @StateObject private var service = FinanceService.shared
    @State private var showAdd = false
    @State private var selectedPeriod: FinancePeriod = .month
    
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
            VStack {
                // Переключатель периодов
                Picker("Период", selection: $selectedPeriod) {
                    ForEach(FinancePeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Графики финансовых данных
                Chart(groupFinanceData()) { dataPoint in
                    BarMark(
                        x: .value("Дата", dataPoint.date, unit: .day),
                        y: .value("Доходы", dataPoint.income)
                    )
                    .foregroundStyle(.green)
                    
                    BarMark(
                        x: .value("Дата", dataPoint.date, unit: .day),
                        y: .value("Расходы", dataPoint.expense)
                    )
                    .foregroundStyle(.red)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 250)
                .padding()
                
                // Существующий список транзакций
                summarySection
                
                List {
                    ForEach(service.records) { record in
                        NavigationLink(destination: TransactionDetailView(record: record)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(record.category)
                                        .font(.headline)
                                    Text(record.details)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text("\(record.type == .income ? "+" : "-")\(Int(record.amount)) \(record.currency)")
                                    .foregroundColor(record.type == .income ? .green : .red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Финансы")
            .toolbar {
                Button {
                    showAdd = true
                } label: {
                    Label("Добавить", systemImage: "plus")
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
        }
    }
    
    // Секция с итогами (сохраняем существующую логику)
    private var summarySection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Доходы")
                Spacer()
                Text("+\(Int(service.totalIncome))")
                    .foregroundColor(.green)
            }

            HStack {
                Text("Расходы")
                Spacer()
                Text("-\(Int(service.totalExpense))")
                    .foregroundColor(.red)
            }

            Divider()

            HStack {
                Text("Прибыль")
                    .bold()
                Spacer()
                Text("\(Int(service.profit))")
                    .foregroundColor(service.profit >= 0 ? .green : .red)
                    .bold()
            }
        }
        .padding()
    }
}
