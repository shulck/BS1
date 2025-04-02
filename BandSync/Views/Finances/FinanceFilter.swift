import Foundation

struct FinanceFilter {
    var startDate: Date?
    var endDate: Date?
    var minAmount: Double?
    var maxAmount: Double?
    var selectedTypes: [FinanceType] = []
    var selectedCategories: [String] = []
    
    enum SortOrder {
        case dateAscending
        case dateDescending
        case amountAscending
        case amountDescending
    }
    
    var sortOrder: SortOrder = .dateDescending
    
    var isActive: Bool {
        return startDate != nil ||
               endDate != nil ||
               minAmount != nil ||
               maxAmount != nil ||
               !selectedTypes.isEmpty ||
               !selectedCategories.isEmpty
    }
    
    mutating func reset() {
        startDate = nil
        endDate = nil
        minAmount = nil
        maxAmount = nil
        selectedTypes = []
        selectedCategories = []
        sortOrder = .dateDescending
    }
    
    func apply(to records: [FinanceRecord]) -> [FinanceRecord] {
        let filteredRecords = records.filter { record in
            // Фильтр по типу
            guard selectedTypes.isEmpty || selectedTypes.contains(record.type) else { return false }
            
            // Фильтр по категории
            guard selectedCategories.isEmpty || selectedCategories.contains(record.category) else { return false }
            
            // Фильтр по дате начала
            if let startDate = startDate, record.date < startDate {
                return false
            }
            
            // Фильтр по дате окончания
            if let endDate = endDate, record.date > endDate {
                return false
            }
            
            // Фильтр по минимальной сумме
            if let minAmount = minAmount, record.amount < minAmount {
                return false
            }
            
            // Фильтр по максимальной сумме
            if let maxAmount = maxAmount, record.amount > maxAmount {
                return false
            }
            
            return true
        }
        
        // Сортировка
        switch sortOrder {
        case .dateAscending:
            return filteredRecords.sorted { $0.date < $1.date }
        case .dateDescending:
            return filteredRecords.sorted { $0.date > $1.date }
        case .amountAscending:
            return filteredRecords.sorted { $0.amount < $1.amount }
        case .amountDescending:
            return filteredRecords.sorted { $0.amount > $1.amount }
        }
    }
}
