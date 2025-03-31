//
//  CacheService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  CacheService.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import Foundation
import FirebaseFirestore

final class CacheService {
    static let shared = CacheService()
    
    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        // Получаем папку для кэширования
        cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BandSyncCache")
        
        // Создаем папку, если ее нет
        if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            } catch {
                print("Ошибка создания кэш-директории: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Общие методы кэширования
    
    // Сохранение данных в кэш
    func cacheData<T: Encodable>(_ data: T, forKey key: String) {
        do {
            let data = try encoder.encode(data)
            try data.write(to: cacheDirectory.appendingPathComponent(key))
        } catch {
            print("Ошибка сохранения в кэш данных для ключа \(key): \(error.localizedDescription)")
        }
    }
    
    // Получение данных из кэша
    func loadData<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(type, from: data)
        } catch {
            print("Ошибка загрузки из кэша данных для ключа \(key): \(error.localizedDescription)")
            return nil
        }
    }
    
    // Проверка, есть ли данные в кэше
    func hasCache(forKey key: String) -> Bool {
        return FileManager.default.fileExists(atPath: cacheDirectory.appendingPathComponent(key).path)
    }
    
    // Удаление данных из кэша
    func removeCache(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("Ошибка удаления кэша для ключа \(key): \(error.localizedDescription)")
            }
        }
    }
    
    // Очистка всего кэша
    func clearAllCache() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: nil
            )
            
            for url in contents {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            print("Ошибка очистки кэша: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Специфические методы для разных типов данных
    
    // Кэширование событий
    func cacheEvents(_ events: [Event], forGroupId groupId: String) {
        cacheData(events, forKey: "events_\(groupId)")
    }
    
    // Получение кэшированных событий
    func getCachedEvents(forGroupId groupId: String) -> [Event]? {
        return loadData(forKey: "events_\(groupId)", as: [Event].self)
    }
    
    // Кэширование сетлистов
    func cacheSetlists(_ setlists: [Setlist], forGroupId groupId: String) {
        cacheData(setlists, forKey: "setlists_\(groupId)")
    }
    
    // Получение кэшированных сетлистов
    func getCachedSetlists(forGroupId groupId: String) -> [Setlist]? {
        return loadData(forKey: "setlists_\(groupId)", as: [Setlist].self)
    }
    
    // Кэширование контактов
    func cacheContacts(_ contacts: [Contact], forGroupId groupId: String) {
        cacheData(contacts, forKey: "contacts_\(groupId)")
    }
    
    // Получение кэшированных контактов
    func getCachedContacts(forGroupId groupId: String) -> [Contact]? {
        return loadData(forKey: "contacts_\(groupId)", as: [Contact].self)
    }
    
    // Кэширование задач
    func cacheTasks(_ tasks: [TaskModel], forGroupId groupId: String) {
        cacheData(tasks, forKey: "tasks_\(groupId)")
    }
    
    // Получение кэшированных задач
    func getCachedTasks(forGroupId groupId: String) -> [TaskModel]? {
        return loadData(forKey: "tasks_\(groupId)", as: [TaskModel].self)
    }
    
    // Кэширование финансовых записей
    func cacheFinances(_ records: [FinanceRecord], forGroupId groupId: String) {
        cacheData(records, forKey: "finances_\(groupId)")
    }
    
    // Получение кэшированных финансовых записей
    func getCachedFinances(forGroupId groupId: String) -> [FinanceRecord]? {
        return loadData(forKey: "finances_\(groupId)", as: [FinanceRecord].self)
    }
    
    // Кэширование мерча
    func cacheMerch(_ items: [MerchItem], forGroupId groupId: String) {
        cacheData(items, forKey: "merch_\(groupId)")
    }
    
    // Получение кэшированного мерча
    func getCachedMerch(forGroupId groupId: String) -> [MerchItem]? {
        return loadData(forKey: "merch_\(groupId)", as: [MerchItem].self)
    }
    
    // Кэширование пользователей
    func cacheUsers(_ users: [UserModel], forGroupId groupId: String) {
        cacheData(users, forKey: "users_\(groupId)")
    }
    
    // Получение кэшированных пользователей
    func getCachedUsers(forGroupId groupId: String) -> [UserModel]? {
        return loadData(forKey: "users_\(groupId)", as: [UserModel].self)
    }
    
    // MARK: - Служебные методы
    
    // Получение метаинформации о кэше
    func getCacheInfo() -> [String: Any] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
            )
            
            var totalSize: UInt64 = 0
            var fileCount = 0
            var oldestDate: Date = Date()
            
            for url in contents {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attributes[.size] as? UInt64,
                   let creationDate = attributes[.creationDate] as? Date {
                    totalSize += size
                    fileCount += 1
                    
                    if creationDate < oldestDate {
                        oldestDate = creationDate
                    }
                }
            }
            
            return [
                "totalSize": totalSize,
                "fileCount": fileCount,
                "oldestCache": oldestDate
            ]
        } catch {
            print("Ошибка получения информации о кэше: \(error.localizedDescription)")
            return [
                "totalSize": 0,
                "fileCount": 0,
                "oldestCache": Date()
            ]
        }
    }
    
    // Очистка старого кэша (старше 30 дней)
    func clearOldCache() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.creationDateKey]
            )
            
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            
            for url in contents {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    try FileManager.default.removeItem(at: url)
                }
            }
        } catch {
            print("Ошибка очистки старого кэша: \(error.localizedDescription)")
        }
    }
}