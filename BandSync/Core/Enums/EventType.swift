//
//  EventType.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  EventType.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation

enum EventType: String, Codable, CaseIterable, Identifiable {
    case concert = "Концерт"
    case rehearsal = "Репетиция"
    case meeting = "Встреча"
    case interview = "Интервью"
    case photoshoot = "Фотосессия"
    case personal = "Личное"

    var id: String { rawValue }
}
