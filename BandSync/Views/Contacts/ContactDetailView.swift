//
//  ContactDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct ContactDetailView: View {
    @StateObject private var contactService = ContactService.shared
    @State private var contact: Contact
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) var dismiss
    
    init(contact: Contact) {
        _contact = State(initialValue: contact)
    }
    
    var body: some View {
        Form {
            // Основная информация
            Section(header: Text("Информация")) {
                if isEditing {
                    TextField("Имя", text: $contact.name)
                    TextField("Роль", text: $contact.role)
                } else {
                    LabeledContent("Имя", value: contact.name)
                    LabeledContent("Роль", value: contact.role)
                }
            }
            
            // Контактные данные
            Section(header: Text("Контактные данные")) {
                if isEditing {
                    TextField("Телефон", text: $contact.phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $contact.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                } else {
                    // Телефон с возможностью звонка
                    Button {
                        call(phone: contact.phone)
                    } label: {
                        HStack {
                            Text("Телефон")
                            Spacer()
                            Text(contact.phone)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Email с возможностью отправки письма
                    Button {
                        sendEmail(to: contact.email)
                    } label: {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(contact.email)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // Кнопки действий (только в режиме просмотра)
            if !isEditing {
                Section {
                    Button {
                        call(phone: contact.phone)
                    } label: {
                        Label("Позвонить", systemImage: "phone")
                    }
                    
                    Button {
                        sendEmail(to: contact.email)
                    } label: {
                        Label("Написать", systemImage: "envelope")
                    }
                    
                    Button {
                        sendSMS(to: contact.phone)
                    } label: {
                        Label("Отправить SMS", systemImage: "message")
                    }
                }
                
                // Кнопка удаления
                if AppState.shared.hasEditPermission(for: .contacts) {
                    Section {
                        Button("Удалить контакт", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Редактирование" : contact.name)
        .toolbar {
            // Кнопка редактирования/сохранения
            if AppState.shared.hasEditPermission(for: .contacts) {
                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        Button("Сохранить") {
                            saveChanges()
                        }
                    } else {
                        Button("Редактировать") {
                            isEditing = true
                        }
                    }
                }
            }
            
            // Кнопка отмены (только в режиме редактирования)
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        // Восстанавливаем исходные данные
                        if let original = contactService.contacts.first(where: { $0.id == contact.id }) {
                            contact = original
                        }
                        isEditing = false
                    }
                }
            }
        }
        .alert("Удалить контакт?", isPresented: $showingDeleteConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                deleteContact()
            }
        } message: {
            Text("Вы уверены, что хотите удалить этот контакт? Это действие нельзя отменить.")
        }
    }
    
    // Функция сохранения изменений
    private func saveChanges() {
        contactService.updateContact(contact) { success in
            if success {
                isEditing = false
            }
        }
    }
    
    // Функция удаления контакта
    private func deleteContact() {
        contactService.deleteContact(contact)
        dismiss()
    }
    
    // Функция звонка
    private func call(phone: String) {
        if let url = URL(string: "tel://\(phone.replacingOccurrences(of: " ", with: ""))"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // Функция отправки email
    private func sendEmail(to: String) {
        if let url = URL(string: "mailto:\(to)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // Функция отправки SMS
    private func sendSMS(to: String) {
        if let url = URL(string: "sms:\(to.replacingOccurrences(of: " ", with: ""))"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
