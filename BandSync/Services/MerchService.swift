//
//  MerchService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

final class MerchService: ObservableObject {
    static let shared = MerchService()

    @Published var items: [MerchItem] = []
    @Published var sales: [MerchSale] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lowStockItems: [MerchItem] = []

    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()

    func fetchItems(for groupId: String) {
        isLoading = true
        errorMessage = nil

        db.collection("merchandise")
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = "Ошибка загрузки товаров: \(error.localizedDescription)"
                        return
                    }

                    if let docs = snapshot?.documents {
                        let result = docs.compactMap { try? $0.data(as: MerchItem.self) }
                        self.items = result

                        // Обновляем список товаров с низким запасом
                        self.updateLowStockItems()

                        // Кэшируем данные для офлайн доступа
                        CacheService.shared.cacheMerch(result, forGroupId: groupId)
                    }
                }
            }
    }

    func fetchSales(for groupId: String) {
        db.collection("merch_sales")
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Ошибка загрузки продаж: \(error.localizedDescription)"
                    }
                    return
                }

                if let docs = snapshot?.documents {
                    let result = docs.compactMap { try? $0.data(as: MerchSale.self) }
                    DispatchQueue.main.async {
                        self.sales = result
                    }
                }
            }
    }

    func addItem(_ item: MerchItem, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil

        do {
            _ = try db.collection("merchandise").addDocument(from: item) { [weak self] error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = "Ошибка добавления товара: \(error.localizedDescription)"
                        completion(false)
                    } else {
                        completion(true)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Ошибка сериализации: \(error.localizedDescription)"
                completion(false)
            }
        }
    }

    func updateItem(_ item: MerchItem, completion: @escaping (Bool) -> Void) {
        guard let id = item.id else {
            completion(false)
            return
        }

        isLoading = true
        errorMessage = nil

        // Обновляем поле updatedAt
        var updatedItem = item
        updatedItem.updatedAt = Date()

        do {
            try db.collection("merchandise").document(id).setData(from: updatedItem) { [weak self] error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = "Ошибка обновления товара: \(error.localizedDescription)"
                        completion(false)
                    } else {
                        // Обновляем локальный список
                        if let index = self.items.firstIndex(where: { $0.id == id }) {
                            self.items[index] = updatedItem
                        }

                        // Обновляем список товаров с низким запасом
                        self.updateLowStockItems()

                        completion(true)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Ошибка сериализации: \(error.localizedDescription)"
                completion(false)
            }
        }
    }

    func deleteItem(_ item: MerchItem, completion: @escaping (Bool) -> Void) {
        guard let id = item.id else {
            completion(false)
            return
        }

        isLoading = true
        errorMessage = nil

        db.collection("merchandise").document(id).delete { [weak self] error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Ошибка удаления товара: \(error.localizedDescription)"
                    completion(false)
                } else {
                    // Удаляем из локального списка
                    self.items.removeAll { $0.id == id }

                    // Обновляем список товаров с низким запасом
                    self.updateLowStockItems()

                    completion(true)
                }
            }
        }
    }

    func recordSale(item: MerchItem, size: String, quantity: Int, channel: MerchSaleChannel) {
        guard let itemId = item.id,
              let groupId = AppState.shared.user?.groupId else { return }

        let sale = MerchSale(
            itemId: itemId,
            size: size,
            quantity: quantity,
            channel: channel,
            groupId: groupId
        )

        do {
            _ = try db.collection("merch_sales").addDocument(from: sale) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Ошибка записи продажи: \(error.localizedDescription)"
                    }
                }
            }
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
            details: "Продажа \(item.name) (размер \(size))",
            date: Date(),
            receiptUrl: nil,
            groupId: groupId
        )

        FinanceService.shared.add(record) { _ in }
    }

    private func updateStock(for item: MerchItem, size: String, delta: Int) {
        guard let id = item.id else { return }
        var updated = item
        updated.updatedAt = Date()

        switch size {
        case "S": updated.stock.S += delta
        case "M": updated.stock.M += delta
        case "L": updated.stock.L += delta
        case "XL": updated.stock.XL += delta
        case "XXL": updated.stock.XXL += delta
        default: break
        }

        do {
            try db.collection("merchandise").document(id).setData(from: updated) { [weak self] error in
                if let error = error {
                    print("Ошибка обновления стока: \(error)")
                } else {
                    // Обновляем локальный список
                    DispatchQueue.main.async {
                        if let index = self?.items.firstIndex(where: { $0.id == id }) {
                            self?.items[index] = updated
                        }

                        // Обновляем список товаров с низким запасом
                        self?.updateLowStockItems()
                    }
                }
            }
        } catch {
            print("Ошибка сериализации при обновлении стока: \(error)")
        }
    }

    // MARK: - Методы для работы с изображениями

    func uploadItemImage(_ image: UIImage, for item: MerchItem, completion: @escaping (Result<String, Error>) -> Void) {
        guard let itemId = item.id else {
            completion(.failure(NSError(domain: "MerchService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Отсутствует ID товара"])))
            return
        }

        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "MerchService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать данные изображения"])))
            return
        }

        let imageName = "\(itemId)_\(UUID().uuidString).jpg"
        let imageRef = storage.child("merchandise/\(imageName)")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        imageRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            imageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                if let url = url {
                    completion(.success(url.absoluteString))
                } else {
                    completion(.failure(NSError(domain: "MerchService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Не удалось получить URL изображения"])))
                }
            }
        }
    }

    func uploadItemImages(_ images: [UIImage], for item: MerchItem, completion: @escaping (Result<[String], Error>) -> Void) {
        guard let itemId = item.id else {
            completion(.failure(NSError(domain: "MerchService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Отсутствует ID товара"])))
            return
        }

        let group = DispatchGroup()
        var urls: [String] = []
        var uploadError: Error?

        for image in images {
            group.enter()

            uploadItemImage(image, for: item) { result in
                switch result {
                case .success(let url):
                    urls.append(url)
                case .failure(let error):
                    uploadError = error
                }

                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let error = uploadError {
                completion(.failure(error))
            } else {
                completion(.success(urls))
            }
        }
    }

    func deleteItemImage(url: String, completion: @escaping (Bool) -> Void) {
        guard let urlObject = URL(string: url), let path = urlObject.path.components(separatedBy: "/o/").last?.removingPercentEncoding else {
            completion(false)
            return
        }

        let imageRef = storage.child(path)

        imageRef.delete { error in
            if let error = error {
                print("Ошибка удаления изображения: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }

    // MARK: - Методы для работы с низким запасом товаров

    private func updateLowStockItems() {
        lowStockItems = items.filter { $0.hasLowStock }

        // Отправляем уведомление, если есть товары с низким запасом
        if !lowStockItems.isEmpty {
            sendLowStockNotification()
        }
    }

    private func sendLowStockNotification() {
        // Отправляем уведомление только раз в день для каждого товара
        let lastNotificationDate = UserDefaults.standard.object(forKey: "lastLowStockNotificationDate") as? Date ?? Date(timeIntervalSince1970: 0)
        let calendar = Calendar.current

        if !calendar.isDateInToday(lastNotificationDate) {
            // Формируем текст уведомления
            let itemCount = lowStockItems.count
            let title = "Низкий запас товаров"
            let body = "У вас \(itemCount) товар\(itemCount == 1 ? "" : "ов") с низким запасом."

            // Отправляем уведомление
            NotificationManager.shared.scheduleLocalNotification(
                title: title,
                body: body,
                date: Date(),
                identifier: "low_stock_notification_\(Date().timeIntervalSince1970)",
                userInfo: ["type": "low_stock"]
            ) { _ in }

            // Сохраняем дату последнего уведомления
            UserDefaults.standard.set(Date(), forKey: "lastLowStockNotificationDate")
        }
    }

    // MARK: - Методы для аналитики

    func getSalesByPeriod(from startDate: Date, to endDate: Date) -> [MerchSale] {
        return sales.filter { $0.date >= startDate && $0.date <= endDate }
    }

    func getSalesByItem(itemId: String) -> [MerchSale] {
        return sales.filter { $0.itemId == itemId }
    }

    func getSalesByCategory(category: MerchCategory) -> [MerchSale] {
        let itemIds = items.filter { $0.category == category }.compactMap { $0.id }
        return sales.filter { sale in itemIds.contains(sale.itemId) }
    }

    func getSalesByMonth() -> [String: Int] {
        let calendar = Calendar.current
        var result: [String: Int] = [:]

        for sale in sales {
            let components = calendar.dateComponents([.year, .month], from: sale.date)
            if let year = components.year, let month = components.month {
                let key = "\(year)-\(String(format: "%02d", month))"
                result[key, default: 0] += sale.quantity
            }
        }

        return result
    }

    func getTopSellingItems(limit: Int = 5) -> [MerchItem] {
        var itemSalesCount: [String: Int] = [:]

        for sale in sales {
            itemSalesCount[sale.itemId, default: 0] += sale.quantity
        }

        let sortedItems = items.sorted { item1, item2 in
            let sales1 = itemSalesCount[item1.id ?? ""] ?? 0
            let sales2 = itemSalesCount[item2.id ?? ""] ?? 0
            return sales1 > sales2
        }

        return Array(sortedItems.prefix(limit))
    }

    func getLeastSellingItems(limit: Int = 5) -> [MerchItem] {
        var itemSalesCount: [String: Int] = [:]

        for sale in sales {
            itemSalesCount[sale.itemId, default: 0] += sale.quantity
        }

        // Добавляем товары без продаж
        for item in items {
            if let id = item.id, itemSalesCount[id] == nil {
                itemSalesCount[id] = 0
            }
        }

        let sortedItems = items.sorted { item1, item2 in
            let sales1 = itemSalesCount[item1.id ?? ""] ?? 0
            let sales2 = itemSalesCount[item2.id ?? ""] ?? 0
            return sales1 < sales2
        }

        return Array(sortedItems.prefix(limit))
    }

    func getTotalRevenue() -> Double {
        var revenue: Double = 0

        for sale in sales {
            if let item = items.first(where: { $0.id == sale.itemId }) {
                revenue += item.price * Double(sale.quantity)
            }
        }

        return revenue
    }

    func getRevenueByMonth() -> [String: Double] {
        let calendar = Calendar.current
        var result: [String: Double] = [:]

        for sale in sales {
            if let item = items.first(where: { $0.id == sale.itemId }) {
                let components = calendar.dateComponents([.year, .month], from: sale.date)
                if let year = components.year, let month = components.month {
                    let key = "\(year)-\(String(format: "%02d", month))"
                    result[key, default: 0] += item.price * Double(sale.quantity)
                }
            }
        }

        return result
    }

    // MARK: - Экспорт данных

    func exportSalesData() -> Data? {
        // Создаем CSV с данными о продажах
        var csvString = "Дата,Товар,Категория,Подкатегория,Размер,Количество,Цена,Сумма,Канал\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for sale in sales {
            guard let item = items.first(where: { $0.id == sale.itemId }) else {
                continue
            }

            let dateString = dateFormatter.string(from: sale.date)
            let amount = item.price * Double(sale.quantity)

            let line = "\(dateString),\"\(item.name)\",\(item.category.rawValue),\(item.subcategory?.rawValue ?? ""),\(sale.size),\(sale.quantity),\(item.price),\(amount),\(sale.channel.rawValue)\n"
            csvString.append(line)
        }

        return csvString.data(using: .utf8)
    }

    // Исправляем метод для работы с опциональной subcategory
    private func filter(_ items: [MerchItem], by searchText: String) -> [MerchItem] {
        return items.filter { item in
            let subcategoryText = item.subcategory?.rawValue ?? ""

            return item.name.lowercased().contains(searchText.lowercased()) ||
                item.description.lowercased().contains(searchText.lowercased()) ||
                item.category.rawValue.lowercased().contains(searchText.lowercased()) ||
                subcategoryText.lowercased().contains(searchText.lowercased())
        }
    }
}
