//
//  AddContactView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  AddContactView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct AddContactView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var role = "Музыкант"

    let roles = ["Музыкант", "Организатор", "Площадка", "Партнёр", "Другое"]

    var body: some View {
        NavigationView {
            Form {
                TextField("Имя", text: $name)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                TextField("Телефон", text: $phone)
                    .keyboardType(.phonePad)

                Picker("Роль", selection: $role) {
                    ForEach(roles, id: \.self) {
                        Text($0)
                    }
                }
            }
            .navigationTitle("Новый контакт")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        guard let groupId = AppState.shared.user?.groupId else { return }
                        let newContact = Contact(name: name, email: email, phone: phone, role: role, groupId: groupId)
                        ContactService.shared.addContact(newContact) { success in
                            if success { dismiss() }
                        }
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}
