import Foundation
import FirebaseFirestore

enum MerchCategory: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    // Основные категории
    case clothing = "Одежда"
    case music = "Музыкальная продукция"
    case accessory = "Аксессуары"
    case collectibles = "Коллекционные издания"
    case printedMaterials = "Печатная продукция"
    case homeGoods = "Для дома"
    case other = "Другое"
    
    // Получение подкатегорий для основной категории
    func getSubcategories() -> [MerchSubcategory] {
        switch self {
        case .clothing:
            return [.tshirt, .hoodie, .jacket, .hat, .socks, .other]
        case .music:
            return [.cd, .vinyl, .digital, .cassette, .other]
        case .accessory:
            return [.badge, .keychain, .necklace, .bracelet, .phoneCase, .other]
        case .collectibles:
            return [.figurine, .poster, .autograph, .limitedEdition, .other]
        case .printedMaterials:
            return [.photobook, .book, .magazine, .postcard, .sticker, .other]
        case .homeGoods:
            return [.mug, .pillow, .blanket, .poster, .other]
        case .other:
            return [.other]
        }
    }
    
    // Получение иконки для категории
    var icon: String {
        switch self {
        case .clothing: return "tshirt"
        case .music: return "music.note"
        case .accessory: return "bag"
        case .collectibles: return "star"
        case .printedMaterials: return "book"
        case .homeGoods: return "house"
        case .other: return "ellipsis.circle"
        }
    }
}

// Подкатегории мерча
enum MerchSubcategory: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    
    // Одежда
    case tshirt = "Футболка"
    case hoodie = "Худи"
    case jacket = "Куртка"
    case hat = "Шапка/Кепка"
    case socks = "Носки"
    
    // Музыкальная продукция
    case cd = "CD"
    case vinyl = "Винил"
    case digital = "Цифровые релизы"
    case cassette = "Кассета"
    
    // Аксессуары
    case badge = "Значок"
    case keychain = "Брелок"
    case necklace = "Подвеска"
    case bracelet = "Браслет"
    case phoneCase = "Чехол для телефона"
    
    // Коллекционные издания
    case figurine = "Фигурка"
    case poster = "Постер"
    case autograph = "Автограф"
    case limitedEdition = "Лимитированное издание"
    
    // Печатная продукция
    case photobook = "Фотокнига"
    case book = "Книга"
    case magazine = "Журнал"
    case postcard = "Открытка"
    case sticker = "Наклейка"
    
    // Для дома
    case mug = "Кружка"
    case pillow = "Подушка"
    case blanket = "Плед"
    
    // Общее
    case other = "Другое"
    
    // Получение иконки для подкатегории
    var icon: String {
        switch self {
        case .tshirt: return "tshirt"
        case .hoodie: return "tshirt.fill"
        case .jacket: return "figure.walk"
        case .hat: return "bolt.horizontal.circle"
        case .socks: return "arrow.down.to.line"
        case .cd: return "opticaldisc"
        case .vinyl: return "circle.dashed"
        case .digital: return "square.and.arrow.down"
        case .cassette: return "rectangle"
        case .badge: return "circle.fill"
        case .keychain: return "link"
        case .necklace: return "circle.bottomhalf.filled"
        case .bracelet: return "circle.dashed"
        case .phoneCase: return "iphone"
        case .figurine: return "person.2.fill"
        case .poster: return "photo"
        case .autograph: return "signature"
        case .limitedEdition: return "star.fill"
        case .photobook: return "photo.on.rectangle"
        case .book: return "book"
        case .magazine: return "magazine"
        case .postcard: return "mail.stack"
        case .sticker: return "square.on.square"
        case .mug: return "cup.and.saucer"
        case .pillow: return "rectangle.fill"
        case .blanket: return "rectangle.grid.2x2"
        case .other: return "ellipsis.circle"
        }
    }
}

// Обновленная структура товара
struct MerchItem: Identifiable, Codable {
    @DocumentID var id: String?

    var name: String
    var description: String
    var price: Double
    var category: MerchCategory
    var subcategory: MerchSubcategory
    var stock: MerchSizeStock
    var imageUrls: [String]? // URLs изображений товара
    var lowStockThreshold: Int // Порог для предупреждения о низком запасе
    var groupId: String
    var createdAt: Date
    var updatedAt: Date
    
    // Проверка, есть ли низкий запас
    var hasLowStock: Bool {
        return stock.S <= lowStockThreshold ||
               stock.M <= lowStockThreshold ||
               stock.L <= lowStockThreshold ||
               stock.XL <= lowStockThreshold ||
               stock.XXL <= lowStockThreshold
    }
    
    // Получение общего количества товара
    var totalStock: Int {
        return stock.S + stock.M + stock.L + stock.XL + stock.XXL
    }
    
    // Инициализатор с значениями по умолчанию
    init(id: String? = nil,
         name: String,
         description: String,
         price: Double,
         category: MerchCategory,
         subcategory: MerchSubcategory? = nil,
         stock: MerchSizeStock,
         imageUrls: [String]? = nil,
         lowStockThreshold: Int = 5,
         groupId: String,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.category = category
        
        // Если подкатегория не указана или не соответствует категории, выбираем первую подходящую
        if let sub = subcategory, category.getSubcategories().contains(sub) {
            self.subcategory = sub
        } else {
            self.subcategory = category.getSubcategories().first ?? .other
        }
        
        self.stock = stock
        self.imageUrls = imageUrls
        self.lowStockThreshold = lowStockThreshold
        self.groupId = groupId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
