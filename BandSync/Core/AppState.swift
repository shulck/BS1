import Foundation
import Combine
import FirebaseAuth

final class AppState: ObservableObject {
    static let shared = AppState()

    // Published properties
    @Published var isLoggedIn: Bool = false
    @Published var user: UserModel?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var sessionInitialized: Bool = false
    @Published var isOffline: Bool = false
    
    // State transitions
    private enum State {
        case initializing
        case authenticating
        case authenticated(UserModel)
        case unauthenticated
        case error(String)
    }
    
    // Current app state (internal)
    private var state: State = .initializing {
        didSet {
            updatePublishedProperties()
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var authStateDidChangeHandler: AuthStateDidChangeListenerHandle?

    private init() {
        print("AppState: initialization")
        
        // Make sure Firebase is initialized
        FirebaseManager.shared.ensureInitialized()
        
        print("AppState: checking authorization state")
        isLoggedIn = AuthService.shared.isUserLoggedIn()
        print("AppState: isLoggedIn set to \(isLoggedIn)")
        
        print("AppState: setting up subscription to currentUser")
        UserService.shared.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                print("AppState: received user update: \(user != nil ? "user exists" : "user doesn't exist")")
                
                guard let self = self else { return }
                
                if let user = user {
                    // User is authenticated with data loaded
                    self.state = .authenticated(user)
                    
                    // Load permissions if user has a group
                    if let groupId = user.groupId {
                        print("AppState: user has groupId: \(groupId), loading permissions")
                        PermissionService.shared.fetchPermissions(for: groupId)
                    } else {
                        print("AppState: user has no groupId")
                    }
                } else if self.isLoggedIn {
                    // User is authenticated but data not loaded yet
                    self.state = .authenticating
                } else {
                    // User is not authenticated
                    self.state = .unauthenticated
                }
                
                // Mark session as initialized
                self.sessionInitialized = true
            }
            .store(in: &cancellables)
        
        // Setup persistent Firebase auth state monitoring
        setupAuthStateMonitoring()
        
        print("AppState: initialization completed")
    }
    
    // Setup Firebase auth state changes monitoring
    private func setupAuthStateMonitoring() {
        // Remove existing handler if any
        if let handler = authStateDidChangeHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
        
        // Add new handler
        authStateDidChangeHandler = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if user != nil {
                    // User is authenticated
                    if self.state == .unauthenticated {
                        self.state = .authenticating
                        self.loadUser()
                    }
                } else {
                    // User is not authenticated
                    self.state = .unauthenticated
                }
            }
        }
    }
    
    // Update published properties based on internal state
    private func updatePublishedProperties() {
        DispatchQueue.main.async {
            switch self.state {
            case .initializing:
                self.isLoading = true
                self.isLoggedIn = false
                self.user = nil
                self.errorMessage = nil
                
            case .authenticating:
                self.isLoading = true
                self.isLoggedIn = true
                self.user = nil
                self.errorMessage = nil
                
            case .authenticated(let user):
                self.isLoading = false
                self.isLoggedIn = true
                self.user = user
                self.errorMessage = nil
                
            case .unauthenticated:
                self.isLoading = false
                self.isLoggedIn = false
                self.user = nil
                self.errorMessage = nil
                
            case .error(let message):
                self.isLoading = false
                self.errorMessage = message
            }
        }
    }

    // Public methods
    
    // Logout user
    func logout() {
        print("AppState: starting logout")
        state = .authenticating
        
        AuthService.shared.signOut { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("AppState: logout successful")
                    self.state = .unauthenticated
                    
                case .failure(let error):
                    print("AppState: error during logout: \(error.localizedDescription)")
                    self.state = .error("Error during logout: \(error.localizedDescription)")
                }
            }
        }
    }

    // Load user data
    func loadUser() {
        print("AppState: starting user loading")
        state = .authenticating
        
        UserService.shared.fetchCurrentUser { [weak self] success in
            guard let self = self else {
                print("AppState: self = nil during user loading")
                return
            }
            
            DispatchQueue.main.async {
                print("AppState: user loading completed, success: \(success)")
                
                if success {
                    if let user = UserService.shared.currentUser {
                        self.state = .authenticated(user)
                    } else {
                        // User data loaded but no user found
                        self.state = .error("User data loaded but no user found")
                    }
                } else {
                    // Failed to load user data
                    self.state = .error("Failed to load user data")
                    print("AppState: failed to load user data")
                }
            }
        }
    }

    // Refresh auth state
    func refreshAuthState() {
        print("AppState: refreshing authorization state")
        
        // Make sure Firebase is initialized
        FirebaseManager.shared.ensureInitialized()
        
        print("AppState: checking current user")
        if Auth.auth().currentUser != nil {
            print("AppState: user is authorized, loading data")
            state = .authenticating
            loadUser()
        } else {
            print("AppState: user is not authorized")
            state = .unauthenticated
        }
    }
    
    // Check access to module for current user
    func hasAccess(to moduleType: ModuleType) -> Bool {
        print("AppState: checking access to module \(moduleType.rawValue)")
        guard isLoggedIn, let userRole = user?.role else {
            print("AppState: access to module \(moduleType.rawValue) denied - not authorized or no role")
            return false
        }
        
        let hasAccess = PermissionService.shared.hasAccess(to: moduleType, role: userRole)
        print("AppState: access to module \(moduleType.rawValue) \(hasAccess ? "allowed" : "denied")")
        return hasAccess
    }
    
    // Check if user has edit permissions in the module
    func hasEditPermission(for moduleType: ModuleType) -> Bool {
        print("AppState: checking edit permissions for module \(moduleType.rawValue)")
        guard isLoggedIn, let userRole = user?.role else {
            print("AppState: edit access for module \(moduleType.rawValue) denied - not authorized or no role")
            return false
        }
        
        // Admins and managers have edit permissions
        let hasPermission = userRole == .admin || userRole == .manager
        print("AppState: edit access for module \(moduleType.rawValue) \(hasPermission ? "allowed" : "denied")")
        return hasPermission
    }
    
    // Check if user is admin
    var isAdmin: Bool {
        guard isLoggedIn, let userRole = user?.role else {
            return false
        }
        
        return userRole == .admin
    }
    
    // Check if user is manager or admin
    var isManagerOrAbove: Bool {
        guard isLoggedIn, let userRole = user?.role else {
            return false
        }
        
        return userRole == .admin || userRole == .manager
    }
}
