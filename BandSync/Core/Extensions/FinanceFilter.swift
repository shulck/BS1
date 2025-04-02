//
//  FinanceFilter.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//


import Foundation
import FirebaseFirestore

// Расширение для добавления функционала фильтрации в FinanceService
extension FinanceService {
    // Структура фильтра
    struct FinanceFilter {
        var types: Set<FinanceType>
        var categories: Set<String>
        var startDate: Date
        var endDate: Date
        var minAmount: Double?
        var maxAmount: Double?
        
        // Применение фильтра к записям
        func apply(to records: [FinanceRecord]) -> [FinanceRecord] {
            return records.filter { record in
                // Фильтр по типу
                guard types.contains(record.type) else { return false }
                
                // Фильтр по категории
                guard categories.contains(record.category) else { return false }
                
                // Фильтр по дате
                guard record.date >= startDate && record.date <= endDate else { return false }
                
                // Фильтр по минимальной сумме
                if let min = minAmount, record.amount < min {
                    return false
                }
                
                // Фильтр по максимальной сумме
                if let max = maxAmount, record.amount > max {
                    return false
                }
                
                return true
            }
        }
    }
    
    // Новые свойства для финансового сервиса
    struct FinanceServiceProperties {
        // Все записи из базы данных
        var allRecords: [FinanceRecord] = []
        
        // Отфильтрованные записи
        var filteredRecords: [FinanceRecord] = []
        
        // Активный фильтр
        var activeFilter: FinanceFilter?
        
        // Состояние фильтрации
        var isFiltered: Bool = false
    }
    
    // Приватное хранилище дополнительных свойств
    private static var _props = FinanceServiceProperties()
    
    // Публичные свойства для доступа к фильтрам
    var activeFilter: FinanceFilter? {
        get { FinanceService._props.activeFilter }
        set { FinanceService._props.activeFilter = newValue }
    }
    
    var isFiltered: Bool {
        get { FinanceService._props.isFiltered }
        set { FinanceService._props.isFiltered = newValue }
    }
    
    // Запросить с учетом фильтров
    func fetchWithFilters(for groupId: String) {
        db.collection("finances")
            .whereField("groupId", isEqualTo: groupId)
            .order(by: "date", descending: true)
            .getDocuments { [weak self] snapshot, error in
                if let docs = snapshot?.documents {
                    let items = docs.compactMap { try? $0.data(as: FinanceRecord.self) }
                    
                    DispatchQueue.main.async {
                        // Сохраняем все записи
                        FinanceService._props.allRecords = items
                        
                        // Применяем фильтр, если он есть
                        if let filter = FinanceService._props.activeFilter {
                            self?.records = filter.apply(to: items)
                        } else {
                            self?.records = items
                        }
                    }
                } else {
                    print("Ошибка загрузки финансов: \(error?.localizedDescription ?? "неизвестно")")
                }
            }
    }
    
    // Применить фильтр
    func applyFilter(_ filter: FinanceFilter) {
        FinanceService._props.activeFilter = filter
        FinanceService._props.isFiltered = true
        self.records = filter.apply(to: FinanceService._props.allRecords)
    }
    
    // Очистить фильтры
    func clearFilters() {
        FinanceService._props.activeFilter = nil
        FinanceService._props.isFiltered = false
        self.records = FinanceService._props.allRecords
    }
    
    // Получить уникальные категории
    func getUniqueCategories() -> [String] {
        let categories = Set(FinanceService._props.allRecords.map { $0.category })
        return Array(categories).sorted()
    }
    
    // Расширение для FinanceType
    func allFinanceTypes() -> [FinanceType] {
        return [.income, .expense]
    }
}

// Расширение для FinanceType чтобы сделать его CaseIterable
extension FinanceType: CaseIterable {
    public static var allCases: [FinanceType] {
        return [.income, .expense]
    }
}