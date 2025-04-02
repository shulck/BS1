import SwiftUI

struct FinancesView: View {
    @StateObject private var service = FinanceService.shared
    @State private var showAdd = false
    @State private var showFilter = false
    @State private var showScanReceipt = false
    @State private var showCharts = false
    @State private var selectedPeriod: String = "All"
    
    private let periods = ["All", "Today", "This Week", "This Month", "This Year"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter and period selection bar
                filterBar
                
                // Charts toggle
                if !service.records.isEmpty {
                    Toggle("Show Charts", isOn: $showCharts)
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                }
                
                // Charts view if enabled
                if showCharts && !service.records.isEmpty {
                    FinanceChartView()
                        .frame(height: 300)
                        .padding(.bottom)
                }
                
                // Summary section
                summarySection
                
                // Records list
                if service.isFiltered {
                    Text("Filtered results: \(service.records.count) transactions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }
                
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
                    
                    if service.records.isEmpty {
                        Text("No transactions found")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Finances")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showAdd = true
                        } label: {
                            Label("Add Transaction", systemImage: "plus")
                        }
                        
                        Button {
                            showScanReceipt = true
                        } label: {
                            Label("Scan Receipt", systemImage: "doc.text.viewfinder")
                        }
                        
                        Button {
                            showFilter = true
                        } label: {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    service.fetchWithFilters(for: groupId)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddTransactionView()
            }
            .sheet(isPresented: $showFilter) {
                FinanceFilterView()
            }
            .sheet(isPresented: $showScanReceipt) {
                EnhancedReceiptScannerView()
            }
        }
    }
    
    // Filter and period selection bar
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Filter button
                Button {
                    showFilter = true
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("Filter")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(service.isFiltered ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(service.isFiltered ? .white : .primary)
                    .cornerRadius(8)
                }
                
                // Period selection
                ForEach(periods, id: \.self) { period in
                    Button {
                        selectedPeriod = period
                        applyPeriodFilter(period)
                    } label: {
                        Text(period)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(selectedPeriod == period ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedPeriod == period ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color.gray.opacity(0.05))
    }
    
    // Summary section
    private var summarySection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Income")
                Spacer()
                Text("+\(Int(service.totalIncome))")
                    .foregroundColor(.green)
            }

            HStack {
                Text("Expenses")
                Spacer()
                Text("-\(Int(service.totalExpense))")
                    .foregroundColor(.red)
            }

            Divider()

            HStack {
                Text("Balance")
                    .bold()
                Spacer()
                Text("\(Int(service.profit))")
                    .foregroundColor(service.profit >= 0 ? .green : .red)
                    .bold()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
    }
    
    // Apply filter based on selected period
    private func applyPeriodFilter(_ period: String) {
        let calendar = Calendar.current
        let now = Date()
        var startDate = Date.distantPast
        let endDate = now
        
        // Calculate start date based on period
        switch period {
        case "Today":
            startDate = calendar.startOfDay(for: now)
        case "This Week":
            if let date = calendar.date(byAdding: .day, value: -7, to: now) {
                startDate = date
            }
        case "This Month":
            if let date = calendar.date(byAdding: .month, value: -1, to: now) {
                startDate = date
            }
        case "This Year":
            if let date = calendar.date(byAdding: .year, value: -1, to: now) {
                startDate = date
            }
        case "All":
            service.clearFilters()
            return
        default:
            return
        }
        
        // Create and apply filter
        let types: Set<FinanceType> = [.income, .expense]
        let categories = Set(service.getUniqueCategories())
        
        let filter = FinanceService.FinanceFilter(
            types: types,
            categories: categories,
            startDate: startDate,
            endDate: endDate,
            minAmount: nil,
            maxAmount: nil
        )
        
        service.applyFilter(filter)
    }
}
