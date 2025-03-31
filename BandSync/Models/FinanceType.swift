//
//  FinanceType.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  FinanceRecord.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore

enum FinanceType: String, Codable {
    case income = "Доход"
    case expense = "Расход"
}

struct FinanceRecord: Identifiable, Codable {
    @DocumentID var id: String?
    
    var type: FinanceType
    var amount: Double
    var currency: String
    var category: String
    var details: String
    var date: Date
    var receiptUrl: String?
    var groupId: String
}
