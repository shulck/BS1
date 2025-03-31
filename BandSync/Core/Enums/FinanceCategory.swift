//
//  FinanceCategory.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  FinanceCategory.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation

enum FinanceCategory: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case logistics = "Логистика"
    case accommodation = "Проживание"
    case food = "Питание"
    case gear = "Оборудование"
    case promo = "Продвижение"
    case performance = "Выступления"
    case merch = "Мерч"
    case royalties = "Роялти"
    case sponsorship = "Спонсорство"
    case other = "Другое"

    static func forType(_ type: FinanceType) -> [FinanceCategory] {
        switch type {
        case .income:
            return [.performance, .merch, .royalties, .sponsorship, .other]
        case .expense:
            return [.logistics, .accommodation, .food, .gear, .promo, .other]
        }
    }
}
