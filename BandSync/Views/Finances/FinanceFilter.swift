//
//  FinanceFilter.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//

import Foundation
import FirebaseFirestore

extension FinanceFilter {
    // Публичный метод для фильтрации финансовых записей
    func applyFilter(in service: FinanceService, completion: @escaping ([FinanceRecord]) -> Void) {
        // Получаем доступ к базе данных через сервис
        let db = Firestore.firestore()
        
        // Создаем базовый запрос к коллекции финансов
        var query: Query = db.collection("finances")
            .whereField("groupId", isEqualTo: service.currentGroupId)
        
        // Применяем фильтры по типу
        if let type = type {
            query = query.whereField("type", isEqualTo: type.rawValue)
        }
        
        // Применяем фильтры по категории
        if let category = category {
            query = query.whereField("category", isEqualTo: category)
        }
        
        // Применяем фильтры по диапазону дат
        if let startDate = startDate, let endDate = endDate {
            query = query.whereField("date", isGreaterThanOrEqualTo: startDate)
                         .whereField("date", isLessThanOrEqualTo: endDate)
        }
        
        // Выполняем запрос
        query.getDocuments { (snapshot: QuerySnapshot?, error: Error?) in
            // Обработка ошибок
            if let error = error {
                print("Ошибка фильтрации: \(error.localizedDescription)")
                completion([])
                return
            }
            
            // Преобразование документов в модели
            guard let documents = snapshot?.documents else {
                completion([])
                return
            }
            
            let filteredRecords = documents.compactMap { doc -> FinanceRecord? in
                do {
                    return try doc.data(as: FinanceRecord.self)
                } catch {
                    print("Ошибка декодирования: \(error)")
                    return nil
                }
            }
            
            // Применяем дополнительную сортировку
            let sortedRecords = sortRecords(filteredRecords)
            
            // Возвращаем результат
            completion(sortedRecords)
        }
    }
    
    // Приватный метод сортировки
    private func sortRecords(_ records: [FinanceRecord]) -> [FinanceRecord] {
        return records.sorted {
            switch sortOrder {
            case .dateAscending:
                return $0.date < $1.date
            case .dateDescending:
                return $0.date > $1.date
            case .amountAscending:
                return $0.amount < $1.amount
            case .amountDescending:
                return $0.amount > $1.amount
            case .none:
                return false
            }
        }
    }
}
