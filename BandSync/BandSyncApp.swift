//
//  BandSyncApp.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI
import FirebaseCore

@main
struct BandSyncApp: App {
    // Регистрируем AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(AppState.shared)
        }
    }
}
