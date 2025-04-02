import SwiftUI
import Charts

struct FinanceChartView: View {
    let records: [FinanceRecord]
    
    // Группировка записей по месяцам
    private var monthlyRecords: [(month: Date, income: Double, expense: Double)] {
        let calendar = Calendar.current
        
        // Группировка записей по месяцам
        let groupedRecords = Dictionary(grouping: records) { record in
            calendar.date(from: calendar.dateComponents([.year, .month], from: record.date)) ?? Date()
        }
        
        // Трансформация сгруппированных данных
        let processedRecords = groupedRecords.map { (month, monthRecords) -> (month: Date, income: Double, expense: Double) in
            let income = monthRecords
                .filter { $0.type == .income }
                .reduce(0.0) { $0 + $1.amount }
            
            let expense = monthRecords
                .filter { $0.type == .expense }
                .reduce(0.0) { $0 + $1.amount }
            
            return (month: month, income: income, expense: expense)
        }
        
        // Сортировка по месяцам
        return processedRecords.sorted { $0.month < $1.month }
    }
    
    var body: some View {
        ScrollView {
            if !monthlyRecords.isEmpty {
                Chart {
                    ForEach(monthlyRecords, id: \.month) { record in
                        BarMark(
                            x: .value("Месяц", record.month, unit: .month),
                            y: .value("Доход", record.income)
                        )
                        .foregroundStyle(.green)
                        
                        BarMark(
                            x: .value("Месяц", record.month, unit: .month),
                            y: .value("Расход", record.expense)
                        )
                        .foregroundStyle(.red)
                    }
                }
                .frame(height: 300)
                .padding()
            } else {
                Text("Нет данных для отображения")
                    .foregroundColor(.gray)
                    .padding()
            }
        }
    }
}
