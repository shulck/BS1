//
//  PermissionService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  PermissionService.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import Foundation
import FirebaseFirestore
import Combine

final class PermissionService: ObservableObject {
    static let shared = PermissionService()
    
    @Published var permissions: PermissionModel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Автоматическая проверка разрешений при изменении пользователя
        AppState.shared.$user
            .removeDuplicates()
            .sink { [weak self] user in
                if let groupId = user?.groupId {
                    self?.fetchPermissions(for: groupId)
                } else {
                    self?.permissions = nil
                }
            }
            .store(in: &cancellables)
    }
    
    // Получение разрешений для группы
    func fetchPermissions(for groupId: String) {
        isLoading = true
        
        db.collection("permissions")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Ошибка загрузки разрешений: \(error.localizedDescription)"
                    return
                }
                
                if let document = snapshot?.documents.first {
                    do {
                        let permissionModel = try document.data(as: PermissionModel.self)
                        DispatchQueue.main.async {
                            self.permissions = permissionModel
                        }
                    } catch {
                        self.errorMessage = "Ошибка преобразования данных разрешений: \(error.localizedDescription)"
                    }
                } else {
                    // Если разрешений для группы нет, создаем стандартные
                    self.createDefaultPermissions(for: groupId)
                }
            }
    }
    
    // Создание стандартных разрешений для новой группы
    func createDefaultPermissions(for groupId: String) {
        isLoading = true
        
        // Стандартные разрешения для всех модулей
        let defaultModules: [PermissionModel.ModulePermission] = ModuleType.allCases.map { moduleType in
            // По умолчанию админы и менеджеры имеют доступ ко всему
            // Обычные участники - только к календарю, сетлистам, задачам и чатам
            let roles: [UserModel.UserRole]
            
            switch moduleType {
            case .admin:
                // Только админы могут получить доступ к админ-панели
                roles = [.admin]
            case .finances, .merchandise, .contacts:
                // Финансы, мерч и контакты требуют управленческих прав
                roles = [.admin, .manager]
            case .calendar, .setlists, .tasks, .chats:
                // Базовые модули доступны всем
                roles = [.admin, .manager, .musician, .member]
            }
            
            return PermissionModel.ModulePermission(moduleId: moduleType, roleAccess: roles)
        }
        
        let newPermissions = PermissionModel(groupId: groupId, modules: defaultModules)
        
        do {
            _ = try db.collection("permissions").addDocument(from: newPermissions) { [weak self] error in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Ошибка создания разрешений: \(error.localizedDescription)"
                } else {
                    // Загружаем созданные разрешения
                    self.fetchPermissions(for: groupId)
                }
            }
        } catch {
            isLoading = false
            errorMessage = "Ошибка сериализации данных разрешений: \(error.localizedDescription)"
        }
    }
    
    // Обновление разрешений для модуля
    func updateModulePermission(moduleId: ModuleType, roles: [UserModel.UserRole]) {
        guard let permissionId = permissions?.id else { return }
        isLoading = true
        
        // Находим существующий модуль для обновления
        if var modules = permissions?.modules {
            if let index = modules.firstIndex(where: { $0.moduleId == moduleId }) {
                modules[index] = PermissionModel.ModulePermission(moduleId: moduleId, roleAccess: roles)
                
                db.collection("permissions").document(permissionId).updateData([
                    "modules": modules.map { [
                        "moduleId": $0.moduleId.rawValue,
                        "roleAccess": $0.roleAccess.map { $0.rawValue }
                    ]}
                ]) { [weak self] error in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Ошибка обновления разрешений: \(error.localizedDescription)"
                    } else {
                        // Обновляем локальные данные
                        DispatchQueue.main.async {
                            self.permissions?.modules = modules
                        }
                    }
                }
            }
        }
    }
    
    // Проверка, имеет ли пользователь доступ к модулю
    func hasAccess(to moduleId: ModuleType, role: UserModel.UserRole) -> Bool {
        // Админы всегда имеют доступ ко всему
        if role == .admin {
            return true
        }
        
        // Проверяем разрешения
        if let modulePermission = permissions?.modules.first(where: { $0.moduleId == moduleId }) {
            return modulePermission.hasAccess(role: role)
        }
        
        // Если разрешения не найдены, по умолчанию доступ запрещен
        return false
    }
    
    // Проверка доступа для текущего пользователя
    func currentUserHasAccess(to moduleId: ModuleType) -> Bool {
        guard let userRole = AppState.shared.user?.role else {
            return false
        }
        
        return hasAccess(to: moduleId, role: userRole)
    }
    
    // Получение всех модулей, к которым у пользователя есть доступ
    func getAccessibleModules(for role: UserModel.UserRole) -> [ModuleType] {
        // Админы имеют доступ ко всему
        if role == .admin {
            return ModuleType.allCases
        }
        
        // Для других ролей фильтруем модули по разрешениям
        return permissions?.modules
            .filter { $0.hasAccess(role: role) }
            .map { $0.moduleId } ?? []
    }
    
    // Получение доступных модулей для текущего пользователя
    func getCurrentUserAccessibleModules() -> [ModuleType] {
        guard let userRole = AppState.shared.user?.role else {
            return []
        }
        
        return getAccessibleModules(for: userRole)
    }
    
    // Проверка, имеет ли пользователь право на редактирование данных в модуле
    // Это более строгое требование, обычно для админов и менеджеров
    func hasEditPermission(for moduleId: ModuleType) -> Bool {
        guard let role = AppState.shared.user?.role else {
            return false
        }
        
        // Только админы и менеджеры могут редактировать
        return role == .admin || role == .manager
    }
    
    // Сброс разрешений до значений по умолчанию
    func resetToDefaults() {
        guard let groupId = AppState.shared.user?.groupId,
              let permissionId = permissions?.id else {
            return
        }
        
        // Удаляем текущие разрешения и создаем новые
        db.collection("permissions").document(permissionId).delete { [weak self] error in
            if error == nil {
                self?.createDefaultPermissions(for: groupId)
            }
        }
    }
    
    // Получение списка ролей, имеющих доступ к модулю
    func getRolesWithAccess(to moduleId: ModuleType) -> [UserModel.UserRole] {
        if let modulePermission = permissions?.modules.first(where: { $0.moduleId == moduleId }) {
            return modulePermission.roleAccess
        }
        return []
    }
}