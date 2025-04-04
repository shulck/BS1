import SwiftUI

struct MainTabView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var permissionService = PermissionService.shared
    @State private var selectedTab = 0
    @State private var showPermissionAlert = false
    @State private var inaccessibleModule: ModuleType?
    @State private var previousValidTab = 4 // Default to More tab
    
    // Map tab indices to modules
    private let tabModules: [Int: ModuleType] = [
        0: .calendar,
        1: .finances,
        2: .merchandise,
        3: .chats,
        4: nil // More tab has no direct module
    ]
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Main tabs based on permissions
                
                // 1. Calendar
                if permissionService.currentUserHasAccess(to: .calendar) {
                    CalendarView()
                        .tabItem {
                            Label("Calendar", systemImage: "calendar")
                        }
                        .tag(0)
                }
                
                // 2. Finances
                if permissionService.currentUserHasAccess(to: .finances) {
                    FinancesView()
                        .tabItem {
                            Label("Finances", systemImage: "dollarsign.circle")
                        }
                        .tag(1)
                }
                
                // 3. Merch
                if permissionService.currentUserHasAccess(to: .merchandise) {
                    MerchView()
                        .tabItem {
                            Label("Merch", systemImage: "bag")
                        }
                        .tag(2)
                }
                
                // 4. Chats
                if permissionService.currentUserHasAccess(to: .chats) {
                    ChatsView()
                        .tabItem {
                            Label("Chats", systemImage: "message")
                        }
                        .tag(3)
                }
                
                // 5. More - always available
                MoreMenuView()
                    .tabItem {
                        Label("More", systemImage: "ellipsis")
                    }
                    .tag(4)
            }
            .onChange(of: selectedTab) { newTab in
                handleTabChange(to: newTab)
            }
            
            // Loading overlay during permission checks
            if permissionService.isLoading {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                    )
            }
        }
        .onAppear {
            // Load user data when view appears
            appState.loadUser()
            
            // Ensure valid tab is selected after a brief delay
            // to allow permissions to load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                ensureValidTab()
            }
        }
        .onChange(of: permissionService.permissions) { _ in
            // When permissions change, revalidate current tab
            ensureValidTab()
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text("Access Denied"),
                message: Text(inaccessibleModule.map { "You don't have access to the \($0.displayName) module." } ?? "You don't have access to this module."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Handle tab change and validate access
    private func handleTabChange(to newTab: Int) {
        // Skip validation for More tab (always accessible)
        if newTab == 4 {
            previousValidTab = newTab
            return
        }
        
        // Get module for selected tab
        guard let module = tabModules[newTab] else {
            previousValidTab = newTab
            return
        }
        
        // Check access
        if !permissionService.currentUserHasAccess(to: module) {
            // User doesn't have access, show alert and revert to previous tab
            inaccessibleModule = module
            showPermissionAlert = true
            
            // Revert to previous valid tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                selectedTab = previousValidTab
            }
        } else {
            // Tab is accessible, update previous valid tab
            previousValidTab = newTab
        }
    }
    
    // Ensure a valid tab is selected
    private func ensureValidTab() {
        // Skip if permissions are still loading
        if permissionService.isLoading {
            return
        }
        
        // Check if current tab is accessible
        let currentTabValid = isTabValid(selectedTab)
        
        if !currentTabValid {
            // Find first accessible tab
            let validTab = findFirstValidTab()
            
            // Update selected tab and previous valid tab
            selectedTab = validTab
            previousValidTab = validTab
        }
    }
    
    // Check if a tab is valid based on permissions
    private func isTabValid(_ tab: Int) -> Bool {
        // More tab is always valid
        if tab == 4 {
            return true
        }
        
        // Check module access
        if let module = tabModules[tab] {
            return permissionService.currentUserHasAccess(to: module)
        }
        
        return false
    }
    
    // Find first valid tab
    private func findFirstValidTab() -> Int {
        // Check each tab in order
        for tabIndex in 0...3 {
            if let module = tabModules[tabIndex],
               permissionService.currentUserHasAccess(to: module) {
                return tabIndex
            }
        }
        
        // If no tabs are accessible, return More tab
        return 4
    }
}

// View for the "More" menu with improved permission handling
struct MoreMenuView: View {
    @StateObject private var permissionService = PermissionService.shared
    @State private var showPermissionAlert = false
    @State private var inaccessibleModule: ModuleType?
    
    var body: some View {
        NavigationView {
            List {
                // Setlists - Only show if user has access
                if permissionService.currentUserHasAccess(to: .setlists) {
                    NavigationLink(destination: SetlistView()) {
                        Label("Setlists", systemImage: "music.note.list")
                    }
                }
                
                // Tasks - Only show if user has access
                if permissionService.currentUserHasAccess(to: .tasks) {
                    NavigationLink(destination: TasksView()) {
                        Label("Tasks", systemImage: "checklist")
                    }
                }
                
                // Contacts - Only show if user has access
                if permissionService.currentUserHasAccess(to: .contacts) {
                    NavigationLink(destination: ContactsView()) {
                        Label("Contacts", systemImage: "person.crop.circle")
                    }
                }
                
                // Settings (available to everyone)
                NavigationLink(destination: NotificationSettingsView()) {
                    Label("Settings", systemImage: "gear")
                }
                
                // Admin panel - Only show if user has access
                if permissionService.currentUserHasAccess(to: .admin) {
                    NavigationLink(destination: AdminPanelView()) {
                        Label("Admin", systemImage: "person.3")
                    }
                }
                
                // Logout option
                Section {
                    Button(action: {
                        AppState.shared.logout()
                    }) {
                        Label("Log Out", systemImage: "arrow.right.square")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("More")
            .listStyle(InsetGroupedListStyle())
            .alert(isPresented: $showPermissionAlert) {
                Alert(
                    title: Text("Access Denied"),
                    message: Text(inaccessibleModule.map { "You don't have access to the \($0.displayName) module." } ?? "You don't have access to this module."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // Helper method to ensure user has access to a module
    private func checkAccess(for module: ModuleType) -> Bool {
        let hasAccess = permissionService.currentUserHasAccess(to: module)
        
        if !hasAccess {
            inaccessibleModule = module
            showPermissionAlert = true
        }
        
        return hasAccess
    }
}
