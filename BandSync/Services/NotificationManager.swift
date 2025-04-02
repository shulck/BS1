import Foundation
import UserNotifications
import FirebaseMessaging
import UIKit

extension NotificationManager {
    // Улучшенное планирование уведомлений для событий с более гибкими настройками
    func scheduleEventNotification(event: Event) {
        guard settings.eventNotificationsEnabled else { return }
        
        // Проверяем, что дата события в будущем
        guard event.date > Date() else { return }
        
        // Очищаем старые уведомления для этого события
        if let eventId = event.id {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [
                    "event_day_before_\(eventId)",
                    "event_hour_before_\(eventId)",
                    "event_evening_before_\(eventId)"
                ]
            )
        }
        
        // Идентификатор для уникального именования уведомлений
        let notificationId = event.id ?? UUID().uuidString
        
        // Создаем базовую информацию для уведомления
        let title = event.isPersonal ? "Личное событие: \(event.title)" : event.title
        let userInfo: [String: Any] = [
            "type": NotificationType.event.rawValue,
            "eventId": event.id ?? "",
            "eventTitle": event.title,
            "eventDate": event.date.timeIntervalSince1970,
            "isPersonal": event.isPersonal
        ]
        
        // Добавляем уведомление за день до события
        if settings.eventReminderIntervals.contains(24) {
            if let notificationDate = Calendar.current.date(byAdding: .day, value: -1, to: event.date) {
                if notificationDate > Date() {
                    let body = "Завтра в \(formatTime(event.date)): \(event.title)"
                    let identifier = "event_day_before_\(notificationId)"
                    
                    scheduleLocalNotification(
                        title: "Напоминание о событии",
                        body: body,
                        date: notificationDate,
                        identifier: identifier,
                        userInfo: userInfo
                    ) { _ in }
                }
            }
        }
        
        // Добавляем уведомление вечером накануне (в 20:00)
        if settings.eventReminderIntervals.contains(12) {
            if let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: event.date) {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: dayBefore)
                components.hour = 20
                components.minute = 0
                
                if let eveningNotificationDate = Calendar.current.date(from: components), eveningNotificationDate > Date() {
                    let tomorrow = Calendar.current.isDateInTomorrow(event.date) ? "Завтра" : formatDate(event.date)
                    let body = "\(tomorrow) в \(formatTime(event.date)): \(event.title)"
                    let identifier = "event_evening_before_\(notificationId)"
                    
                    scheduleLocalNotification(
                        title: "Напоминание о событии",
                        body: body,
                        date: eveningNotificationDate,
                        identifier: identifier,
                        userInfo: userInfo
                    ) { _ in }
                }
            }
        }
        
        // Добавляем уведомление за час до события
        if settings.eventReminderIntervals.contains(1) {
            if let notificationDate = Calendar.current.date(byAdding: .hour, value: -1, to: event.date) {
                if notificationDate > Date() {
                    let body = "Событие через час: \(event.title)"
                    let identifier = "event_hour_before_\(notificationId)"
                    
                    scheduleLocalNotification(
                        title: "Скоро событие",
                        body: body,
                        date: notificationDate,
                        identifier: identifier,
                        userInfo: userInfo
                    ) { _ in }
                }
            }
        }
        
        // Для личных событий добавляем дополнительное уведомление утром того же дня (в 8:00)
        if event.isPersonal {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: event.date)
            components.hour = 8
            components.minute = 0
            
            if let morningNotificationDate = Calendar.current.date(from: components),
               morningNotificationDate > Date() && morningNotificationDate < event.date {
                let body = "Сегодня в \(formatTime(event.date)): \(event.title)"
                let identifier = "event_morning_of_\(notificationId)"
                
                scheduleLocalNotification(
                    title: "Личное событие сегодня",
                    body: body,
                    date: morningNotificationDate,
                    identifier: identifier,
                    userInfo: userInfo
                ) { _ in }
            }
        }
    }
    
    // Вспомогательные функции форматирования даты
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
