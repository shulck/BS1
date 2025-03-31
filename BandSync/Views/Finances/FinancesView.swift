//
//  FinancesView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  FinancesView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct FinancesView: View {
    @StateObject private var service = FinanceService.shared
    @State private var showAdd = false

    var body: some View {
        NavigationView {
            VStack {
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
