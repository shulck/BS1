//
//  AdminPanelView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct AdminPanelView: View {
    @StateObject private var groupService = GroupService.shared
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Управление группой")) {
                    // Настройки группы
                    NavigationLink(destination: GroupSettingsView()) {
                        Label("Настройки группы", systemImage: "gearshape")
                    }
                    
                    // Управление участниками
                    NavigationLink(destination: UsersListView()) {
                        Label("Участники группы", systemImage: "person.3")
                    }
                    
                    // Управление разрешениями
                    NavigationLink(destination: PermissionsView()) {
                        Label("Разрешения", systemImage: "lock.shield")
                    }
                    
                    // Управление модулями
                    NavigationLink(destination: ModuleManagementView()) {
                        Label("Модули приложения", systemImage: "square.grid.2x2")
                    }
                }
                
                Section(header: Text("Статистика")) {
                    // Статистика использования приложения
                    Label("Количество участников: \(groupService.groupMembers.count)", systemImage: "person.2")
                    
                    if let group = groupService.group {
                        Label("Название группы: \(group.name)", systemImage: "music.mic")
                        
                        // Код приглашения с возможностью копирования
                        HStack {
                            Label("Код приглашения: \(group.code)", systemImage: "qrcode")
                            Spacer()
                            Button {
                                UIPasteboard.general.string = group.code
                                alertMessage = "Код скопирован в буфер обмена"
                                showAlert = true
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Section(header: Text("Дополнительно")) {
                    Button(action: {
                        // Функция для тестирования уведомлений
                        alertMessage = "Уведомления будут реализованы в следующем обновлении"
                        showAlert = true
                    }) {
                        Label("Тестировать уведомления", systemImage: "bell")
                    }
                    
                    Button(action: {
                        // Функция экспорта данных
                        alertMessage = "Экспорт данных будет реализован в следующем обновлении"
                        showAlert = true
                    }) {
                        Label("Экспорт данных группы", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Админ-панель")
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    groupService.fetchGroup(by: groupId)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Информация"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("ОК"))
                )
            }
            .refreshable {
                if let groupId = AppState.shared.user?.groupId {
                    groupService.fetchGroup(by: groupId)
                }
            }
        }
    }
}
