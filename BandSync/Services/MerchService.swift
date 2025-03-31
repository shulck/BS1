//
//  MerchService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  MerchService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore


final class MerchService: ObservableObject {
    static let shared = MerchService()

    @Published var items: [MerchItem] = []
    @Published var sales: [MerchSale] = []

    private let db = Firestore.firestore()

    func fetchItems(for groupId: String) {
        db.collection("merchandise")
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener { snapshot, _ in
                if let docs = snapshot?.documents {
                    let result = docs.compactMap { try? $0.data(as: MerchItem.self) }
                    DispatchQueue.main.async {
                        self.items = result
                    }
                }
            }
    }

    func fetchSales(for groupId: String) {
        db.collection("merch_sales")
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener { snapshot, _ in
                if let docs = snapshot?.documents {
                    let result = docs.compactMap { try? $0.data(as: MerchSale.self) }
                    DispatchQueue.main.async {
                        self.sales = result
                    }
                }
            }
    }

    func addItem(_ item: MerchItem, completion: @escaping (Bool) -> Void) {
        do {
            _ = try db.collection("merchandise").addDocument(from: item) { error in
                completion(error == nil)
            }
        } catch {
            completion(false)
        }
    }

    func recordSale(item: MerchItem, size: String, quantity: Int, channel: MerchSaleChannel) {
        guard let groupId = AppState.shared.user?.groupId else { return }

        let sale = MerchSale(
            itemId: item.id ?? "",
            quantity: quantity,
            size: size,
            channel: channel,
            date: Date(),
            groupId: groupId
        )

        do {
            _ = try db.collection("merch_sales").addDocument(from: sale)
        } catch {
            print("Ошибка записи продажи: \(error)")
        }

        // Update stock
        updateStock(for: item, size: size, delta: -quantity)
        
        // Auto-add to finances
        let record = FinanceRecord(
            type: .income,
            amount: Double(quantity) * item.price,
            currency: "EUR",
            category: "Мерч",
            details: "Продажа \(item.name)",
            date: Date(),
            receiptUrl: nil,
            groupId: groupId
        )

        FinanceService.shared.add(record) { _ in }
    }

    private func updateStock(for item: MerchItem, size: String, delta: Int) {
        guard let id = item.id else { return }
        var updated = item

        switch size {
        case "S": updated.stock.S += delta
        case "M": updated.stock.M += delta
        case "L": updated.stock.L += delta
        case "XL": updated.stock.XL += delta
        case "XXL": updated.stock.XXL += delta
        default: break
        }

        do {
            try db.collection("merchandise").document(id).setData(from: updated)
        } catch {
            print("Ошибка обновления стока: \(error)")
        }
    }
}
