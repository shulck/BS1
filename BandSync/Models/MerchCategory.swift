import Foundation
import FirebaseFirestore

enum MerchCategory: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case clothing = "Одежда"
    case music = "Музыка"
    case accessory = "Аксессуары"
    case other = "Другое"
}

// Вынесен отдельно для использования в разных местах
struct MerchSizeStock: Codable, Hashable {
    var S: Int
    var M: Int
    var L: Int
    var XL: Int
    var XXL: Int
    
    // Инициализатор по умолчанию
    init(S: Int = 0, M: Int = 0, L: Int = 0, XL: Int = 0, XXL: Int = 0) {
        self.S = S
        self.M = M
        self.L = L
        self.XL = XL
        self.XXL = XXL
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

    // Кодинг ключи для корректной работы с Firestore
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case price
        case category
        case subcategory
        case stock
        case groupId
        case imageURL
    }
    
    // Пользовательский init для Firestore
    init(name: String, description: String, price: Double,
         category: MerchCategory, subcategory: MerchSubcategory? = nil,
         stock: MerchSizeStock, groupId: String, imageURL: String? = nil) {
        self.name = name
        self.description = description
        self.price = price
        self.category = category
        self.subcategory = subcategory
        self.stock = stock
        self.groupId = groupId
        self.imageURL = imageURL
    }
    
    // Инициализатор для декодирования
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        price = try container.decode(Double.self, forKey: .price)
        category = try container.decode(MerchCategory.self, forKey: .category)
        subcategory = try container.decodeIfPresent(MerchSubcategory.self, forKey: .subcategory)
        stock = try container.decode(MerchSizeStock.self, forKey: .stock)
        groupId = try container.decode(String.self, forKey: .groupId)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
    }
}
