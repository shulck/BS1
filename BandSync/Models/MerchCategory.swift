//
//  MerchCategory.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  MerchItem.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore

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
}

struct MerchItem: Identifiable, Codable {
    @DocumentID var id: String?

    var name: String
    var description: String
    var price: Double
    var category: MerchCategory
    var stock: MerchSizeStock
    var groupId: String
}
