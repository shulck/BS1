import Foundation
import UserNotifications
import FirebaseMessaging
import UIKit

final class NotificationManager {
    static let shared = NotificationManager()
    
    // Типы уведомлений
    enum NotificationType: String {
        case event = "event"
        case task = "task"
        case message = "message"
        case system = "system"
    }
    
    // Настройки уведомлений
    struct NotificationSettings: Codable {
        var eventNotificationsEnabled = true
        var taskNotificationsEnabled = true
        var chatNotificationsEnabled = true
        var systemNotificationsEnabled = true
        
        // Интервалы уведомлений для событий (в часах)
        var eventReminderIntervals = [24, 1] // За день и за час
        
        // Интервалы уведомлений для задач (в часах)
        var taskReminderIntervals = [24] // За день
    }
    
    private var settings: NotificationSettings
    
    private init() {
        // Загружаем настройки или используем значения по умолчанию
        if let savedSettings = UserDefaults.standard.data(forKey: "notificationSettings"),
           let decodedSettings = try? JSONDecoder().decode(NotificationSettings.self, from: savedSettings) {
            self.settings = decodedSettings
        } else {
            self.settings = NotificationSettings()
        }
    }
    
    // MARK: - Основные методы
    
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
    
    // Подписка на тему
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
    
    // Отменить конкретное уведомление
    func cancelNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    // Отменить все уведомления
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - Планирование уведомлений
    
    // Запланировать локальное уведомление
    func scheduleLocalNotification(title: String, body: String, date: Date, identifier: String, userInfo: [AnyHashable: Any] = [:], completion: @escaping (Bool) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
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
    
    // MARK: - Интеграция с календарем
    
    // Запланировать уведомление о событии
    func scheduleEventNotification(event: Event) {
        guard settings.eventNotificationsEnabled else { return }
        
        // Проверяем, что дата события в будущем
        guard event.date > Date() else { return }
        
        // Очищаем старые уведомления для этого события
        if let eventId = event.id {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["event_day_before_\(eventId)", "event_hour_before_\(eventId)"]
            )
        }
        
        // Добавляем уведомления на основе настроек интервалов
        for hoursBefore in settings.eventReminderIntervals {
            if let reminderDate = Calendar.current.date(byAdding: .hour, value: -hoursBefore, to: event.date) {
                if reminderDate > Date() {
                    let title: String
                    let body: String
                    
                    if hoursBefore == 24 {
                        title = "Завтра: \(event.title)"
                        body = "Напоминаем о событии завтра в \(formatTime(event.date))"
                    } else if hoursBefore == 1 {
                        title = "Скоро: \(event.title)"
                        body = "Через час: \(event.title)"
                    } else {
                        title = "Событие: \(event.title)"
                        body = "Через \(hoursBefore) ч.: \(event.title)"
                    }
                    
                    let identifier = "event_\(hoursBefore)h_before_\(event.id ?? UUID().uuidString)"
                    
                    let userInfo: [String: Any] = [
                        "type": NotificationType.event.rawValue,
                        "eventId": event.id ?? "",
                        "eventTitle": event.title,
                        "eventDate": event.date.timeIntervalSince1970
                    ]
                    
                    scheduleLocalNotification(
                        title: title,
                        body: body,
                        date: reminderDate,
                        identifier: identifier,
                        userInfo: userInfo
                    ) { _ in }
                }
            }
        }
    }
    
    // MARK: - Интеграция с задачами
    
    // Запланировать уведомление о задаче
    func scheduleTaskNotification(task: TaskModel) {
        guard settings.taskNotificationsEnabled, !task.completed else { return }
        
        // Проверяем, что дата задачи в будущем
        guard task.dueDate > Date() else { return }
        
        // Очищаем старые уведомления для этой задачи
        if let taskId = task.id {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["task_day_before_\(taskId)"]
            )
        }
        
        // Добавляем уведомления на основе настроек интервалов
        for hoursBefore in settings.taskReminderIntervals {
            if let reminderDate = Calendar.current.date(byAdding: .hour, value: -hoursBefore, to: task.dueDate) {
                if reminderDate > Date() {
                    let title: String
                    let body: String
                    
                    if hoursBefore == 24 {
                        title = "Задача на завтра"
                        body = "\(task.title) - срок истекает завтра"
                    } else {
                        title = "Задача: \(task.title)"
                        body = "Срок выполнения через \(hoursBefore) ч."
                    }
                    
                    let identifier = "task_\(hoursBefore)h_before_\(task.id ?? UUID().uuidString)"
                    
                    let userInfo: [String: Any] = [
                        "type": NotificationType.task.rawValue,
                        "taskId": task.id ?? "",
                        "taskTitle": task.title,
                        "taskDueDate": task.dueDate.timeIntervalSince1970
                    ]
                    
                    scheduleLocalNotification(
                        title: title,
                        body: body,
                        date: reminderDate,
                        identifier: identifier,
                        userInfo: userInfo
                    ) { _ in }
                }
            }
        }
    }
    
    // MARK: - Интеграция с чатами
    
    // Отправить уведомление о новом сообщении
    func sendMessageNotification(chatId: String, chatName: String, message: Message, forUsers userIds: [String]) {
        guard settings.chatNotificationsEnabled else { return }
        
        // Для локальных уведомлений используем следующий подход
        // В реальном приложении здесь был бы код для отправки пуш-уведомлений через FCM
        
        let title = "Новое сообщение в \(chatName)"
        let body = message.text
        
        let userInfo: [String: Any] = [
            "type": NotificationType.message.rawValue,
            "chatId": chatId,
            "chatName": chatName,
            "messageId": message.id ?? "",
            "messageText": message.text,
            "senderId": message.senderId
        ]
        
        // Отправляем локальное уведомление только если не от текущего пользователя
        if message.senderId != AuthService.shared.currentUserUID() {
            scheduleLocalNotification(
                title: title,
                body: body,
                date: Date(),
                identifier: "message_\(message.id ?? UUID().uuidString)",
                userInfo: userInfo
            ) { _ in }
        }
    }
    
    // MARK: - Настройки уведомлений
    
    // Получить настройки уведомлений
    func getNotificationSettings() -> NotificationSettings {
        return settings
    }
    
    // Обновить настройки уведомлений
    func updateNotificationSettings(_ newSettings: NotificationSettings) {
        settings = newSettings
        saveSettings()
        
        // При изменении настроек может потребоваться перепланирование уведомлений
        if let groupId = AppState.shared.user?.groupId {
            reschedulePendingNotifications(for: groupId)
        }
    }
    
    // Обновить конкретную настройку
    func updateSetting<T>(keyPath: WritableKeyPath<NotificationSettings, T>, value: T) {
        settings[keyPath: keyPath] = value
        saveSettings()
    }
    
    // Сохранить настройки
    private func saveSettings() {
        if let encodedData = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encodedData, forKey: "notificationSettings")
        }
    }
    
    // Перепланировать все уведомления
    private func reschedulePendingNotifications(for groupId: String) {
        // Отменяем все запланированные уведомления
        cancelAllNotifications()
        
        // Перепланируем уведомления для событий
        EventService.shared.fetchEvents(for: groupId)
        for event in EventService.shared.events {
            scheduleEventNotification(event: event)
        }
        
        // Перепланируем уведомления для задач
        TaskService.shared.fetchTasks(for: groupId)
        for task in TaskService.shared.tasks {
            if !task.completed {
                scheduleTaskNotification(task: task)
            }
        }
    }
    
    // MARK: - Вспомогательные методы
    
    // Форматирование времени для уведомлений
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
