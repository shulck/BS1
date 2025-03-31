//
//  PermissionsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  PermissionsView.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import SwiftUI

struct PermissionsView: View {
    @StateObject private var permissionService = PermissionService.shared
    @State private var selectedModule: ModuleType?
    @State private var showModuleEditor = false
    @State private var showResetConfirmation = false
    
    var body: some View {
        List {
            // Информационный раздел
            Section(header: Text("Управление доступом")) {
                Text("Здесь вы можете настроить, какие роли имеют доступ к различным модулям приложения.")
                    .font(.footnote)
            }
            
            // Раздел с модулями
            Section(header: Text("Модули")) {
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
                                
                                // Отображаем роли с доступом
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
            
            // Сброс настроек
            Section {
                Button("Сбросить к значениям по умолчанию") {
                    showResetConfirmation = true
                }
                .foregroundColor(.red)
            }
            
            // Индикатор загрузки
            if permissionService.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
            
            // Сообщение об ошибке
            if let error = permissionService.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Разрешения")
        .sheet(isPresented: $showModuleEditor) {
            if let module = selectedModule {
                ModulePermissionEditorView(module: module)
            }
        }
        .alert("Сбросить разрешения?", isPresented: $showResetConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Сбросить", role: .destructive) {
                permissionService.resetToDefaults()
            }
        } message: {
            Text("Это действие сбросит все настройки разрешений к значениям по умолчанию. Вы уверены?")
        }
        .onAppear {
            if let groupId = AppState.shared.user?.groupId {
                permissionService.fetchPermissions(for: groupId)
            }
        }
    }
    
    // Форматирование текста ролей с доступом
    private func accessRolesText(for module: ModuleType) -> String {
        let roles = permissionService.getRolesWithAccess(to: module)
        
        if roles.isEmpty {
            return "Нет доступа"
        }
        
        return roles.map { $0.rawValue }.joined(separator: ", ")
    }
}

// Редактор разрешений для модуля
struct ModulePermissionEditorView: View {
    let module: ModuleType
    @StateObject private var permissionService = PermissionService.shared
    @Environment(\.dismiss) var dismiss
    
    // Локальное состояние выбранных ролей
    @State private var selectedRoles: Set<UserModel.UserRole> = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Доступ к модулю")) {
                    Text("Выберите роли, которые будут иметь доступ к модулю '\(module.displayName)'")
                        .font(.footnote)
                }
                
                Section(header: Text("Роли")) {
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
                    }
                }
                
                if permissionService.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(module.displayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        savePermissions()
                    }
                }
            }
            .onAppear {
                // Загружаем текущие роли при появлении
                let currentRoles = permissionService.getRolesWithAccess(to: module)
                selectedRoles = Set(currentRoles)
            }
        }
    }
    
    // Переключение выбора роли
    private func toggleRole(_ role: UserModel.UserRole) {
        if selectedRoles.contains(role) {
            selectedRoles.remove(role)
        } else {
            selectedRoles.insert(role)
        }
    }
    
    // Сохранение настроек
    private func savePermissions() {
        permissionService.updateModulePermission(
            moduleId: module,
            roles: Array(selectedRoles)
        )
        dismiss()
    }
}