//
//  AppState.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import Combine
import FirebaseAuth

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isLoggedIn: Bool = false // Изменили на false для безопасности
    @Published var user: UserModel?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        print("AppState: инициализация")
        
        // Убедитесь, что Firebase инициализирован
        FirebaseManager.shared.ensureInitialized()
        
        print("AppState: проверяем состояние авторизации")
        isLoggedIn = AuthService.shared.isUserLoggedIn()
        print("AppState: isLoggedIn установлен в \(isLoggedIn)")
        
        print("AppState: настройка подписки на currentUser")
        UserService.shared.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                print("AppState: получено обновление пользователя: \(user != nil ? "пользователь есть" : "пользователя нет")")
                self?.user = user
                
                // Когда пользователь меняется, загружаем разрешения
                if let groupId = user?.groupId {
                    print("AppState: пользователь имеет groupId: \(groupId), загружаем разрешения")
                    PermissionService.shared.fetchPermissions(for: groupId)
                } else {
                    print("AppState: пользователь не имеет groupId")
                }
            }
            .store(in: &cancellables)
        print("AppState: инициализация завершена")
    }

    func logout() {
        print("AppState: начало выхода")
        isLoading = true
        
        AuthService.shared.signOut { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success:
                    print("AppState: выход успешен")
                    self.isLoggedIn = false
                    self.user = nil
                case .failure(let error):
                    print("AppState: ошибка при выходе: \(error.localizedDescription)")
                    self.errorMessage = "Ошибка при выходе: \(error.localizedDescription)"
                }
            }
        }
    }

    func loadUser() {
        print("AppState: начало загрузки пользователя")
        isLoading = true
        
        UserService.shared.fetchCurrentUser { [weak self] success in
            guard let self = self else {
                print("AppState: self = nil при загрузке пользователя")
                return
            }
            
            DispatchQueue.main.async {
                print("AppState: завершение загрузки пользователя, успех: \(success)")
                self.isLoggedIn = success
                self.isLoading = false
                
                if !success {
                    self.errorMessage = "Не удалось загрузить данные пользователя"
                    print("AppState: не удалось загрузить данные пользователя")
                }
            }
        }
    }

    func refreshAuthState() {
        print("AppState: обновление состояния авторизации")
        isLoading = true
        
        // Убедитесь, что Firebase инициализирован
        FirebaseManager.shared.ensureInitialized()
        
        print("AppState: проверка текущего пользователя")
        if Auth.auth().currentUser != nil {
            print("AppState: пользователь авторизован, загружаем данные")
            loadUser()
        } else {
            print("AppState: пользователь не авторизован")
            DispatchQueue.main.async {
                self.isLoggedIn = false
                self.user = nil
                self.isLoading = false
            }
        }
    }
    
    // Проверка доступа к модулю для текущего пользователя
    func hasAccess(to moduleType: ModuleType) -> Bool {
        print("AppState: проверка доступа к модулю \(moduleType.rawValue)")
        guard isLoggedIn, let userRole = user?.role else {
            print("AppState: доступ к модулю \(moduleType.rawValue) отклонен - не авторизован или нет роли")
            return false
        }
        
        let hasAccess = PermissionService.shared.hasAccess(to: moduleType, role: userRole)
        print("AppState: доступ к модулю \(moduleType.rawValue) \(hasAccess ? "разрешен" : "отклонен")")
        return hasAccess
    }
    
    // Проверка, имеет ли пользователь права на редактирование в модуле
    func hasEditPermission(for moduleType: ModuleType) -> Bool {
        print("AppState: проверка прав на редактирование для модуля \(moduleType.rawValue)")
        guard isLoggedIn, let userRole = user?.role else {
            print("AppState: доступ на редактирование для модуля \(moduleType.rawValue) отклонен - не авторизован или нет роли")
            return false
        }
        
        // Админы и менеджеры имеют права редактирования
        let hasPermission = userRole == .admin || userRole == .manager
        print("AppState: доступ на редактирование для модуля \(moduleType.rawValue) \(hasPermission ? "разрешен" : "отклонен")")
        return hasPermission
    }
}
