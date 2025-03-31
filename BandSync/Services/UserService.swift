//
//  UserService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

final class UserService: ObservableObject {
    static let shared = UserService()
    @Published var currentUser: UserModel?
    
    private let db = Firestore.firestore()
    
    init() {
        print("UserService: инициализирован")
    }
    
    func fetchCurrentUser(completion: @escaping (Bool) -> Void) {
        print("UserService: загрузка текущего пользователя")
        
        // Убедимся, что Firebase инициализирован
        FirebaseManager.shared.ensureInitialized()
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("UserService: нет текущего пользователя")
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }
        
        print("UserService: запрос данных пользователя из Firestore, uid: \(uid)")
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("UserService: ошибка загрузки данных пользователя: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                print("UserService: документ пользователя не существует")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            if let data = snapshot.data() {
                print("UserService: данные пользователя получены: \(data)")
                
                // Создаем UserModel напрямую из данных, без сериализации в JSON
                let user = UserModel(
                    id: data["id"] as? String ?? uid,
                    email: data["email"] as? String ?? "",
                    name: data["name"] as? String ?? "",
                    phone: data["phone"] as? String ?? "",
                    groupId: data["groupId"] as? String,
                    role: UserModel.UserRole(rawValue: data["role"] as? String ?? "Member") ?? .member
                )
                
                DispatchQueue.main.async {
                    self?.currentUser = user
                    print("UserService: currentUser установлен")
                    completion(true)
                }
            } else {
                print("UserService: данные пользователя отсутствуют")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    func updateUserGroup(groupId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("UserService: обновление группы пользователя на \(groupId)")
        
        // Убедимся, что Firebase инициализирован
        FirebaseManager.shared.ensureInitialized()
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("UserService: нет текущего пользователя для обновления группы")
            return
        }
        
        db.collection("users").document(uid).updateData([
            "groupId": groupId
        ]) { error in
            if let error = error {
                print("UserService: ошибка обновления группы: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("UserService: группа успешно обновлена")
                self.fetchCurrentUser { _ in }
                completion(.success(()))
            }
        }
    }
}
