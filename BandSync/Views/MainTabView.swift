//
//  MainTabView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var appState = AppState.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarView()
                .tabItem {
                    Label("Календарь", systemImage: "calendar")
                }
                .tag(0)

            SetlistView()
                .tabItem {
                    Label("Сетлисты", systemImage: "music.note.list")
                }
                .tag(1)

            FinancesView()
                .tabItem {
                    Label("Финансы", systemImage: "dollarsign.circle")
                }
                .tag(2)

            MerchView()
                .tabItem {
                    Label("Мерч", systemImage: "bag")
                }
                .tag(3)

            TasksView()
                .tabItem {
                    Label("Задачи", systemImage: "checklist")
                }
                .tag(4)

            ChatsView()
                .tabItem {
                    Label("Чаты", systemImage: "message")
                }
                .tag(5)

            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gear")
                }
                .tag(6)

            if appState.user?.role == .admin {
                AdminPanelView()
                    .tabItem {
                        Label("Админка", systemImage: "person.3")
                    }
                    .tag(7)
            }
        }
        .onAppear {
            appState.loadUser()
        }
    }
}
