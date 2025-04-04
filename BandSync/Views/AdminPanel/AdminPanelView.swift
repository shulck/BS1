import SwiftUI

struct AdminPanelView: View {
    @StateObject private var groupService = GroupService.shared
    @StateObject private var permissionService = PermissionService.shared
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isRefreshing = false
    @State private var showExportSheet = false
    @State private var exportData: Data?
    
    var body: some View {
        ZStack {
            List {
                Section(header: Text("Group management")) {
                    // Group settings
                    NavigationLink(destination: GroupSettingsView()) {
                        Label("Group settings", systemImage: "gearshape")
                    }
                    
                    // Member management
                    NavigationLink(destination: UsersListView()) {
                        Label("Group members", systemImage: "person.3")
                    }
                    
                    // Permission management
                    NavigationLink(destination: PermissionsView()) {
                        Label("Permissions", systemImage: "lock.shield")
                    }
                    
                    // Module management
                    NavigationLink(destination: ModuleManagementView()) {
                        Label("App modules", systemImage: "square.grid.2x2")
                    }
                }
                
                Section(header: Text("Group information")) {
                    // Number of members
                    Label("Members: \(groupService.groupMembers.count)", systemImage: "person.2")
                    
                    Label("Pending approvals: \(groupService.pendingMembers.count)", systemImage: "person.badge.clock")
                    
                    if let group = groupService.group {
                        Label("Group name: \(group.name)", systemImage: "music.mic")
                        
                        // Invitation code with copy option
                        HStack {
                            Label("Invitation code: \(group.code)", systemImage: "qrcode")
                            Spacer()
                            Button {
                                UIPasteboard.general.string = group.code
                                showCopiedAlert()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Section(header: Text("Tools")) {
                    Button(action: {
                        testNotifications()
                    }) {
                        Label("Test notifications", systemImage: "bell")
                    }
                    
                    Button(action: {
                        exportGroupData()
                    }) {
                        Label("Export group data", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isRefreshing)
                    
                    Button(action: {
                        reloadData()
                    }) {
                        Label("Reload group data", systemImage: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }
                
                // Error messages
                if let error = groupService.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                if let error = permissionService.errorMessage {
                    Section {
                        Text("Permission error: \(error)")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Admin panel")
            .onAppear {
                loadData()
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .refreshable {
                reloadData()
            }
            .sheet(isPresented: $showExportSheet) {
                if let data = exportData {
                    ShareSheet(items: [data])
                }
            }
            
            // Loading overlay
            if groupService.isLoading || permissionService.isLoading || isRefreshing {
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
    }
    
    // Load initial data
    private func loadData() {
        if let groupId = AppState.shared.user?.groupId {
            groupService.fetchGroup(by: groupId)
            permissionService.fetchPermissions(for: groupId)
        }
    }
    
    // Reload all data
    private func reloadData() {
        isRefreshing = true
        
        if let groupId = AppState.shared.user?.groupId {
            groupService.fetchGroup(by: groupId)
            permissionService.fetchPermissions(for: groupId)
            
            // Set a timeout for the refresh
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isRefreshing = false
            }
        } else {
            isRefreshing = false
            showAlert(title: "Error", message: "No group ID available")
        }
    }
    
    // Test notifications
    private func testNotifications() {
        // Schedule a test notification
        NotificationManager.shared.scheduleLocalNotification(
            title: "Test Notification",
            body: "This is a test notification from BandSync admin panel",
            date: Date().addingTimeInterval(5),
            identifier: "admin_test_\(UUID().uuidString)"
        ) { success in
            if success {
                showAlert(title: "Notification Scheduled", message: "A test notification will appear in 5 seconds")
            } else {
                showAlert(title: "Notification Error", message: "Failed to schedule test notification. Please check notification permissions in Settings.")
            }
        }
    }
    
    // Export group data
    private func exportGroupData() {
        isRefreshing = true
        
        groupService.exportGroupData { result in
            isRefreshing = false
            
            switch result {
            case .success(let data):
                exportData = data
                showExportSheet = true
            case .failure(let error):
                showAlert(title: "Export Error", message: error.localizedDescription)
            }
        }
    }
    
    // Helper to show a simple alert
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
    
    // Show copy confirmation
    private func showCopiedAlert() {
        alertTitle = "Copied"
        alertMessage = "Invitation code copied to clipboard"
        showAlert = true
    }
}

// ShareSheet for exporting data
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
