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
    @State private var isGift = false

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

                Toggle("Это подарок", isOn: $isGift)
                    .onChange(of: isGift) { newValue in
                        if newValue {
                            channel = .gift
                        } else if channel == .gift {
                            channel = .concert
                        }
                    }

                if !isGift {
                    Picker("Канал продаж", selection: $channel) {
                        ForEach(MerchSaleChannel.allCases.filter { $0 != .gift }) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                }
            }

            .navigationTitle(isGift ? "Подарить товар" : "Продажа")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isGift ? "Подарить" : "Подтвердить") {
                        // При подарке принудительно устанавливаем канал gift
                        let finalChannel = isGift ? MerchSaleChannel.gift : channel
                        MerchService.shared.recordSale(item: item, size: size, quantity: quantity, channel: finalChannel)
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
