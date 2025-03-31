//
//  TransactionDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  TransactionDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct TransactionDetailView: View {
    let record: FinanceRecord

    var body: some View {
        Form {
            Section(header: Text("Тип")) {
                Text(record.type.rawValue)
            }

            Section(header: Text("Категория")) {
                Text(record.category)
            }

            Section(header: Text("Сумма")) {
                Text("\(Int(record.amount)) \(record.currency)")
                    .foregroundColor(record.type == .income ? .green : .red)
            }

            Section(header: Text("Дата")) {
                Text(formattedDate(record.date))
            }

            Section(header: Text("Описание")) {
                Text(record.details)
            }
        }
        .navigationTitle("Операция")
    }

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: date)
    }
}
