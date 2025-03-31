//
//  MainTabView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var permissionService = PermissionService.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Динамически добавляем только те вкладки, к которым у пользователя есть доступ
            
            // Календарь
            if permissionService.currentUserHasAccess(to: .calendar) {
                CalendarView()
                    .tabItem {
                        Label("Календарь", systemImage: "calendar")
                    }
                    .tag(0)
            }
            
            // Сетлисты
            if permissionService.currentUserHasAccess(to: .setlists) {
                SetlistView()
                    .tabItem {
                        Label("Сетлисты", systemImage: "music.note.list")
                    }
                    .tag(1)
            }
            
            // Финансы
            if permissionService.currentUserHasAccess(to: .finances) {
                FinancesView()
                    .tabItem {
                        Label("Финансы", systemImage: "dollarsign.circle")
                    }
                    .tag(2)
            }
            
            // Мерч
            if permissionService.currentUserHasAccess(to: .merchandise) {
                MerchView()
                    .tabItem {
                        Label("Мерч", systemImage: "bag")
                    }
                    .tag(3)
            }
            
            // Задачи
            if permissionService.currentUserHasAccess(to: .tasks) {
                TasksView()
                    .tabItem {
                        Label("Задачи", systemImage: "checklist")
                    }
                    .tag(4)
            }
            
            // Чаты
            if permissionService.currentUserHasAccess(to: .chats) {
                ChatsView()
                    .tabItem {
                        Label("Чаты", systemImage: "message")
                    }
                    .tag(5)
            }
            
            // Контакты
            if permissionService.currentUserHasAccess(to: .contacts) {
                ContactsView()
                    .tabItem {
                        Label("Контакты", systemImage: "person.crop.circle")
                    }
                    .tag(6)
            }
            
            // Настройки (доступны всем)
            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gear")
                }
                .tag(7)
            
            // Админ-панель
            if permissionService.currentUserHasAccess(to: .admin) {
                AdminPanelView()
                    .tabItem {
                        Label("Админка", systemImage: "person.3")
                    }
                    .tag(8)
            }
        }
        .onAppear {
            appState.loadUser()
            
            // Если текущая вкладка недоступна, переключаемся на первую доступную
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                ensureValidTab()
            }
        }
        .onChange(of: permissionService.permissions) { _ in
            // При изменении разрешений проверяем, что текущая вкладка доступна
            ensureValidTab()
        }
    }
    
    // Обеспечивает, что выбрана доступная вкладка
    private func ensureValidTab() {
        let modules = permissionService.getCurrentUserAccessibleModules()
        
        // Проверяем, имеет ли пользователь доступ к текущей вкладке
        var isCurrentTabAccessible = false
        
        switch selectedTab {
        case 0: isCurrentTabAccessible = modules.contains(.calendar)
        case 1: isCurrentTabAccessible = modules.contains(.setlists)
        case 2: isCurrentTabAccessible = modules.contains(.finances)
        case 3: isCurrentTabAccessible = modules.contains(.merchandise)
        case 4: isCurrentTabAccessible = modules.contains(.tasks)
        case 5: isCurrentTabAccessible = modules.contains(.chats)
        case 6: isCurrentTabAccessible = modules.contains(.contacts)
        case 7: isCurrentTabAccessible = true // Настройки всегда доступны
        case 8: isCurrentTabAccessible = modules.contains(.admin)
        default: isCurrentTabAccessible = false
        }
        
        // Если текущая вкладка недоступна, выбираем первую доступную
        if !isCurrentTabAccessible {
            // По умолчанию всегда должны быть доступны настройки
            selectedTab = 7
            
            // Проверяем доступность других вкладок в порядке приоритета
            if modules.contains(.calendar) {
                selectedTab = 0
            } else if modules.contains(.setlists) {
                selectedTab = 1
            } else if modules.contains(.tasks) {
                selectedTab = 4
            } else if modules.contains(.chats) {
                selectedTab = 5
            }
        }
    }
}
