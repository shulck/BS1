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
    
    func fetchCurrentUser(completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: data)
                    let user = try JSONDecoder().decode(UserModel.self, from: jsonData)
                    DispatchQueue.main.async {
                        self.currentUser = user
                        completion(true)
                    }
                } catch {
                    print("Ошибка при парсинге пользователя: \(error)")
                    completion(false)
                }
            } else {
                print("Ошибка загрузки данных пользователя: \(error?.localizedDescription ?? "Неизвестная ошибка")")
                completion(false)
            }
        }
    }
    
    func updateUserGroup(groupId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(uid).updateData([
            "groupId": groupId
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                self.fetchCurrentUser { _ in }
                completion(.success(()))
            }
        }
    }
}
