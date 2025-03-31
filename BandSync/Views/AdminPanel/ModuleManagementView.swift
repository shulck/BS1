//
//  ModuleManagementView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  ModuleManagementView.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import SwiftUI

struct ModuleManagementView: View {
    @StateObject private var permissionService = PermissionService.shared
    @State private var modules = ModuleType.allCases
    @State private var enabledModules: Set<ModuleType> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        List {
            Section(header: Text("Доступные модули")) {
                Text("Включите или отключите модули, которые будут доступны участникам группы.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            ForEach(modules) { module in
                HStack {
                    Image(systemName: module.icon)
                        .foregroundColor(.blue)
                    
                    Text(module.displayName)
                    
                    Spacer()
                    
                    if module == .admin {
                        Text("Всегда включен")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Toggle("", isOn: Binding(
                            get: { enabledModules.contains(module) },
                            set: { newValue in
                                if newValue {
                                    enabledModules.insert(module)
                                } else {
                                    enabledModules.remove(module)
                                }
                            }
                        ))
                    }
                }
            }
            
            Section {
                Button("Сохранить изменения") {
                    saveChanges()
                }
                .disabled(isLoading)
            }
            
            // Сообщения об успехе или ошибке
            if let success = successMessage {
                Section {
                    Text(success)
                        .foregroundColor(.green)
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            
            // Индикатор загрузки
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Управление модулями")
        .onAppear {
            loadModuleSettings()
        }
    }
    
    // Загрузка текущих настроек модулей
    private func loadModuleSettings() {
        isLoading = true
        successMessage = nil
        errorMessage = nil
        
        if let groupId = AppState.shared.user?.groupId {
            permissionService.fetchPermissions(for: groupId)
            
            // Используем задержку, чтобы дать время загрузиться разрешениям
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Инициализируем список включенных модулей
                enabledModules = Set(permissionService.permissions?.modules
                    .filter { !$0.roleAccess.isEmpty }
                    .map { $0.moduleId } ?? [])
                
                // Admin всегда включен
                enabledModules.insert(.admin)
                
                isLoading = false
            }
        } else {
            isLoading = false
            errorMessage = "Не удалось определить группу"
        }
    }
    
    // Сохранение изменений
    private func saveChanges() {
        guard let permissionId = permissionService.permissions?.id else {
            errorMessage = "Не удалось найти настройки разрешений"
            return
        }
        
        isLoading = true
        successMessage = nil
        errorMessage = nil
        
        // Для каждого модуля, кроме Admin
        for module in modules where module != .admin {
            // Определяем, какие роли должны иметь доступ
            let roles: [UserModel.UserRole]
            
            if enabledModules.contains(module) {
                // Если модуль включен, используем текущие настройки ролей или стандартные
                roles = permissionService.getRolesWithAccess(to: module)
                
                // Если нет ролей, устанавливаем стандартные настройки доступа
                if roles.isEmpty {
                    switch module {
                    case .finances, .merchandise, .contacts:
                        // Финансы, мерч и контакты требуют управленческих прав
                        permissionService.updateModulePermission(
                            moduleId: module,
                            roles: [.admin, .manager]
                        )
                    case .calendar, .setlists, .tasks, .chats:
                        // Базовые модули доступны всем
                        permissionService.updateModulePermission(
                            moduleId: module,
                            roles: [.admin, .manager, .musician, .member]
                        )
                    default:
                        break
                    }
                }
            } else {
                // Если модуль отключен, устанавливаем пустой список ролей
                permissionService.updateModulePermission(
                    moduleId: module,
                    roles: []
                )
            }
        }
        
        // Задержка для завершения всех операций обновления
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoading = false
            successMessage = "Настройки модулей успешно обновлены"
        }
    }
}