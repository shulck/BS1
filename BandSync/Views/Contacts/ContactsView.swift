import SwiftUI
import Contacts
import ContactsUI

struct ContactsView: View {
    @StateObject private var contactService = ContactService.shared
    @State private var searchText = ""
    @State private var showAddContact = false
    @State private var showImportContacts = false
    @State private var selectedCategory: String? = nil
    @State private var isLoading = false
    
    // Категории контактов
    private let categories = ["Все", "Музыканты", "Организаторы", "Площадки", "Другие"]
    
    // Отфильтрованные контакты
    private var filteredContacts: [Contact] {
        var result = contactService.contacts
        
        // Фильтрация по поиску
        if !searchText.isEmpty {
            result = result.filter { contact in
                contact.name.lowercased().contains(searchText.lowercased()) ||
                contact.email.lowercased().contains(searchText.lowercased()) ||
                contact.phone.contains(searchText)
            }
        }
        
        // Фильтрация по категории
        if let category = selectedCategory, category != "Все" {
            result = result.filter { $0.role == category }
        }
        
        return result
    }
    
    // Группировка контактов по первой букве
    private var groupedContacts: [String: [Contact]] {
        Dictionary(grouping: filteredContacts) { contact in
            String(contact.name.prefix(1).uppercased())
        }
    }
    
    // Упорядоченные ключи групп
    private var sortedKeys: [String] {
        groupedContacts.keys.sorted()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Секция с категориями
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(categories, id: \.self) { category in
                                CategoryButton(
                                    title: category,
                                    isSelected: selectedCategory == category,
                                    action: {
                                        if selectedCategory == category {
                                            selectedCategory = nil
                                        } else {
                                            selectedCategory = category
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color.gray.opacity(0.1))
                    
                    // Список контактов
                    List {
                        ForEach(sortedKeys, id: \.self) { key in
                            Section(header: Text(key)) {
                                ForEach(groupedContacts[key] ?? []) { contact in
                                    NavigationLink(destination: ContactDetailView(contact: contact)) {
                                        VStack(alignment: .leading) {
                                            Text(contact.name)
                                                .font(.headline)
                                            Text(contact.role)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Text(contact.phone)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        
                        if filteredContacts.isEmpty {
                            Text("Нет контактов")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                // Отображение индикатора загрузки
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                }
            }
            .navigationTitle("Контакты")
            .searchable(text: $searchText, prompt: "Поиск контактов")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showAddContact = true
                        }) {
                            Label("Добавить контакт", systemImage: "person.badge.plus")
                        }
                        
                        Button(action: {
                            showImportContacts = true
                        }) {
                            Label("Импорт из контактов", systemImage: "person.crop.circle.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                loadContacts()
            }
            .sheet(isPresented: $showAddContact) {
                AddContactView(isPresented: $showAddContact)
            }
            .sheet(isPresented: $showImportContacts) {
                ContactPickerView { contact in
                    if let contact = contact {
                        importSystemContact(contact)
                    }
                    showImportContacts = false
                }
            }
        }
    }
    
    // Загрузка контактов
    private func loadContacts() {
        isLoading = true
        
        if let groupId = AppState.shared.user?.groupId {
            contactService.fetchContacts(for: groupId)
            isLoading = false
        } else {
            isLoading = false
        }
    }
    
    // Импорт контакта из системного контакта
    private func importSystemContact(_ contact: CNContact) {
        guard let groupId = AppState.shared.user?.groupId else { return }
        
        // Получаем имя
        let firstName = contact.givenName
        let lastName = contact.familyName
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        
        // Получаем телефон
        var phoneNumber = ""
        if let phone = contact.phoneNumbers.first?.value.stringValue {
            phoneNumber = phone
        }
        
        // Получаем email
        var emailAddress = ""
        if let email = contact.emailAddresses.first?.value as String? {
            emailAddress = email
        }
        
        // Создаем новый контакт
        let newContact = Contact(
            name: fullName,
            email: emailAddress,
            phone: phoneNumber,
            role: "Другие", // По умолчанию
            groupId: groupId
        )
        
        // Добавляем контакт
        contactService.addContact(newContact) { _ in
            // Обновление завершено
        }
    }
}

// Вспомогательный компонент для кнопок категорий
struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}
