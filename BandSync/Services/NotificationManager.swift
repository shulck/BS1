//
//  NotificationManager.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  NotificationManager.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import Foundation
import UserNotifications
import FirebaseMessaging

final class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {} 
    
    // Запрос разрешения на уведомления
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("Ошибка запроса разрешения на уведомления: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                // Регистрация для удаленных уведомлений
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                
                completion(granted)
            }
        )
    }
    
    // Проверка статуса разрешений
    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
    
    // Подписка на тему (например, для группового чата)
    func subscribe(to topic: String) {
        Messaging.messaging().subscribe(toTopic: topic) { error in
            if let error = error {
                print("Ошибка подписки на тему \(topic): \(error.localizedDescription)")
            } else {
                print("Успешная подписка на тему: \(topic)")
            }
        }
    }
    
    // Отписка от темы
    func unsubscribe(from topic: String) {
        Messaging.messaging().unsubscribe(fromTopic: topic) { error in
            if let error = error {
                print("Ошибка отписки от темы \(topic): \(error.localizedDescription)")
            } else {
                print("Успешная отписка от темы: \(topic)")
            }
        }
    }
    
    // Запланировать локальное уведомление
    func scheduleLocalNotification(title: String, body: String, date: Date, identifier: String, completion: @escaping (Bool) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Создаем компоненты даты для триггера
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // Создаем запрос на уведомление
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Добавляем запрос в центр уведомлений
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Ошибка планирования уведомления: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    // Запланировать уведомление о событии
    func scheduleEventNotification(event: Event) {
        // Проверяем, что дата события в будущем
        guard event.date > Date() else { return }
        
        // Уведомление за день до события
        if let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: event.date) {
            if dayBefore > Date() {
                scheduleLocalNotification(
                    title: "Event Tomorrow".localized,
                    body: "\(event.title) - \(formatTime(event.date))".localized,
                    date: dayBefore,
                    identifier: "event_day_before_\(event.id ?? UUID().uuidString)",
                    completion: { _ in }
                )
            }
        }
        
        // Уведомление за час до события
        if let hourBefore = Calendar.current.date(byAdding: .hour, value: -1, to: event.date) {
            if hourBefore > Date() {
                scheduleLocalNotification(
                    title: "Event in 1 hour".localized,
                    body: "\(event.title) - \(formatTime(event.date))".localized,
                    date: hourBefore,
                    identifier: "event_hour_before_\(event.id ?? UUID().uuidString)",
                    completion: { _ in }
                )
            }
        }
    }
    
    // Запланировать уведомление о задаче
    func scheduleTaskNotification(task: TaskModel) {
        // Проверяем, что срок задачи в будущем и задача не выполнена
        guard task.dueDate > Date(), !task.completed else { return }
        
        // Уведомление за день до срока
        if let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: task.dueDate) {
            if dayBefore > Date() {
                scheduleLocalNotification(
                    title: "Task due tomorrow".localized,
                    body: task.title,
                    date: dayBefore,
                    identifier: "task_day_before_\(task.id ?? UUID().uuidString)",
                    completion: { _ in }
                )
            }
        }
    }
    
    // Отменить все запланированные уведомления
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // Отменить конкретное уведомление
    func cancelNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    // Форматирование времени для уведомлений
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}