import Foundation
import FirebaseFirestore

enum SortOrder {
    case dateAscending
    case dateDescending
    case amountAscending
    case amountDescending
}

extension FinanceFilter {
    func applyFilter(completion: @escaping ([FinanceRecord]) -> Void) {
        // Получаем доступ к базе данных
        let db = Firestore.firestore()
        
        // Создаем базовый запрос к коллекции финансов
        guard let groupId = AppState.shared.user?.groupId else {
            completion([])
            return
        }
        
        var query: Query = db.collection("finances")
            .whereField("groupId", isEqualTo: groupId)
        
        // Применяем фильтр по типу
        if let type = selectedTypes.first {
            query = query.whereField("type", isEqualTo: type.rawValue)
        }
        
        // Выполняем запрос
        query.getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                completion([])
                return
            }
            
            // Преобразуем документы в модели
            let records = documents.compactMap { try? $0.data(as: FinanceRecord.self) }
            
            // Локальная постфильтрация
            let filteredRecords = records.filter { record in
                // Фильтр по категориям
                guard selectedCategories.isEmpty || selectedCategories.contains(record.category) else {
                    return false
                }
                
                // Фильтр по диапазону дат
                if let startDate = startDate, record.date < startDate {
                    return false
                }
                
                if let endDate = endDate, record.date > endDate {
                    return false
                }
                
                // Фильтр по сумме
                if let minAmount = minAmount, record.amount < minAmount {
                    return false
                }
                
                if let maxAmount = maxAmount, record.amount > maxAmount {
                    return false
                }
                
                return true
            }
            
            // Сортировка
            let sortedRecords: [FinanceRecord]
            switch sortOrder {
            case .dateAscending:
                sortedRecords = filteredRecords.sorted { $0.date < $1.date }
            case .dateDescending:
                sortedRecords = filteredRecords.sorted { $0.date > $1.date }
            case .amountAscending:
                sortedRecords = filteredRecords.sorted { $0.amount < $1.amount }
            case .amountDescending:
                sortedRecords = filteredRecords.sorted { $0.amount > $1.amount }
            }
            
            completion(sortedRecords)
        }
    }
}
