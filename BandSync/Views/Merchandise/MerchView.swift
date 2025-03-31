//
//  MerchView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  MerchView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct MerchView: View {
    @StateObject private var merchService = MerchService.shared
    @State private var showAdd = false

    var body: some View {
        NavigationView {
            List {
                ForEach(merchService.items) { item in
                    NavigationLink(destination: MerchDetailView(item: item)) {
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.headline)
                            Text("Остатки: S:\(item.stock.S) M:\(item.stock.M) L:\(item.stock.L) XL:\(item.stock.XL) XXL:\(item.stock.XXL)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Мерч")
            .toolbar {
                Button {
                    showAdd = true
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
            }
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    merchService.fetchItems(for: groupId)
                    merchService.fetchSales(for: groupId)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddMerchView()
            }
        }
    }
}
