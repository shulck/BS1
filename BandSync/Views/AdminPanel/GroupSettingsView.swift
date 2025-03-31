//
//  GroupSettingsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct GroupSettingsView: View {
    @StateObject private var groupService = GroupService.shared
    @State private var newName = ""
    @State private var showConfirmation = false
    @State private var showSuccessAlert = false
    
    var body: some View {
        Form {
            // Название группы
            Section(header: Text("Название группы")) {
                TextField("Название группы", text: $newName)
                    .autocapitalization(.words)
                
                Button("Обновить название") {
                    groupService.updateGroupName(newName)
                    showSuccessAlert = true
                }
                .disabled(newName.isEmpty || groupService.isLoading)
            }
            
            // Код приглашения
            if let group = groupService.group {
                Section(header: Text("Код приглашения")) {
                    HStack {
                        Text(group.code)
                            .font(.system(.title3, design: .monospaced))
                            .bold()
                        
                        Spacer()
                        
                        Button {
                            UIPasteboard.general.string = group.code
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                    
                    Button("Сгенерировать новый код") {
                        showConfirmation = true
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Участники группы (краткая информация)
            Section(header: Text("Участники")) {
                NavigationLink(destination: UsersListView()) {
                    HStack {
                        Text("Управление участниками")
                        Spacer()
                        Text("\(groupService.groupMembers.count)")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Управление модулями (здесь можно будет добавить функциональность для включения/отключения модулей)
            Section(header: Text("Доступные модули")) {
                Text("Управление модулями будет доступно в следующем обновлении.")
                    .foregroundColor(.gray)
            }
            
            // Отображение ошибок
            if let error = groupService.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            
            // Индикатор загрузки
            if groupService.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Настройки группы")
        .onAppear {
            if let gid = AppState.shared.user?.groupId {
                groupService.fetchGroup(by: gid)
                newName = groupService.group?.name ?? ""
            }
        }
        .onChange(of: groupService.group) { newGroup in
            if let name = newGroup?.name {
                newName = name
            }
        }
        .alert("Сгенерировать новый код?", isPresented: $showConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Сгенерировать") {
                groupService.regenerateCode()
                showSuccessAlert = true
            }
        } message: {
            Text("Старый код больше не будет действителен. Все участники, которые еще не присоединились, должны будут использовать новый код.")
        }
        .alert("Успешно", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Изменения успешно сохранены.")
        }
    }
}
