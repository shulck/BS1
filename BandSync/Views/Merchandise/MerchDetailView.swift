//
//  MerchDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  MerchDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct MerchDetailView: View {
    let item: MerchItem
    @State private var showSell = false

    var body: some View {
        Form {
            Section(header: Text("Описание")) {
                Text(item.description)
            }

            Section(header: Text("Категория")) {
                Text(item.category.rawValue)
            }

            Section(header: Text("Цена")) {
                Text("\(Int(item.price)) EUR")
            }

            Section(header: Text("Остатки по размерам")) {
                Text("S: \(item.stock.S)")
                Text("M: \(item.stock.M)")
                Text("L: \(item.stock.L)")
                Text("XL: \(item.stock.XL)")
                Text("XXL: \(item.stock.XXL)")
            }

            Section {
                Button("Продать товар") {
                    showSell = true
                }
            }
        }
        .navigationTitle(item.name)
        .sheet(isPresented: $showSell) {
            SellMerchView(item: item)
        }
    }
}
