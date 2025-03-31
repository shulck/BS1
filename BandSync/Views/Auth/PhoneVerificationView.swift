//
//  PhoneVerificationView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import SwiftUI
import FirebaseAuth

struct PhoneVerificationView: View {
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var verificationID: String?
    @State private var isVerified = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Подтверждение номера")
                .font(.title.bold())
                .padding(.top)

            TextField("Номер телефона", text: $phoneNumber)
                .keyboardType(.phonePad)
                .textFieldStyle(.roundedBorder)

            Button("Отправить код") {
                sendCode()
            }

            if verificationID != nil {
                TextField("Код из SMS", text: $verificationCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)

                Button("Подтвердить") {
                    verifyCode()
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }

            if isVerified {
                Text("Телефон подтверждён ✅")
                    .foregroundColor(.green)
            }

            Spacer()
        }
        .padding()
    }

    private func sendCode() {
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { id, error in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            verificationID = id
            errorMessage = nil
        }
    }

    private func verifyCode() {
        guard let id = verificationID else { return }
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: id, verificationCode: verificationCode)

        Auth.auth().signIn(with: credential) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                isVerified = true
                errorMessage = nil
            }
        }
    }
}
