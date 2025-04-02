//
//  BandSyncApp.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI
import FirebaseCore

@main
struct BandSyncApp: App {
    // Регистрируем AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        // Не вызывайте print() в инициализаторе структуры App
        // Это приводит к ошибкам компиляции
    }
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(AppState.shared)
                .onAppear {
                    print("SplashView: появился")
                    // Гарантируем, что Firebase уже инициализирован
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("SplashView: запускаем отложенное обновление состояния авторизации")
                        AppState.shared.refreshAuthState()
                    }
                }
        }
    }
}
