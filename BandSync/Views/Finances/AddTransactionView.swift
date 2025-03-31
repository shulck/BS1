//
//  AddTransactionView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  AddTransactionView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var type: FinanceType = .expense
    @State private var category: FinanceCategory = .logistics
    @State private var amount: String = ""
    @State private var currency: String = "EUR"
    @State private var details: String = ""
    @State private var date = Date()

    var body: some View {
        NavigationView {
            Form {
                Picker("Тип", selection: $type) {
                    Text("Доход").tag(FinanceType.income)
                    Text("Расход").tag(FinanceType.expense)
                }
                .pickerStyle(.segmented)

                Picker("Категория", selection: $category) {
                    ForEach(FinanceCategory.forType(type)) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }

                TextField("Сумма", text: $amount)
                    .keyboardType(.decimalPad)

                TextField("Валюта", text: $currency)
                    .autocapitalization(.allCharacters)

                TextField("Описание", text: $details)

                DatePicker("Дата", selection: $date, displayedComponents: [.date])
            }

            .navigationTitle("Новая запись")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveRecord()
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveRecord() {
        guard
            let amountValue = Double(amount),
            let groupId = AppState.shared.user?.groupId
        else { return }

        let record = FinanceRecord(
            type: type,
            amount: amountValue,
            currency: currency.uppercased(),
            category: category.rawValue,
            details: details,
            date: date,
            receiptUrl: nil,
            groupId: groupId
        )

        guard FinanceValidator.isValid(record: record) else { return }

        FinanceService.shared.add(record) { success in
            if success {
                dismiss()
            }
        }
    }
}
