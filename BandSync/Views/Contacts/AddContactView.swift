//
//  AddContactView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI
import Contacts

struct AddContactView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var contactService = ContactService.shared
    
    // Данные контакта
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var role = "Музыкант"
    
    // UI states
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showImportFromContacts = false
    
    // Предопределенные роли
    let roles = [
        "Музыкант",
        "Организатор",
        "Площадка",
        "Звукорежиссер",
        "Менеджер",
        "Промоутер",
        "Партнёр",
        "Другое"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // Основная информация
                Section(header: Text("Основная информация")) {
                    TextField("Имя", text: $name)
                    
                    Picker("Роль", selection: $role) {
                        ForEach(roles, id: \.self) {
                            Text($0)
                        }
                    }
                }
                
                // Контактные данные
                Section(header: Text("Контактные данные")) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)
                    
                    TextField("Телефон", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
                
                // Импорт из контактов
                Section {
                    Button {
                        showImportFromContacts = true
                    } label: {
                        Label("Импортировать из контактов", systemImage: "person.crop.circle.badge.plus")
                    }
                }
                
                // Ошибки
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                // Индикатор загрузки
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Новый контакт")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveContact()
                    }
                    .disabled(name.isEmpty || phone.isEmpty || isLoading)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImportFromContacts) {
                ContactPickerView { selectedContact in
                    if let contact = selectedContact {
                        // Заполняем поля данными из контакта
                        name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Получаем телефон (первый в списке)
                        if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                            phone = phoneNumber
                        }
                        
                        // Получаем email (первый в списке)
                        if let emailAddress = contact.emailAddresses.first?.value as String? {
                            email = emailAddress
                        }
                    }
                }
            }
        }
    }
    
    private func saveContact() {
        guard let groupId = AppState.shared.user?.groupId else {
            errorMessage = "Не удалось определить группу"
            return
        }
        
        isLoading = true
        
        let newContact = Contact(
            name: name,
            email: email,
            phone: phone,
            role: role,
            groupId: groupId
        )
        
        contactService.addContact(newContact) { success in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    dismiss()
                } else {
                    errorMessage = "Не удалось добавить контакт"
                }
            }
        }
    }
}

// Представление для выбора контакта из адресной книги устройства
struct ContactPickerView: UIViewControllerRepresentable {
    var onContactPicked: (CNContact?) -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerView
        
        init(_ parent: ContactPickerView) {
            self.parent = parent
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.onContactPicked(nil)
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onContactPicked(contact)
        }
    }
}
