//
//  AuthService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class AuthService {
    static let shared = AuthService()
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    private init() {
        print("AuthService: инициализирован")
    }
    
    func registerUser(email: String, password: String, name: String, phone: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("AuthService: начало регистрации пользователя с email \(email)")
        
        // Убедимся, что Firebase инициализирован
        FirebaseManager.shared.ensureInitialized()
        
        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                print("AuthService: ошибка при создании пользователя: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let uid = result?.user.uid else {
                print("AuthService: UID отсутствует после создания пользователя")
                completion(.failure(NSError(domain: "UIDMissing", code: -1, userInfo: nil)))
                return
            }
            
            print("AuthService: пользователь создан с UID: \(uid)")

            let userData: [String: Any] = [
                "id": uid,
                "email": email,
                "name": name,
                "phone": phone,
                "groupId": NSNull(),
                "role": "Member"
            ]
            
            print("AuthService: сохранение данных пользователя: \(userData)")

            self?.db.collection("users").document(uid).setData(userData) { error in
                if let error = error {
                    print("AuthService: ошибка при сохранении данных пользователя: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("AuthService: данные пользователя успешно сохранены")
                    completion(.success(()))
                }
            }
        }
    }

    func loginUser(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("AuthService: попытка входа пользователя с email \(email)")
        
        // Убедимся, что Firebase инициализирован
        FirebaseManager.shared.ensureInitialized()
        
        auth.signIn(withEmail: email, password: password) { _, error in
            if let error = error {
                print("AuthService: ошибка при входе: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("AuthService: вход пользователя успешен")
                completion(.success(()))
            }
        }
    }

    func resetPassword(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("AuthService: отправка запроса на сброс пароля для email \(email)")
        
        // Убедимся, что Firebase инициализирован
        FirebaseManager.shared.ensureInitialized()
        
        auth.sendPasswordReset(withEmail: email) { error in
            if let error = error {
                print("AuthService: ошибка при сбросе пароля: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("AuthService: запрос на сброс пароля отправлен успешно")
                completion(.success(()))
            }
        }
    }

    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        print("AuthService: попытка выхода пользователя")
        
        // Убедимся, что Firebase инициализирован
        FirebaseManager.shared.ensureInitialized()
        
        do {
            try auth.signOut()
            print("AuthService: выход пользователя успешен")
            completion(.success(()))
        } catch {
            print("AuthService: ошибка при выходе: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    func isUserLoggedIn() -> Bool {
        print("AuthService: проверка авторизации пользователя")
        
        // Убедимся, что Firebase инициализирован
        FirebaseManager.shared.ensureInitialized()
        
        let isLoggedIn = auth.currentUser != nil
        print("AuthService: пользователь \(isLoggedIn ? "авторизован" : "не авторизован")")
        return isLoggedIn
    }

    func currentUserUID() -> String? {
        print("AuthService: запрос UID текущего пользователя")
        
        // Убедимся, что Firebase инициализирован
        FirebaseManager.shared.ensureInitialized()
        
        let uid = auth.currentUser?.uid
        print("AuthService: UID текущего пользователя: \(uid ?? "отсутствует")")
        return uid
    }
}
