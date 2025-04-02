import SwiftUI
import Charts

struct FinancesView: View {
    @StateObject private var service = FinanceService.shared
    @State private var showAdd = false
    @State private var showFilter = false
    @State private var showScanner = false
    @State private var showChart = false
    
    // Фильтр для финансовых записей
    @State private var financeFilter = FinanceFilter()
    
    // Отфильтрованные записи
    private var filteredRecords: [FinanceRecord] {
        financeFilter.apply(to: service.records)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Сводная секция
                summarySection
                
                // Фильтры и управление
                filterControlSection
                
                // Список транзакций
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
            .sheet(isPresented: $showFilter) {
                FinanceFilterView(filter: $financeFilter, service: service)
            }
            .sheet(isPresented: $showScanner) {
                ReceiptScannerView()
            }
            .sheet(isPresented: $showChart) {
                FinanceChartView(records: filteredRecords)
            }
        }
    }
    
    // Секция сводной статистики
    private var summarySection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Доходы")
                Spacer()
                Text("+\(Int(totalIncome))")
                    .foregroundColor(.green)
            }

            HStack {
                Text("Расходы")
                Spacer()
                Text("-\(Int(totalExpense))")
                    .foregroundColor(.red)
            }

            Divider()

            HStack {
                Text("Прибыль")
                    .bold()
                Spacer()
                Text("\(Int(profit))")
                    .foregroundColor(profit >= 0 ? .green : .red)
                    .bold()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
    
    // Секция фильтров и управления
    private var filterControlSection: some View {
        HStack {
            // Кнопка фильтра
            Button {
                showFilter = true
            } label: {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Фильтр")
                }
                .foregroundColor(financeFilter.isActive ? .blue : .primary)
            }
            
            // Кнопка сброса фильтра
            if financeFilter.isActive {
                Button("Сбросить") {
                    financeFilter.reset()
                }
                .foregroundColor(.red)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // Секция списка транзакций
    private var transactionListSection: some View {
        List {
            ForEach(filteredRecords) { record in
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
            
            // Сообщение, если список пуст
            if filteredRecords.isEmpty {
                Text("Нет финансовых записей")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // Вычисляемые свойства для статистики
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
