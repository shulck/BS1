//
//  EventStatus.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  EventStatus.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation

enum EventStatus: String, Codable, CaseIterable, Identifiable {
    case booked = "Забронировано"
    case confirmed = "Подтверждено"

    var id: String { rawValue }
}
