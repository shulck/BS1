//
//  MerchSubcategory.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//


import Foundation

enum MerchSubcategory: String, Codable, CaseIterable, Identifiable {
    // Подкатегории для одежды
    case tshirt = "Футболка"
    case hoodie = "Худи"
    case jacket = "Куртка"
    case cap = "Кепка"

    // Подкатегории для музыки
    case vinyl = "Виниловая пластинка"
    case cd = "CD"
    case tape = "Кассета"

    // Подкатегории для аксессуаров
    case poster = "Постер"
    case sticker = "Стикер"
    case pin = "Значок"
    case keychain = "Брелок"

    // Другое
    case other = "Другое"

    var id: String { rawValue }

    // Добавляем свойство icon, которое используется в приложении
    var icon: String {
        switch self {
        case .tshirt: return "tshirt"
        case .hoodie: return "person.crop.circle"
        case .jacket: return "person.crop.square"
        case .cap: return "face.smiling"
        case .vinyl: return "opticaldiscdrive"
        case .cd: return "disc"
        case .tape: return "rectangle"
        case .poster: return "doc.richtext"
        case .sticker: return "note.text"
        case .pin: return "pin"
        case .keychain: return "key"
        case .other: return "ellipsis"
        }
    }

    // Получение подкатегорий для конкретной категории
    static func subcategories(for category: MerchCategory) -> [MerchSubcategory] {
        switch category {
        case .clothing:
            return [.tshirt, .hoodie, .jacket, .cap]
        case .music:
            return [.vinyl, .cd, .tape]
        case .accessory:
            return [.poster, .sticker, .pin, .keychain]
        case .other:
            return [.other]
        }
    }
}