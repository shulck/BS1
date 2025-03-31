//
//  UsersListView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct UsersListView: View {
    @StateObject private var groupService = GroupService.shared
    @State private var showingRoleView = false
    @State private var selectedUserId = ""
    
    var body: some View {
        List {
            if groupService.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else {
                // Участники группы
                if !groupService.groupMembers.isEmpty {
                    Section(header: Text("Участники")) {
                        ForEach(groupService.groupMembers) { user in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.name)
                                        .font(.headline)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("Роль: \(user.role.rawValue)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Кнопки действий
                                if user.id != AppState.shared.user?.id {
                                    Menu {
                                        Button("Изменить роль") {
                                            selectedUserId = user.id
                                            showingRoleView = true
                                        }
                                        
                                        Button("Удалить из группы", role: .destructive) {
                                            groupService.removeUser(userId: user.id)
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Ожидающие подтверждения
                if !groupService.pendingMembers.isEmpty {
                    Section(header: Text("Ожидают одобрения")) {
                        ForEach(groupService.pendingMembers) { user in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.name)
                                        .font(.headline)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Кнопки принятия/отклонения
                                Button {
                                    groupService.approveUser(userId: user.id)
                                } label: {
                                    Text("Принять")
                                        .foregroundColor(.green)
                                }
                                
                                Button {
                                    groupService.rejectUser(userId: user.id)
                                } label: {
                                    Text("Отклонить")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
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
                            groupService.regenerateCode()
                        }
                    }
                }
            }
            
            if let error = groupService.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Участники группы")
        .onAppear {
            if let gid = AppState.shared.user?.groupId {
                groupService.fetchGroup(by: gid)
            }
        }
        .sheet(isPresented: $showingRoleView) {
            RoleSelectionView(userId: selectedUserId)
        }
        .refreshable {
            if let gid = AppState.shared.user?.groupId {
                groupService.fetchGroup(by: gid)
            }
        }
    }
}

// Представление для выбора роли
struct RoleSelectionView: View {
    let userId: String
    @StateObject private var groupService = GroupService.shared
    @State private var selectedRole: UserModel.UserRole = .member
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Выберите роль")) {
                    ForEach(UserModel.UserRole.allCases, id: \.self) { role in
                        Button {
                            selectedRole = role
                            groupService.changeUserRole(userId: userId, newRole: role)
                            dismiss()
                        } label: {
                            HStack {
                                Text(role.rawValue)
                                Spacer()
                                if selectedRole == role {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                if groupService.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                
                if let error = groupService.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Изменение роли")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Попытаемся найти текущую роль пользователя
            if let user = groupService.groupMembers.first(where: { $0.id == userId }) {
                selectedRole = user.role
            }
        }
    }
}
