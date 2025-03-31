//
//  EventService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import Foundation
import FirebaseFirestore
import Network

final class EventService: ObservableObject {
    static let shared = EventService()

    @Published var events: [Event] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isOfflineMode: Bool = false
    
    private let db = Firestore.firestore()
    private var networkMonitor = NWPathMonitor()
    private var hasLoadedFromCache = false
    
    init() {
        // Инициализация мониторинга сети
        setupNetworkMonitoring()
    }
    
    // Настройка мониторинга сети
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let isConnected = path.status == .satisfied
                self?.isOfflineMode = !isConnected
                
                // При восстановлении соединения, обновляем данные
                if isConnected && self?.hasLoadedFromCache == true {
                    if let groupId = AppState.shared.user?.groupId {
                        self?.fetchEvents(for: groupId)
                    }
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }

    func fetchEvents(for groupId: String) {
        isLoading = true
        errorMessage = nil
        
        // Проверяем соединение с сетью
        if isOfflineMode {
            loadFromCache(groupId: groupId)
            return
        }
        
        db.collection("events")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Ошибка загрузки событий: \(error.localizedDescription)"
                        self.loadFromCache(groupId: groupId)
                        return
                    }
                    
                    if let docs = snapshot?.documents {
                        let events = docs.compactMap { try? $0.data(as: Event.self) }
                        self.events = events
                        
                        // Сохраняем в кэш
                        CacheService.shared.cacheEvents(events, forGroupId: groupId)
                    }
                }
            }
    }
    
    // Загрузка из кэша
    private func loadFromCache(groupId: String) {
        if let cachedEvents = CacheService.shared.getCachedEvents(forGroupId: groupId) {
            self.events = cachedEvents
            self.hasLoadedFromCache = true
            self.isLoading = false
            
            if isOfflineMode {
                self.errorMessage = "Loaded from cache (offline mode)"
            }
        } else {
            self.errorMessage = "No data available in offline mode"
            self.isLoading = false
        }
    }

    func addEvent(_ event: Event, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        // Проверяем соединение с сетью
        if isOfflineMode {
            errorMessage = "Cannot add events in offline mode"
            isLoading = false
            completion(false)
            return
        }
        
        do {
            _ = try db.collection("events").addDocument(from: event) { [weak self] error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Ошибка добавления события: \(error.localizedDescription)"
                        completion(false)
                    } else {
                        // Обновляем локальные данные
                        self.fetchEvents(for: event.groupId)
                        
                        // Планируем уведомления
                        NotificationManager.shared.scheduleEventNotification(event: event)
                        
                        completion(true)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Ошибка сериализации события: \(error)"
                completion(false)
            }
        }
    }

    func updateEvent(_ event: Event, completion: @escaping (Bool) -> Void) {
        guard let id = event.id else {
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Проверяем соединение с сетью
        if isOfflineMode {
            errorMessage = "Cannot update events in offline mode"
            isLoading = false
            completion(false)
            return
        }
        
        do {
            try db.collection("events").document(id).setData(from: event) { [weak self] error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Ошибка обновления события: \(error.localizedDescription)"
                        completion(false)
                    } else {
                        // Обновляем локальные данные
                        self.fetchEvents(for: event.groupId)
                        
                        // Обновляем уведомления
                        // Сначала отменяем старые
                        NotificationManager.shared.cancelNotification(withIdentifier: "event_day_before_\(id)")
                        NotificationManager.shared.cancelNotification(withIdentifier: "event_hour_before_\(id)")
                        // Затем планируем новые
                        NotificationManager.shared.scheduleEventNotification(event: event)
                        
                        completion(true)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Ошибка сериализации события: \(error)"
                completion(false)
            }
        }
    }

    func deleteEvent(_ event: Event) {
        guard let id = event.id else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Проверяем соединение с сетью
        if isOfflineMode {
            errorMessage = "Cannot delete events in offline mode"
            isLoading = false
            return
        }
        
        db.collection("events").document(id).delete { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Ошибка удаления: \(error.localizedDescription)"
                } else if let groupId = AppState.shared.user?.groupId {
                    // Обновляем локальные данные
                    self.fetchEvents(for: groupId)
                    
                    // Отменяем уведомления
                    NotificationManager.shared.cancelNotification(withIdentifier: "event_day_before_\(id)")
                    NotificationManager.shared.cancelNotification(withIdentifier: "event_hour_before_\(id)")
                }
            }
        }
    }
    
    // Получение событий, отфильтрованных по дате
    func eventsForDate(_ date: Date) -> [Event] {
        return events.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }
    
    // Получение предстоящих событий
    func upcomingEvents(limit: Int = 5) -> [Event] {
        let now = Date()
        return events
            .filter { $0.date > now }
            .sorted { $0.date < $1.date }
            .prefix(limit)
            .map { $0 }
    }
    
    // Очистить все данные
    func clearAllData() {
        events = []
        errorMessage = nil
    }
    
    deinit {
        networkMonitor.cancel()
    }
}
