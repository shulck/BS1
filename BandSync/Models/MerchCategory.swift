import Foundation
import FirebaseFirestore

enum MerchCategory: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case clothing = "Одежда"
    case music = "Музыка"
    case accessory = "Аксессуары"
    case other = "Другое"

    // Добавляем свойство icon
    var icon: String {
        switch self {
        case .clothing: return "tshirt"
        case .music: return "music.note"
        case .accessory: return "bag"
        case .other: return "ellipsis.circle"
        }
    }
}

struct MerchSizeStock: Codable {
    var S: Int = 0
    var M: Int = 0
    var L: Int = 0
    var XL: Int = 0
    var XXL: Int = 0

    init(S: Int = 0, M: Int = 0, L: Int = 0, XL: Int = 0, XXL: Int = 0) {
        self.S = S
        self.M = M
        self.L = L
        self.XL = XL
        self.XXL = XXL
    }

    // Общее количество
    var total: Int {
        return S + M + L + XL + XXL
    }

    // Проверка на низкие остатки
    func hasLowStock(threshold: Int) -> Bool {
        return S <= threshold || M <= threshold || L <= threshold || XL <= threshold || XXL <= threshold
    }
}

struct MerchItem: Identifiable, Codable {
    @DocumentID var id: String?

    var name: String
    var description: String
    var price: Double
    var category: MerchCategory
    var subcategory: MerchSubcategory?
    var stock: MerchSizeStock
    var groupId: String
    var imageURL: String?
    var imageUrls: [String]?
    var lowStockThreshold: Int = 3
    var updatedAt: Date = Date()
    var createdAt: Date = Date()

    // Вычисляемые свойства
    var totalStock: Int {
        return stock.total
    }

    var hasLowStock: Bool {
        return stock.hasLowStock(threshold: lowStockThreshold)
    }
}
