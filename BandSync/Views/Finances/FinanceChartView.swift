import SwiftUI
import Charts

struct FinanceChartView: View {
    let income: [Double]
    let expenses: [Double]
    let labels: [String]
    let totalIncome: Double
    let totalExpenses: Double
    let period: ChartPeriod
    
    enum ChartPeriod {
        case week
        case month
        case quarter
        case year
        
        var title: String {
            switch self {
            case .week: return "Неделя"
            case .month: return "Месяц"
            case .quarter: return "Квартал"
            case .year: return "Год"
            }
        }
    }
    
    var profit: Double {
        totalIncome - totalExpenses
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Заголовок и сводная информация
            HStack {
                VStack(alignment: .leading) {
                    Text("Финансовый обзор")
                        .font(.headline)
                    Text(period.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Прибыль")
                        .font(.subheadline)
                    Text("\(Int(profit)) \(profit >= 0 ? "+" : "")")
                        .font(.headline)
                        .foregroundColor(profit >= 0 ? .green : .red)
                }
            }
            
            Divider()
            
            // График
            Chart {
                ForEach(0..<income.count, id: \.self) { index in
                    BarMark(
                        x: .value("Период", labels[index]),
                        y: .value("Доход", income[index]),
                        width: .fixed(20)
                    )
                    .foregroundStyle(.green)
                    .position(by: .value("Тип", "Доходы"))
                    
                    BarMark(
                        x: .value("Период", labels[index]),
                        y: .value("Расход", expenses[index]),
                        width: .fixed(20)
                    )
                    .foregroundStyle(.red)
                    .position(by: .value("Тип", "Расходы"))
                }
                
                RuleMark(y: .value("Прибыль", 0))
                    .foregroundStyle(.gray)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(preset: .aligned) { value in
                    if let label = value.as(String.self) {
                        AxisValueLabel(label)
                    }
                }
            }
            .chartForegroundStyleScale([
                "Доходы": Color.green,
                "Расходы": Color.red
            ])
            .chartLegend(position: .bottom, alignment: .center)
            
            Divider()
            
            // Итоговая статистика
            HStack(spacing: 20) {
                Spacer()
                
                VStack {
                    Text("Доходы")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(totalIncome))")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                
                VStack {
                    Text("Расходы")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(totalExpenses))")
                        .font(.title3)
                        .foregroundColor(.red)
                }
                
                VStack {
                    Text("Баланс")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(profit))")
                        .font(.title3)
                        .foregroundColor(profit >= 0 ? .green : .red)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// Предварительный просмотр для разработки
struct FinanceChartView_Previews: PreviewProvider {
    static var previews: some View {
        FinanceChartView(
            income: [1500, 2300, 1800, 2700, 3200, 2100],
            expenses: [1200, 1800, 1400, 2100, 1900, 1600],
            labels: ["Янв", "Фев", "Март", "Апр", "Май", "Июнь"],
            totalIncome: 13600,
            totalExpenses: 10000,
            period: .month
        )
        .padding()
        .background(Color.gray.opacity(0.1))
        .previewLayout(.sizeThatFits)
    }
}
