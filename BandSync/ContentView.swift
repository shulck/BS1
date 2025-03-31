//
//  ContentView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState.shared

    var body: some View {
        Group {
            if !appState.isLoggedIn {
                LoginView()
            } else if appState.user?.groupId == nil {
                // Пользователь вошел, но не имеет группы
                GroupSelectionView()
            } else {
                // Пользователь вошел и имеет группу
                MainTabView()
            }
        }
        .onAppear {
            appState.refreshAuthState()
        }
    }
}
