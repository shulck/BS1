//
//  FirebaseManager.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseCore

class FirebaseManager {
    static let shared = FirebaseManager()
    
    private(set) var isInitialized = false
    private let initializationLock = NSLock()
    
    private init() {
        print("FirebaseManager: создан экземпляр")
    }
    
    func initialize() {
        print("FirebaseManager: попытка инициализации Firebase")
        // Используем лок для потокобезопасности
        initializationLock.lock()
        print("FirebaseManager: лок получен")
        defer {
            initializationLock.unlock()
            print("FirebaseManager: лок освобожден")
        }
        
        if !isInitialized {
            print("FirebaseManager: Firebase не был инициализирован, инициализируем")
            do {
                FirebaseApp.configure()
                print("FirebaseManager: Firebase успешно инициализирован")
                isInitialized = true
            } catch let error {
                print("FirebaseManager: ОШИБКА инициализации Firebase: \(error)")
            }
        } else {
            print("FirebaseManager: Firebase уже был инициализирован")
        }
    }
    
    func ensureInitialized() {
        print("FirebaseManager: проверка инициализации")
        if !isInitialized {
            print("FirebaseManager: требуется инициализация")
            initialize()
        } else {
            print("FirebaseManager: уже инициализирован")
        }
    }
}
