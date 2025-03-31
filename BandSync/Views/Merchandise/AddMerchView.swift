//
//  AddMerchView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  AddMerchView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct AddMerchView: View {
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var price = ""
    @State private var category: MerchCategory = .clothing
    @State private var stock = MerchSizeStock(S: 0, M: 0, L: 0, XL: 0, XXL: 0)

    var body: some View {
        NavigationView {
            Form {
                TextField("Название", text: $name)
                TextField("Описание", text: $description)
                TextField("Цена", text: $price).keyboardType(.decimalPad)

                Picker("Категория", selection: $category) {
                    ForEach(MerchCategory.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }

                Section(header: Text("Остатки по размерам")) {
                    Stepper("S: \(stock.S)", value: $stock.S, in: 0...999)
                    Stepper("M: \(stock.M)", value: $stock.M, in: 0...999)
                    Stepper("L: \(stock.L)", value: $stock.L, in: 0...999)
                    Stepper("XL: \(stock.XL)", value: $stock.XL, in: 0...999)
                    Stepper("XXL: \(stock.XXL)", value: $stock.XXL, in: 0...999)
                }
            }

            .navigationTitle("Добавить товар")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        guard let priceValue = Double(price),
                              let groupId = AppState.shared.user?.groupId else { return }

                        let item = MerchItem(
                            name: name,
                            description: description,
                            price: priceValue,
                            category: category,
                            stock: stock,
                            groupId: groupId
                        )

                        MerchService.shared.addItem(item) { success in
                            if success { dismiss() }
                        }
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
}
