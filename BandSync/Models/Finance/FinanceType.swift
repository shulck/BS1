// FinanceModel.swift
// Объединённые модели: типы и категории

import Foundation

// MARK: - Тип операции
enum FinanceType: String, Codable, CaseIterable, Identifiable {
    case income = "Доход"
    case expense = "Расход"

    var id: String { rawValue }
}

// MARK: - Категория
enum FinanceCategory: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    // Расходы
    case logistics = "Логистика"
    case accommodation = "Проживание"
    case food = "Питание"
    case gear = "Оборудование"
    case promo = "Продвижение"
    case other = "Другое"

    // Доходы
    case performance = "Выступления"
    case merch = "Мерч"
    case royalties = "Роялти"
    case sponsorship = "Спонсорство"

    static func forType(_ type: FinanceType) -> [FinanceCategory] {
        switch type {
        case .income:
            return [.performance, .merch, .royalties, .sponsorship, .other]
        case .expense:
            return [.logistics, .accommodation, .food, .gear, .promo, .other]
        }
    }
}
