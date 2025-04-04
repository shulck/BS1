import SwiftUI

struct PermissionsView: View {
    @StateObject private var permissionService = PermissionService.shared
    @State private var selectedModule: ModuleType?
    @State private var showModuleEditor = false
    @State private var showResetConfirmation = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var successMessage = ""
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            List {
                // Information section
                Section(header: Text("Access management")) {
                    Text("Here you can configure which roles have access to different application modules.")
                        .font(.footnote)
                }
                
                // Modules section
                Section(header: Text("Modules")) {
                    ForEach(ModuleType.allCases) { module in
                        Button {
                            selectedModule = module
                            showModuleEditor = true
                        } label: {
                            HStack {
                                Image(systemName: module.icon)
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text(module.displayName)
                                        .foregroundColor(.primary)
                                    
                                    // Display roles with access
                                    Text(accessRolesText(for: module))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                    }
                }
                
                // Reset settings
                Section {
                    Button("Reset to default values") {
                        showResetConfirmation = true
                    }
                    .foregroundColor(.red)
                }
                
                // Error message
                if let serviceError = permissionService.errorMessage {
                    Section {
                        Text(serviceError)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Permissions")
            .sheet(isPresented: $showModuleEditor) {
                if let module = selectedModule {
                    ModulePermissionEditorView(module: module) { result in
                        switch result {
                        case .success(let message):
                            successMessage = message
                            showSuccessAlert = true
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    }
                }
            }
            .alert("Reset permissions?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetPermissions()
                }
            } message: {
                Text("This action will reset all permission settings to default values. Are you sure?")
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK") {}
            } message: {
                Text(successMessage)
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                loadPermissions()
            }
            .refreshable {
                loadPermissions()
            }
            
            // Loading overlay
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
    }
    
    // Format text of roles with access
    private func accessRolesText(for module: ModuleType) -> String {
        let roles = permissionService.getRolesWithAccess(to: module)
        
        if roles.isEmpty {
            return "No access"
        }
        
        return roles.map { $0.rawValue }.joined(separator: ", ")
    }
    
    // Load permissions
    private func loadPermissions() {
        if let groupId = AppState.shared.user?.groupId {
            permissionService.fetchPermissions(for: groupId)
        }
    }
    
    // Reset permissions
    private func resetPermissions() {
        permissionService.resetToDefaults()
        
        // Show success message
        successMessage = "Permissions have been reset to default values"
        showSuccessAlert = true
    }
    
    // Module permission editor view
    struct ModulePermissionEditorView: View {
        let module: ModuleType
        @StateObject private var permissionService = PermissionService.shared
        @Environment(\.dismiss) var dismiss
        
        // Completion handler
        var completion: ((Result<String, Error>) -> Void)? = nil
        
        // Local state of selected roles
        @State private var selectedRoles: Set<UserModel.UserRole> = []
        @State private var originalRoles: Set<UserModel.UserRole> = []
        
        init(module: ModuleType, completion: ((Result<String, Error>) -> Void)? = nil) {
            self.module = module
            self.completion = completion
        }
        
        var body: some View {
            NavigationView {
                ZStack {
                    Form {
                        Section(header: Text("Module access")) {
                            Text("Select roles that will have access to the '\(module.displayName)' module")
                                .font(.footnote)
                        }
                        
                        // Special warning for admin module
                        if module == .admin {
                            Section {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text("Admin role cannot be removed from this module for security reasons.")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        
                        Section(header: Text("Roles")) {
                            ForEach(UserModel.UserRole.allCases, id: \.self) { role in
                                Button {
                                    toggleRole(role)
                                } label: {
                                    HStack {
                                        Text(role.rawValue)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if selectedRoles.contains(role) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                // Disable toggling admin access for admin panel
                                .disabled(module == .admin && role == .admin)
                            }
                        }
                        
                        if let serviceError = permissionService.errorMessage {
                            Section {
                                Text(serviceError)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .navigationTitle(module.displayName)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                dismiss()
                            }
                        }
                        
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                savePermissions()
                            }
                            .disabled(permissionService.isLoading || selectedRoles == originalRoles)
                        }
                    }
                    .onAppear {
                        loadCurrentRoles()
                    }
                    
                    // Loading overlay
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
            }
        }
        
        // Load current roles
        private func loadCurrentRoles() {
            let roles = permissionService.getRolesWithAccess(to: module)
            selectedRoles = Set(roles)
            originalRoles = selectedRoles
        }
        
        // Toggle role selection
        private func toggleRole(_ role: UserModel.UserRole) {
            // Prevent removing admin access from admin module
            if module == .admin && role == .admin {
                return
            }
            
            if selectedRoles.contains(role) {
                selectedRoles.remove(role)
            } else {
                selectedRoles.insert(role)
            }
        }
        
        // Save settings
        private func savePermissions() {
            // Make sure we're not removing admin access from the admin module
            if module == .admin && !selectedRoles.contains(.admin) {
                selectedRoles.insert(.admin)
            }
            
            permissionService.updateModulePermission(
                moduleId: module,
                roles: Array(selectedRoles)
            )
            
            // Wait for operation to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Check for errors
                if let error = permissionService.errorMessage {
                    completion?(.failure(NSError(domain: "PermissionService", code: -1, userInfo: [NSLocalizedDescriptionKey: error])))
                } else {
                    // Success
                    let message = "Permissions for \(module.displayName) updated successfully"
                    completion?(.success(message))
                }
                dismiss()
            }
        }
    }
}
