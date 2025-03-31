//
//  GroupService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import Foundation
import FirebaseFirestore


final class GroupService: ObservableObject {
    static let shared = GroupService()

    @Published var group: GroupModel?
    @Published var groupMembers: [UserModel] = []
    @Published var pendingMembers: [UserModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    
    // Получение информации о группе по ID
    func fetchGroup(by id: String) {
        isLoading = true
        
        db.collection("groups").document(id).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.errorMessage = "Ошибка загрузки группы: \(error.localizedDescription)"
                self.isLoading = false
                return
            }
            
            if let data = try? snapshot?.data(as: GroupModel.self) {
                DispatchQueue.main.async {
                    self.group = data
                    self.fetchGroupMembers(groupId: id)
                    self.isLoading = false
                }
            } else {
                self.errorMessage = "Ошибка преобразования данных группы"
                self.isLoading = false
            }
        }
    }

    // Получение информации о пользователях группы
    private func fetchGroupMembers(groupId: String) {
        guard let group = self.group else { return }
        
        // Очистка существующих данных
        self.groupMembers = []
        self.pendingMembers = []
        
        // Получение активных участников
        for memberId in group.members {
            db.collection("users").document(memberId).getDocument { [weak self] snapshot, error in
                if let userData = try? snapshot?.data(as: UserModel.self) {
                    DispatchQueue.main.async {
                        self?.groupMembers.append(userData)
                    }
                }
            }
        }
        
        // Получение ожидающих подтверждения
        for pendingId in group.pendingMembers {
            db.collection("users").document(pendingId).getDocument { [weak self] snapshot, error in
                if let userData = try? snapshot?.data(as: UserModel.self) {
                    DispatchQueue.main.async {
                        self?.pendingMembers.append(userData)
                    }
                }
            }
        }
    }
    
    // Подтверждение пользователя (перевод из pending в members)
    func approveUser(userId: String) {
        guard let groupId = group?.id else { return }
        isLoading = true
        
        db.collection("groups").document(groupId).updateData([
            "pendingMembers": FieldValue.arrayRemove([userId]),
            "members": FieldValue.arrayUnion([userId])
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка подтверждения пользователя: \(error.localizedDescription)"
                } else {
                    // Обновляем локальные данные
                    if let pendingIndex = self?.pendingMembers.firstIndex(where: { $0.id == userId }) {
                        if let user = self?.pendingMembers[pendingIndex] {
                            self?.groupMembers.append(user)
                            self?.pendingMembers.remove(at: pendingIndex)
                        }
                    }
                }
            }
        }
    }

    // Отклонение заявки пользователя
    func rejectUser(userId: String) {
        guard let groupId = group?.id else { return }
        isLoading = true
        
        db.collection("groups").document(groupId).updateData([
            "pendingMembers": FieldValue.arrayRemove([userId])
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка отклонения пользователя: \(error.localizedDescription)"
                } else {
                    // Обновляем локальные данные
                    if let pendingIndex = self?.pendingMembers.firstIndex(where: { $0.id == userId }) {
                        self?.pendingMembers.remove(at: pendingIndex)
                    }
                    
                    // Также нужно очистить groupId в профиле пользователя
                    self?.db.collection("users").document(userId).updateData([
                        "groupId": NSNull()
                    ])
                }
            }
        }
    }

    // Удаление пользователя из группы
    func removeUser(userId: String) {
        guard let groupId = group?.id else { return }
        isLoading = true
        
        db.collection("groups").document(groupId).updateData([
            "members": FieldValue.arrayRemove([userId])
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка удаления пользователя: \(error.localizedDescription)"
                } else {
                    // Обновляем локальные данные
                    if let memberIndex = self?.groupMembers.firstIndex(where: { $0.id == userId }) {
                        self?.groupMembers.remove(at: memberIndex)
                    }
                    
                    // Также нужно очистить groupId в профиле пользователя
                    self?.db.collection("users").document(userId).updateData([
                        "groupId": NSNull()
                    ])
                }
            }
        }
    }

    // Обновление названия группы
    func updateGroupName(_ newName: String) {
        guard let groupId = group?.id else { return }
        isLoading = true
        
        db.collection("groups").document(groupId).updateData([
            "name": newName
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка обновления названия: \(error.localizedDescription)"
                } else {
                    // Обновляем локальные данные
                    self?.group?.name = newName
                }
            }
        }
    }

    // Генерация нового кода приглашения
    func regenerateCode() {
        guard let groupId = group?.id else { return }
        isLoading = true
        
        let newCode = UUID().uuidString.prefix(6).uppercased()

        db.collection("groups").document(groupId).updateData([
            "code": String(newCode)
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка обновления кода: \(error.localizedDescription)"
                } else {
                    // Обновляем локальные данные
                    self?.group?.code = String(newCode)
                }
            }
        }
    }
    
    // Изменение роли пользователя
    func changeUserRole(userId: String, newRole: UserModel.UserRole) {
        isLoading = true
        
        db.collection("users").document(userId).updateData([
            "role": newRole.rawValue
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка изменения роли: \(error.localizedDescription)"
                } else {
                    // Обновляем локальные данные
                    if let memberIndex = self?.groupMembers.firstIndex(where: { $0.id == userId }) {
                        // Для простоты создаем обновленную копию пользователя
                        var updatedUser = self?.groupMembers[memberIndex]
                        updatedUser?.role = newRole
                        
                        if let user = updatedUser {
                            self?.groupMembers[memberIndex] = user
                        }
                    }
                }
            }
        }
    }
}
