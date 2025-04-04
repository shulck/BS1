import Foundation
import FirebaseFirestore
import Combine

final class PermissionService: ObservableObject {
    static let shared = PermissionService()
    
    // Published properties for SwiftUI updates
    @Published var permissions: PermissionModel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isPermissionsInitialized = false
    
    // Local cache for offline access
    private var cachedPermissions: [String: PermissionModel] = [:]
    private let cacheKey = "permissions_cache"
    
    // Network state tracking
    private var isOffline = false
    
    // Constants
    private let retryLimit = 3
    private let retryDelay: TimeInterval = 2.0
    
    // Firebase references
    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // Queue for serializing permission creation operations
    private let operationQueue = DispatchQueue(label: "com.bandsync.permissionservice.queue")
    
    // Initialization flag to prevent duplicate creation attempts
    private var isCreatingPermissions = false
    
    // Permissions creation lock to prevent race conditions
    private let permissionsLock = NSLock()
    
    init() {
        print("PermissionService: initialized")
        loadCachedPermissions()
        
        // Automatic permission check when user changes
        AppState.shared.$user
            .removeDuplicates()
            .sink { [weak self] user in
                guard let self = self else { return }
                
                if let groupId = user?.groupId {
                    print("PermissionService: user has group ID \(groupId), fetching permissions")
                    self.fetchPermissions(for: groupId)
                } else {
                    print("PermissionService: user has no group, clearing permissions")
                    self.clearPermissions()
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        print("PermissionService: deinitializing")
        removeAllListeners()
    }
    
    // MARK: - Permission Fetching
    
    /// Fetches permissions for the specified group
    /// - Parameter groupId: The ID of the group to fetch permissions for
    func fetchPermissions(for groupId: String) {
        print("PermissionService: fetching permissions for group \(groupId)")
        isLoading = true
        errorMessage = nil
        
        // First attempt to use cached permissions if offline
        if isOffline, let cached = cachedPermissions[groupId] {
            print("PermissionService: using cached permissions for group \(groupId)")
            DispatchQueue.main.async {
                self.permissions = cached
                self.isPermissionsInitialized = true
                self.isLoading = false
            }
            return
        }
        
        // Remove existing listener for this group
        removeListener(for: groupId)
        
        // Add a real-time listener for permissions
        let listener = db.collection("permissions")
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    print("PermissionService: error fetching permissions: \(error.localizedDescription)")
                    self.isOffline = true
                    self.errorMessage = "Error loading permissions: \(error.localizedDescription)"
                    
                    // Try to use cached data if available
                    if let cached = self.cachedPermissions[groupId] {
                        print("PermissionService: using cached permissions after error")
                        DispatchQueue.main.async {
                            self.permissions = cached
                            self.isPermissionsInitialized = true
                        }
                    }
                    return
                }
                
                self.isOffline = false
                
                if let document = snapshot?.documents.first {
                    do {
                        let permissionModel = try document.data(as: PermissionModel.self)
                        print("PermissionService: successfully loaded permissions for group \(groupId)")
                        
                        DispatchQueue.main.async {
                            self.permissions = permissionModel
                            self.isPermissionsInitialized = true
                            
                            // Cache the permissions
                            self.cachedPermissions[groupId] = permissionModel
                            self.savePermissionsToCache()
                        }
                    } catch {
                        print("PermissionService: error parsing permissions: \(error.localizedDescription)")
                        self.errorMessage = "Error parsing permission data: \(error.localizedDescription)"
                    }
                } else {
                    print("PermissionService: no permissions found for group \(groupId), creating default")
                    // If no permissions for group, create default ones
                    self.createDefaultPermissions(for: groupId)
                }
            }
        
        // Store listener for cleanup
        listeners[groupId] = listener
    }
    
    // MARK: - Default Permissions Creation
    
    /// Creates default permissions for a new group
    /// - Parameter groupId: The ID of the group to create permissions for
    func createDefaultPermissions(for groupId: String) {
        // Use lock to prevent multiple concurrent creation attempts
        permissionsLock.lock()
        defer { permissionsLock.unlock() }
        
        // If already creating permissions, don't start another creation process
        if isCreatingPermissions {
            print("PermissionService: already creating permissions, skipping")
            return
        }
        
        print("PermissionService: creating default permissions for group \(groupId)")
        isCreatingPermissions = true
        isLoading = true
        errorMessage = nil
        
        // First check if permissions already exist to prevent duplicates
        db.collection("permissions")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("PermissionService: error checking existing permissions: \(error.localizedDescription)")
                    self.errorMessage = "Error checking permissions: \(error.localizedDescription)"
                    self.isLoading = false
                    self.isCreatingPermissions = false
                    return
                }
                
                // If permissions already exist, don't create again
                if let snapshot = snapshot, !snapshot.documents.isEmpty {
                    print("PermissionService: permissions already exist for group \(groupId)")
                    
                    // Try to parse and use the existing permissions
                    if let permissionDocument = snapshot.documents.first,
                       let permissionModel = try? permissionDocument.data(as: PermissionModel.self) {
                        DispatchQueue.main.async {
                            self.permissions = permissionModel
                            self.isPermissionsInitialized = true
                            self.isLoading = false
                            self.isCreatingPermissions = false
                            
                            // Cache the permissions
                            self.cachedPermissions[groupId] = permissionModel
                            self.savePermissionsToCache()
                        }
                    } else {
                        self.isLoading = false
                        self.isCreatingPermissions = false
                    }
                    return
                }
                
                // Create default permissions with retry mechanism
                self.createNewPermissionsWithRetry(for: groupId, retryCount: 0)
            }
    }
    
    /// Creates new permissions with retry mechanism
    /// - Parameters:
    ///   - groupId: The ID of the group to create permissions for
    ///   - retryCount: Current retry attempt
    private func createNewPermissionsWithRetry(for groupId: String, retryCount: Int) {
        print("PermissionService: creating permissions for group \(groupId), attempt \(retryCount + 1)")
        
        // Default permissions for all modules
        let defaultModules: [PermissionModel.ModulePermission] = ModuleType.allCases.map { moduleType in
            // By default, admins and managers have access to everything
            // Regular members - only to calendar, setlists, tasks, and chats
            let roles: [UserModel.UserRole]
            
            switch moduleType {
            case .admin:
                // Only admins can access admin panel
                roles = [.admin]
            case .finances, .merchandise, .contacts:
                // Finances, merch, and contacts require manager rights
                roles = [.admin, .manager]
            case .calendar, .setlists, .tasks, .chats:
                // Basic modules available to all
                roles = [.admin, .manager, .musician, .member]
            }
            
            return PermissionModel.ModulePermission(moduleId: moduleType, roleAccess: roles)
        }
        
        let newPermissions = PermissionModel(groupId: groupId, modules: defaultModules)
        
        do {
            _ = try db.collection("permissions").addDocument(from: newPermissions) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("PermissionService: error creating permissions: \(error.localizedDescription)")
                    
                    // Retry if under the retry limit
                    if retryCount < self.retryLimit {
                        print("PermissionService: retrying permission creation in \(self.retryDelay) seconds")
                        DispatchQueue.main.asyncAfter(deadline: .now() + self.retryDelay) {
                            self.createNewPermissionsWithRetry(for: groupId, retryCount: retryCount + 1)
                        }
                    } else {
                        print("PermissionService: max retries reached, giving up")
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.isCreatingPermissions = false
                            self.errorMessage = "Error creating permissions: \(error.localizedDescription)"
                        }
                    }
                    return
                }
                
                print("PermissionService: successfully created permissions for group \(groupId)")
                
                // Fetch the newly created permissions
                self.db.collection("permissions")
                    .whereField("groupId", isEqualTo: groupId)
                    .getDocuments { snapshot, error in
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.isCreatingPermissions = false
                            
                            if let error = error {
                                print("PermissionService: error fetching new permissions: \(error.localizedDescription)")
                                self.errorMessage = "Error fetching new permissions: \(error.localizedDescription)"
                                return
                            }
                            
                            if let document = snapshot?.documents.first,
                               let permissionModel = try? document.data(as: PermissionModel.self) {
                                self.permissions = permissionModel
                                self.isPermissionsInitialized = true
                                
                                // Cache the permissions
                                self.cachedPermissions[groupId] = permissionModel
                                self.savePermissionsToCache()
                            }
                        }
                    }
            }
        } catch {
            print("PermissionService: error serializing permissions: \(error.localizedDescription)")
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.isCreatingPermissions = false
                self.errorMessage = "Error creating permissions: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Update Permissions
    
    /// Updates permission for a specific module
    /// - Parameters:
    ///   - moduleId: The module to update permissions for
    ///   - roles: The roles that should have access to the module
    func updateModulePermission(moduleId: ModuleType, roles: [UserModel.UserRole]) {
        guard let permissionId = permissions?.id else {
            print("PermissionService: no permission ID found for update")
            self.errorMessage = "No permissions found"
            return
        }
        
        // Special validation: admin module must always be accessible to admins
        var updatedRoles = roles
        if moduleId == .admin && !roles.contains(.admin) {
            print("PermissionService: adding admin role to admin module as it's required")
            updatedRoles.append(.admin)
        }
        
        print("PermissionService: updating module \(moduleId.rawValue) with roles: \(updatedRoles.map { $0.rawValue }.joined(separator: ", "))")
        isLoading = true
        errorMessage = nil
        
        // Find existing module to update
        if var modules = permissions?.modules {
            if let index = modules.firstIndex(where: { $0.moduleId == moduleId }) {
                // Update existing module
                modules[index] = PermissionModel.ModulePermission(moduleId: moduleId, roleAccess: updatedRoles)
                
                // Prepare update data
                let modulesData = modules.map { [
                    "moduleId": $0.moduleId.rawValue,
                    "roleAccess": $0.roleAccess.map { $0.rawValue }
                ]}
                
                // Update with retry mechanism
                updatePermissionsWithRetry(
                    permissionId: permissionId,
                    data: ["modules": modulesData],
                    modules: modules,
                    retryCount: 0
                )
            } else {
                // Module not found, add new one
                print("PermissionService: adding new module \(moduleId.rawValue)")
                let newModule = PermissionModel.ModulePermission(moduleId: moduleId, roleAccess: updatedRoles)
                modules.append(newModule)
                
                // Prepare update data
                let modulesData = modules.map { [
                    "moduleId": $0.moduleId.rawValue,
                    "roleAccess": $0.roleAccess.map { $0.rawValue }
                ]}
                
                // Update with retry mechanism
                updatePermissionsWithRetry(
                    permissionId: permissionId,
                    data: ["modules": modulesData],
                    modules: modules,
                    retryCount: 0
                )
            }
        } else {
            print("PermissionService: no modules found in permissions")
            isLoading = false
            errorMessage = "No modules found in permissions"
        }
    }
    
    /// Updates permissions with retry mechanism
    /// - Parameters:
    ///   - permissionId: The ID of the permission document to update
    ///   - data: The data to update
    ///   - modules: The updated modules list
    ///   - retryCount: Current retry attempt
    private func updatePermissionsWithRetry(permissionId: String, data: [String: Any], modules: [PermissionModel.ModulePermission], retryCount: Int) {
        print("PermissionService: updating permissions, attempt \(retryCount + 1)")
        
        db.collection("permissions").document(permissionId).updateData(data) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("PermissionService: error updating permissions: \(error.localizedDescription)")
                
                // Retry if under the retry limit
                if retryCount < self.retryLimit {
                    print("PermissionService: retrying permission update in \(self.retryDelay) seconds")
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.retryDelay) {
                        self.updatePermissionsWithRetry(
                            permissionId: permissionId,
                            data: data,
                            modules: modules,
                            retryCount: retryCount + 1
                        )
                    }
                } else {
                    print("PermissionService: max retries reached, giving up")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Error updating permissions: \(error.localizedDescription)"
                    }
                }
                return
            }
            
            print("PermissionService: successfully updated permissions")
            
            // Update local data and cache
            DispatchQueue.main.async {
                self.isLoading = false
                
                // Update the local modules
                self.permissions?.modules = modules
                
                // Update cache
                if let groupId = self.permissions?.groupId {
                    self.cachedPermissions[groupId] = self.permissions
                    self.savePermissionsToCache()
                }
            }
        }
    }
    
    // MARK: - Reset Permissions
    
    /// Resets permissions to default values
    func resetToDefaults() {
        guard let groupId = AppState.shared.user?.groupId,
              let permissionId = permissions?.id else {
            print("PermissionService: cannot reset permissions, missing group or permission ID")
            errorMessage = "Cannot reset permissions, missing group or permission ID"
            return
        }
        
        print("PermissionService: resetting permissions to defaults for group \(groupId)")
        isLoading = true
        errorMessage = nil
        
        // Delete current permissions and create new ones
        db.collection("permissions").document(permissionId).delete { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("PermissionService: error deleting permissions: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Error resetting permissions: \(error.localizedDescription)"
                }
            } else {
                print("PermissionService: permissions deleted, creating new default ones")
                
                // Create new default permissions
                self.createDefaultPermissions(for: groupId)
            }
        }
    }
    
    // MARK: - Permission Checking
    
    /// Checks if a role has access to a module
    /// - Parameters:
    ///   - moduleId: The module to check access for
    ///   - role: The role to check
    /// - Returns: True if the role has access, false otherwise
    func hasAccess(to moduleId: ModuleType, role: UserModel.UserRole) -> Bool {
        // Admins always have access to everything
        if role == .admin {
            return true
        }
        
        // If permissions not initialized yet, use default rules for basic access
        if !isPermissionsInitialized {
            print("PermissionService: permissions not initialized, using default rules for \(moduleId.rawValue)")
            switch moduleId {
            case .calendar, .setlists, .tasks, .chats:
                return true
            case .finances, .merchandise, .contacts:
                return role == .manager
            case .admin:
                return false
            }
        }
        
        // Check permissions
        if let modulePermission = permissions?.modules.first(where: { $0.moduleId == moduleId }) {
            return modulePermission.hasAccess(role: role)
        }
        
        print("PermissionService: module \(moduleId.rawValue) not found in permissions, using default")
        
        // If module not found, use default permissions
        switch moduleId {
        case .admin:
            return role == .admin
        case .finances, .merchandise, .contacts:
            return role == .admin || role == .manager
        case .calendar, .setlists, .tasks, .chats:
            return true
        }
    }
    
    /// Checks if the current user has access to a module
    /// - Parameter moduleId: The module to check access for
    /// - Returns: True if the current user has access, false otherwise
    func currentUserHasAccess(to moduleId: ModuleType) -> Bool {
        guard let userRole = AppState.shared.user?.role else {
            print("PermissionService: cannot check access, user role unknown")
            return false
        }
        
        let hasAccess = hasAccess(to: moduleId, role: userRole)
        print("PermissionService: user with role \(userRole.rawValue) \(hasAccess ? "has" : "does not have") access to \(moduleId.rawValue)")
        return hasAccess
    }
    
    /// Gets all modules that a role has access to
    /// - Parameter role: The role to check
    /// - Returns: Array of accessible modules
    func getAccessibleModules(for role: UserModel.UserRole) -> [ModuleType] {
        // Admins have access to everything
        if role == .admin {
            return ModuleType.allCases
        }
        
        // If permissions not initialized yet, use default rules
        if !isPermissionsInitialized {
            print("PermissionService: permissions not initialized, using default module access for role \(role.rawValue)")
            switch role {
            case .admin:
                return ModuleType.allCases
            case .manager:
                return ModuleType.allCases.filter { $0 != .admin }
            case .musician, .member:
                return [.calendar, .setlists, .tasks, .chats]
            }
        }
        
        // For other roles, filter modules by permissions
        return permissions?.modules
            .filter { $0.hasAccess(role: role) }
            .map { $0.moduleId } ?? []
    }
    
    /// Gets all modules that the current user has access to
    /// - Returns: Array of accessible modules
    func getCurrentUserAccessibleModules() -> [ModuleType] {
        guard let userRole = AppState.shared.user?.role else {
            print("PermissionService: cannot get accessible modules, user role unknown")
            return []
        }
        
        let modules = getAccessibleModules(for: userRole)
        print("PermissionService: user has access to \(modules.count) modules")
        return modules
    }
    
    /// Checks if the current user has edit permission for a module
    /// - Parameter moduleId: The module to check edit permission for
    /// - Returns: True if the user has edit permission, false otherwise
    func hasEditPermission(for moduleId: ModuleType) -> Bool {
        guard let role = AppState.shared.user?.role else {
            return false
        }
        
        // Only admins and managers can edit
        let hasPermission = role == .admin || role == .manager
        print("PermissionService: user with role \(role.rawValue) \(hasPermission ? "has" : "does not have") edit permission for \(moduleId.rawValue)")
        return hasPermission
    }
    
    /// Gets roles that have access to a module
    /// - Parameter moduleId: The module to check
    /// - Returns: Array of roles with access
    func getRolesWithAccess(to moduleId: ModuleType) -> [UserModel.UserRole] {
        if let modulePermission = permissions?.modules.first(where: { $0.moduleId == moduleId }) {
            return modulePermission.roleAccess
        }
        
        print("PermissionService: module \(moduleId.rawValue) not found in permissions, using default roles")
        
        // If module not found, return default roles
        switch moduleId {
        case .admin:
            return [.admin]
        case .finances, .merchandise, .contacts:
            return [.admin, .manager]
        case .calendar, .setlists, .tasks, .chats:
            return [.admin, .manager, .musician, .member]
        }
    }
    
    // MARK: - Offline Support
    
    /// Saves permissions to cache
    private func savePermissionsToCache() {
        print("PermissionService: saving permissions to cache")
        
        do {
            let data = try JSONEncoder().encode(cachedPermissions)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            print("PermissionService: error saving permissions to cache: \(error.localizedDescription)")
        }
    }
    
    /// Loads permissions from cache
    private func loadCachedPermissions() {
        print("PermissionService: loading permissions from cache")
        
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            print("PermissionService: no cached permissions found")
            return
        }
        
        do {
            cachedPermissions = try JSONDecoder().decode([String: PermissionModel].self, from: data)
            print("PermissionService: loaded \(cachedPermissions.count) cached permission sets")
        } catch {
            print("PermissionService: error loading cached permissions: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    /// Clears all permissions data
    private func clearPermissions() {
        permissions = nil
        isPermissionsInitialized = false
        removeAllListeners()
    }
    
    /// Removes a listener for a specific group
    /// - Parameter groupId: The group ID to remove listener for
    private func removeListener(for groupId: String) {
        print("PermissionService: removing listener for group \(groupId)")
        
        if let listener = listeners[groupId] {
            listener.remove()
            listeners.removeValue(forKey: groupId)
        }
    }
    
    /// Removes all listeners
    private func removeAllListeners() {
        print("PermissionService: removing all listeners")
        
        for (_, listener) in listeners {
            listener.remove()
        }
        listeners.removeAll()
    }
}
