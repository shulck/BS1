//
//  GroupViewModel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  GroupViewModel.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import Foundation
import Combine
import FirebaseFirestore

final class GroupViewModel: ObservableObject {
    @Published var groupName = ""
    @Published var groupCode = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var pendingMembers: [String] = []
    @Published var members: [String] = []
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    // Создание новой группы
    func createGroup(completion: @escaping (Result<String, Error>) -> Void) {
        guard let userId = AuthService.shared.currentUserUID(), !groupName.isEmpty else {
            errorMessage = "Необходимо указать название группы"
            completion(.failure(NSError(domain: "EmptyGroupName", code: -1, userInfo: nil)))
            return
        }
        
        isLoading = true
        
        let groupCode = UUID().uuidString.prefix(6).uppercased()
        let newGroup = GroupModel(
            name: groupName,
            code: String(groupCode),
            members: [userId],
            pendingMembers: []
        )
        
        do {
            try db.collection("groups").addDocument(from: newGroup) { [weak self] error in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Ошибка создания группы: \(error.localizedDescription)"
                    completion(.failure(error))
                    return
                }
                
                self.successMessage = "Группа успешно создана!"
                
                // Получаем ID созданной группы
                self.db.collection("groups")
                    .whereField("code", isEqualTo: groupCode)
                    .getDocuments { snapshot, error in
                        if let error = error {
                            self.errorMessage = "Ошибка при получении ID группы: \(error.localizedDescription)"
                            completion(.failure(error))
                            return
                        }
                        
                        if let groupId = snapshot?.documents.first?.documentID {
                            // Обновляем пользователя с ID группы
                            UserService.shared.updateUserGroup(groupId: groupId) { result in
                                switch result {
                                case .success:
                                    // Также обновляем роль пользователя на Admin
                                    self.db.collection("users").document(userId).updateData([
                                        "role": "Admin"
                                    ]) { error in
                                        if let error = error {
                                            self.errorMessage = "Ошибка назначения администратора: \(error.localizedDescription)"
                                            completion(.failure(error))
                                        } else {
                                            completion(.success(groupId))
                                        }
                                    }
                                case .failure(let error):
                                    self.errorMessage = "Ошибка обновления пользователя: \(error.localizedDescription)"
                                    completion(.failure(error))
                                }
                            }
                        } else {
                            self.errorMessage = "Не удалось найти созданную группу"
                            completion(.failure(NSError(domain: "GroupNotFound", code: -1, userInfo: nil)))
                        }
                    }
            }
        } catch {
            isLoading = false
            errorMessage = "Ошибка при создании группы: \(error.localizedDescription)"
            completion(.failure(error))
        }
    }
    
    // Присоединение к существующей группе по коду
    func joinGroup(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = AuthService.shared.currentUserUID(), !groupCode.isEmpty else {
            errorMessage = "Необходимо указать код группы"
            completion(.failure(NSError(domain: "EmptyGroupCode", code: -1, userInfo: nil)))
            return
        }
        
        isLoading = true
        
        db.collection("groups")
            .whereField("code", isEqualTo: groupCode)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Ошибка поиска группы: \(error.localizedDescription)"
                    completion(.failure(error))
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    self.errorMessage = "Группа с таким кодом не найдена"
                    completion(.failure(NSError(domain: "GroupNotFound", code: -1, userInfo: nil)))
                    return
                }
                
                let groupId = document.documentID
                
                // Добавляем пользователя в pendingMembers
                self.db.collection("groups").document(groupId).updateData([
                    "pendingMembers": FieldValue.arrayUnion([userId])
                ]) { error in
                    if let error = error {
                        self.errorMessage = "Ошибка при присоединении к группе: \(error.localizedDescription)"
                        completion(.failure(error))
                    } else {
                        self.successMessage = "Запрос на вступление отправлен. Ожидайте подтверждения."
                        
                        // Обновляем groupId пользователя
                        UserService.shared.updateUserGroup(groupId: groupId) { result in
                            switch result {
                            case .success:
                                completion(.success(()))
                            case .failure(let error):
                                self.errorMessage = "Ошибка обновления пользователя: \(error.localizedDescription)"
                                completion(.failure(error))
                            }
                        }
                    }
                }
            }
    }
    
    // Загрузка участников группы
    func loadGroupMembers(groupId: String) {
        isLoading = true
        
        GroupService.shared.fetchGroup(by: groupId)
        
        // Подписываемся на обновления группы
        GroupService.shared.$group
            .receive(on: DispatchQueue.main)
            .sink { [weak self] group in
                guard let self = self, let group = group else { return }
                
                self.isLoading = false
                self.members = group.members
                self.pendingMembers = group.pendingMembers
            }
            .store(in: &cancellables)
    }
}