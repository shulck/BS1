//
//  MerchSaleChannel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  MerchSale.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore

enum MerchSaleChannel: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case concert = "Концерт"
    case online = "Онлайн"
    case partner = "Партнёр"
}

struct MerchSale: Identifiable, Codable {
    @DocumentID var id: String?

    var itemId: String
    var quantity: Int
    var size: String
    var channel: MerchSaleChannel
    var date: Date
    var groupId: String
}
