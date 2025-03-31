//
//  AppDelegate.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("AppDelegate: начало инициализации")
        
        // Инициализация Firebase через менеджер
        print("AppDelegate: перед инициализацией Firebase")
        FirebaseManager.shared.initialize()
        print("AppDelegate: после инициализации Firebase")
        
        // Настройка уведомлений
        UNUserNotificationCenter.current().delegate = self
        print("AppDelegate: делегат уведомлений установлен")
        
        // Настройка Firebase Messaging
        Messaging.messaging().delegate = self
        print("AppDelegate: делегат Messaging установлен")
        
        // Запрос разрешения на уведомления
        requestNotificationAuthorization()
        
        print("AppDelegate: инициализация завершена")
        return true
    }
    
    // Запрос разрешений на уведомления
    private func requestNotificationAuthorization() {
        print("AppDelegate: запрос разрешения на уведомления")
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                print("AppDelegate: разрешение на уведомления \(granted ? "получено" : "отклонено")")
                if let error = error {
                    print("AppDelegate: ошибка запроса разрешения: \(error)")
                }
            }
        )
        
        UIApplication.shared.registerForRemoteNotifications()
        print("AppDelegate: регистрация для удаленных уведомлений запрошена")
    }
    
    // Получение FCM токена устройства
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            print("AppDelegate: получен FCM токен: \(token)")
        } else {
            print("AppDelegate: не удалось получить FCM токен")
        }
    }
    
    // Получение удаленных уведомлений, когда приложение в foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("AppDelegate: получено уведомление в foreground")
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
        print("AppDelegate: получено нажатие на уведомление: \(userInfo)")
        
        completionHandler()
    }
    
    // Получение токена устройства для удаленных уведомлений
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("AppDelegate: получен токен для удаленных уведомлений: \(token)")
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // Обработка ошибки регистрации удаленных уведомлений
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("AppDelegate: не удалось зарегистрироваться для удаленных уведомлений: \(error.localizedDescription)")
    }
    
    // Обработка открытия URL
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        print("AppDelegate: приложение открыто через URL: \(url)")
        return true
    }
    
    // Обработка перехода приложения в фоновый режим
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("AppDelegate: приложение перешло в фоновый режим")
    }
    
    // Обработка возвращения приложения в активное состояние
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("AppDelegate: приложение возвращается в активное состояние")
    }
}
