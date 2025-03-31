//
//  LoginView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showRegister = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("BandSync")
                    .font(.largeTitle.bold())
                    .padding(.top)

                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)

                SecureField("Пароль", text: $viewModel.password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)

                Button("Войти") {
                    viewModel.login()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty)

                Button("Войти с Face ID") {
                    authenticateWithFaceID()
                }

                Button("Забыли пароль?") {
                    showForgotPassword = true
                }
                .padding(.top, 5)

                NavigationLink("Регистрация", destination: RegisterView())
                    .padding(.top)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Вход")
            .fullScreenCover(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
        }
    }

    private func authenticateWithFaceID() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Вход с Face ID") { success, error in
                if success {
                    DispatchQueue.main.async {
                        viewModel.isAuthenticated = true
                    }
                } else {
                    DispatchQueue.main.async {
                        viewModel.errorMessage = "Ошибка Face ID"
                    }
                }
            }
        } else {
            viewModel.errorMessage = "Face ID недоступен"
        }
    }
}
