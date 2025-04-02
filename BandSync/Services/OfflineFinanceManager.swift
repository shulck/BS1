import Foundation
import Combine
import UIKit  // Добавляем импорт UIKit

class OfflineFinanceManager {
    static let shared = OfflineFinanceManager()

    private let cacheKey = "cached_finance_records"
    private let pendingUploadsKey = "pending_finance_uploads"
    private var cancellables = Set<AnyCancellable>()
    private var isConnected = true
    private var syncTimer: Timer?

    private init() {
        setupNetworkMonitoring()
        startSyncTimer()
    }

    // Мониторинг сетевого подключения
    private func setupNetworkMonitoring() {
        // В реальном приложении здесь будет использоваться Network.framework или Reachability
        // Для примера просто имитируем работу с сетью
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.checkConnection()
            }
            .store(in: &cancellables)
    }

    private func checkConnection() {
        // В реальном приложении здесь будет проверка подключения
        // Для примера имитируем работу с сетью
        isConnected = true
        if isConnected {
            syncPendingUploads()
        }
    }

    // Периодическая синхронизация
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkConnection()
        }
    }

    // Кэширование записей
    func cacheRecord(_ record: FinanceRecord) {
        var cachedRecords = getCachedRecords()
        cachedRecords.append(record)

        if let encoded = try? JSONEncoder().encode(cachedRecords) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }

    // Получение кэшированных записей
    func getCachedRecords() -> [FinanceRecord] {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let records = try? JSONDecoder().decode([FinanceRecord].self, from: data) {
            return records
        }
        return []
    }

    // Добавление записи в очередь на отправку
    func addToPendingUploads(_ record: FinanceRecord) {
        var pendingUploads = getPendingUploads()
        pendingUploads.append(record)

        if let encoded = try? JSONEncoder().encode(pendingUploads) {
            UserDefaults.standard.set(encoded, forKey: pendingUploadsKey)
        }

        // Если есть подключение, пробуем синхронизировать
        if isConnected {
            syncPendingUploads()
        }
    }

    // Получение ожидающих отправки записей
    func getPendingUploads() -> [FinanceRecord] {
        if let data = UserDefaults.standard.data(forKey: pendingUploadsKey),
           let records = try? JSONDecoder().decode([FinanceRecord].self, from: data) {
            return records
        }
        return []
    }

    // Безопасная синхронизация записей
    func syncPendingUploads() {
        let pendingUploads = getPendingUploads()
        guard !pendingUploads.isEmpty else { return }

        // Более безопасная обработка записей
        for record in pendingUploads {
            DispatchQueue.main.async {
                FinanceService.shared.add(record) { [weak self] success in
                    if success {
                        self?.removePendingUpload(record)
                    }
                }
            }
        }
    }

    // Удаление синхронизированной записи из очереди
    private func removePendingUpload(_ record: FinanceRecord) {
        var pendingUploads = getPendingUploads()
        pendingUploads.removeAll { $0.id == record.id }

        if let encoded = try? JSONEncoder().encode(pendingUploads) {
            UserDefaults.standard.set(encoded, forKey: pendingUploadsKey)
        }
    }

    // Очистка кэша
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}

// Расширение FinanceService для работы с кэшем
extension FinanceService {
    func loadCachedRecordsIfNeeded() {
        // Если записей нет или мало, добавляем кэшированные
        if self.records.count < 5 {
            let cachedRecords = OfflineFinanceManager.shared.getCachedRecords()
            if !cachedRecords.isEmpty {
                self.records.append(contentsOf: cachedRecords)
            }
        }
    }
}
