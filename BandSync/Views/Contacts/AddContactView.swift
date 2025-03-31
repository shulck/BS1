import SwiftUI

struct AddContactView: View {
    @Binding var isPresented: Bool
    @StateObject private var contactService = ContactService.shared
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var role = "Музыканты"
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Доступные роли для контактов
    private let roles = ["Музыканты", "Организаторы", "Площадки", "Продюсеры", "Звукорежиссеры", "Другие"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Информация")) {
                    TextField("Имя", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Телефон", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section(header: Text("Категория")) {
                    Picker("Роль", selection: $role) {
                        ForEach(roles, id: \.self) {
                            Text($0)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button("Сохранить") {
                        saveContact()
                    }
                    .disabled(name.isEmpty || phone.isEmpty || isLoading)
                }
            }
            .navigationTitle("Новый контакт")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        isPresented = false
                    }
                }
            }
            .overlay(Group {
                if isLoading {
                    ProgressView()
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                }
            })
        }
    }
    
    private func saveContact() {
        guard let groupId = AppState.shared.user?.groupId else {
            errorMessage = "Не удалось определить группу"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let newContact = Contact(
            name: name,
            email: email,
            phone: phone,
            role: role,
            groupId: groupId
        )
        
        contactService.addContact(newContact) { success in
            isLoading = false
            
            if success {
                isPresented = false
            } else {
                errorMessage = "Не удалось добавить контакт"
            }
        }
    }
}
