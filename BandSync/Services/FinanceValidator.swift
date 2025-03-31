//
//  FinanceValidator.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  FinanceValidator.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation

struct FinanceValidator {
    static func isValid(record: FinanceRecord) -> Bool {
        return record.amount > 0 && !record.currency.isEmpty && !record.category.isEmpty
    }
}
