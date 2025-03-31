//
//  AppDelegate.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  AppDelegate.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Настройка Firebase
        FirebaseApp.configure()
        
        // Настройка уведомлений
        UNUserNotificationCenter.current().delegate = self
        
        // Настройка Firebase Messaging
        Messaging.messaging().delegate = self
        
        return true
    }
    
    // Получение FCM токена устройства
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            print("FCM token: \(token)")
            // Здесь можно отправить токен на сервер для сохранения
        }
    }
    
    // Получение удаленных уведомлений, когда приложение в foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Показываем уведомление даже если приложение открыто
        completionHandler([.banner, .sound, .badge])
    }
    
    // Обработка нажатия на уведомление
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Обработка нажатия на уведомление
        // Здесь можно добавить логику для перехода на нужный экран
        
        completionHandler()
    }
    
    // Получение токена устройства для удаленных уведомлений
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // Обработка ошибки регистрации удаленных уведомлений
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}