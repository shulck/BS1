//
//  SellMerchView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct SellMerchView: View {
    @Environment(\.dismiss) var dismiss
    let item: MerchItem

    @State private var size = "M"
    @State private var quantity = 1
    @State private var channel: MerchSaleChannel = .concert

    var body: some View {
        NavigationView {
            Form {
                if item.category == .clothing {
                    Picker("Размер", selection: $size) {
                        ForEach(["S", "M", "L", "XL", "XXL"], id: \.self) { size in
                            Text(size)
                        }
                    }
                } else {
                    // Для других категорий размер не выбираем, используем фиктивное значение
                    let _ = { size = "one_size" }()
                }

                Stepper("Количество: \(quantity)", value: $quantity, in: 1...999)

                Picker("Канал продаж", selection: $channel) {
                    ForEach(MerchSaleChannel.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
            }

            .navigationTitle("Продажа")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Подтвердить") {
                        MerchService.shared.recordSale(item: item, size: size, quantity: quantity, channel: channel)
                        dismiss()
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
