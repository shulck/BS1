import SwiftUI

struct MainTabView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var permissionService = PermissionService.shared
    @State private var selectedTab = 0
    @State private var showMoreMenu = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Основные табы (всегда видимые)
            
            // 1. Календарь
            if permissionService.currentUserHasAccess(to: .calendar) {
                CalendarView()
                    .tabItem {
                        Label("Календарь", systemImage: "calendar")
                    }
                    .tag(0)
            }
            
            // 2. Финансы
            if permissionService.currentUserHasAccess(to: .finances) {
                FinancesView()
                    .tabItem {
                        Label("Финансы", systemImage: "dollarsign.circle")
                    }
                    .tag(1)
            }
            
            // 3. Мерч
            if permissionService.currentUserHasAccess(to: .merchandise) {
                MerchView()
                    .tabItem {
                        Label("Мерч", systemImage: "bag")
                    }
                    .tag(2)
            }
            
            // 4. Чаты
            if permissionService.currentUserHasAccess(to: .chats) {
                ChatsView()
                    .tabItem {
                        Label("Чаты", systemImage: "message")
                    }
                    .tag(3)
            }
            
            // 5. Еще (More)
            MoreMenuView()
                .tabItem {
                    Label("Еще", systemImage: "ellipsis")
                }
                .tag(4)
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
        case 1: isCurrentTabAccessible = modules.contains(.finances)
        case 2: isCurrentTabAccessible = modules.contains(.merchandise)
        case 3: isCurrentTabAccessible = modules.contains(.chats)
        case 4: isCurrentTabAccessible = true // More меню всегда доступно
        default: isCurrentTabAccessible = false
        }
        
        // Если текущая вкладка недоступна, выбираем первую доступную
        if !isCurrentTabAccessible {
            // По умолчанию всегда должна быть доступна вкладка More
            selectedTab = 4
            
            // Проверяем доступность других вкладок в порядке приоритета
            if modules.contains(.calendar) {
                selectedTab = 0
            } else if modules.contains(.finances) {
                selectedTab = 1
            } else if modules.contains(.merchandise) {
                selectedTab = 2
            } else if modules.contains(.chats) {
                selectedTab = 3
            }
        }
    }
}

// Представление для меню "Еще"
struct MoreMenuView: View {
    @StateObject private var permissionService = PermissionService.shared
    @State private var selectedOption: String? = nil
    
    var body: some View {
        NavigationView {
            List {
                // Сетлисты
                if permissionService.currentUserHasAccess(to: .setlists) {
                    NavigationLink(destination: SetlistView()) {
                        Label("Сетлисты", systemImage: "music.note.list")
                    }
                }
                
                // Задачи
                if permissionService.currentUserHasAccess(to: .tasks) {
                    NavigationLink(destination: TasksView()) {
                        Label("Задачи", systemImage: "checklist")
                    }
                }
                
                // Контакты
                if permissionService.currentUserHasAccess(to: .contacts) {
                    NavigationLink(destination: ContactsView()) {
                        Label("Контакты", systemImage: "person.crop.circle")
                    }
                }
                
                // Настройки (доступны всем)
                NavigationLink(destination: SettingsView()) {
                    Label("Настройки", systemImage: "gear")
                }
                
                // Админ-панель
                if permissionService.currentUserHasAccess(to: .admin) {
                    NavigationLink(destination: AdminPanelView()) {
                        Label("Админка", systemImage: "person.3")
                    }
                }
            }
            .navigationTitle("Еще")
            .listStyle(InsetGroupedListStyle())
        }
    }
}
