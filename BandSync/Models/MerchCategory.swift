import Foundation
import FirebaseFirestore

// Добавим субкатегорию
enum MerchSubcategory: String, Codable, CaseIterable, Identifiable {
    // Одежда
    case tshirt = "Футболка"
    case hoodie = "Худи"
    case cap = "Кепка"
    case sweatshirt = "Свитшот"
    case jacket = "Куртка"
    
    // Музыка
    case vinyl = "Винил"
    case cd = "CD"
    case tape = "Кассета"
    case digital = "Цифровой альбом"
    
    // Аксессуары
    case poster = "Постер"
    case pin = "Значок"
    case patch = "Нашивка"
    case flag = "Флаг"
    case sticker = "Стикер"
    
    // Другое
    case other = "Другое"
    
    var id: String { rawValue }
    
    // Метод для получения субкатегорий по основной категории
    static func subcategories(for category: MerchCategory) -> [MerchSubcategory] {
        switch category {
        case .clothing:
            return [.tshirt, .hoodie, .cap, .sweatshirt, .jacket]
        case .music:
            return [.vinyl, .cd, .tape, .digital]
        case .accessory:
            return [.poster, .pin, .patch, .flag, .sticker]
        case .other:
            return [.other]
        }
    }
}

enum MerchCategory: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case clothing = "Одежда"
    case music = "Музыка"
    case accessory = "Аксессуары"
    case other = "Другое"
}

struct MerchSizeStock: Codable {
    var S: Int
    var M: Int
    var L: Int
    var XL: Int
    var XXL: Int
    
    // Добавим метод для проверки низких остатков
    var hasLowStock: Bool {
        return S <= 3 || M <= 3 || L <= 3 || XL <= 3 || XXL <= 3
    }
}

struct MerchItem: Identifiable, Codable {
    @DocumentID var id: String?

    var name: String
    var description: String
    var price: Double
    var category: MerchCategory
    var subcategory: MerchSubcategory
    var stock: MerchSizeStock
    var groupId: String
    var updatedAt: Date = Date()
    var createdAt: Date = Date()
}
