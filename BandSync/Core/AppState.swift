//
//  AppState.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import Foundation
import Combine
import FirebaseAuth

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isLoggedIn: Bool = AuthService.shared.isUserLoggedIn()
    @Published var user: UserModel?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        UserService.shared.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.user = user
                
                // Когда пользователь меняется, загружаем разрешения
                if let groupId = user?.groupId {
                    PermissionService.shared.fetchPermissions(for: groupId)
                }
            }
            .store(in: &cancellables)
    }

    func logout() {
        isLoading = true
        
        AuthService.shared.signOut { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success:
                    self.isLoggedIn = false
                    self.user = nil
                case .failure(let error):
                    self.errorMessage = "Ошибка при выходе: \(error.localizedDescription)"
                }
            }
        }
    }

    func loadUser() {
        isLoading = true
        
        UserService.shared.fetchCurrentUser { [weak self] success in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoggedIn = success
                self.isLoading = false
                
                if !success {
                    self.errorMessage = "Не удалось загрузить данные пользователя"
                }
            }
        }
    }

    func refreshAuthState() {
        isLoading = true
        
        if Auth.auth().currentUser != nil {
            loadUser()
        } else {
            self.isLoggedIn = false
            self.user = nil
            self.isLoading = false
        }
    }
    
    // Проверка доступа к модулю для текущего пользователя
    func hasAccess(to moduleType: ModuleType) -> Bool {
        guard isLoggedIn, let userRole = user?.role else {
            return false
        }
        
        return PermissionService.shared.hasAccess(to: moduleType, role: userRole)
    }
    
    // Проверка, имеет ли пользователь права на редактирование в модуле
    func hasEditPermission(for moduleType: ModuleType) -> Bool {
        guard isLoggedIn, let userRole = user?.role else {
            return false
        }
        
        // Админы и менеджеры имеют права редактирования
        return userRole == .admin || userRole == .manager
    }
}
