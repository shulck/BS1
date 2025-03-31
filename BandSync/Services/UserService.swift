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
                
                do {
                    // Преобразуем данные с преобразованием Timestamp в Date, если необходимо
                    let processedData = data
                    
                    let jsonData = try JSONSerialization.data(withJSONObject: processedData)
                    print("UserService: данные сериализованы в JSON")
                    
                    let decoder = JSONDecoder()
                    let user = try decoder.decode(UserModel.self, from: jsonData)
                    print("UserService: данные успешно декодированы в UserModel")
                    
                    DispatchQueue.main.async {
                        self?.currentUser = user
                        print("UserService: currentUser установлен")
                        completion(true)
                    }
                } catch {
                    print("UserService: ОШИБКА при парсинге пользователя: \(error)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
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
