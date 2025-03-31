//
//  AppState.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import Combine
import FirebaseAuth

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isLoggedIn: Bool = AuthService.shared.isUserLoggedIn()
    @Published var user: UserModel?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        UserService.shared.$currentUser
            .receive(on: DispatchQueue.main)
            .assign(to: \.user, on: self)
            .store(in: &cancellables)
    }

    func logout() {
        AuthService.shared.signOut { _ in
            DispatchQueue.main.async {
                self.isLoggedIn = false
                self.user = nil
            }
        }
    }

    func loadUser() {
        UserService.shared.fetchCurrentUser { success in
            DispatchQueue.main.async {
                self.isLoggedIn = success
            }
        }
    }

    func refreshAuthState() {
        if Auth.auth().currentUser != nil {
            loadUser()
        } else {
            self.isLoggedIn = false
            self.user = nil
        }
    }
}

