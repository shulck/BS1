//
//  ContactsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct ContactsView: View {
    @StateObject private var contactService = ContactService.shared
    @State private var showAddContact = false
    @State private var searchText = ""
    @State private var selectedRole: String?
    
    var body: some View {
        NavigationView {
            VStack {
                // Фильтр по ролям
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Кнопка "Все"
                        FilterButton(title: "Все", isSelected: selectedRole == nil) {
                            selectedRole = nil
                        }
                        
                        // Кнопки для каждой роли
                        ForEach(availableRoles, id: \.self) { role in
                            FilterButton(title: role, isSelected: selectedRole == role) {
                                selectedRole = role
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Список контактов
                List {
                    ForEach(groupedAndFilteredContacts.keys.sorted(), id: \.self) { role in
                        if !groupedAndFilteredContacts[role]!.isEmpty {
                            Section(header: Text(role)) {
                                ForEach(groupedAndFilteredContacts[role]!) { contact in
                                    NavigationLink(destination: ContactDetailView(contact: contact)) {
                                        VStack(alignment: .leading) {
                                            Text(contact.name)
                                                .font(.headline)
                                            
                                            Text(contact.phone)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Если нет контактов или ничего не найдено
                    if groupedAndFilteredContacts.isEmpty {
                        if searchText.isEmpty && selectedRole == nil {
                            Text("У вас пока нет контактов")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 20)
                        } else {
                            Text("Ничего не найдено")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 20)
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Поиск контактов")
            }
            .navigationTitle("Контакты")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddContact = true
                    } label: {
                        Label("Добавить", systemImage: "plus")
                    }
                    .disabled(!AppState.shared.hasEditPermission(for: .contacts))
                }
            }
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    contactService.fetchContacts(for: groupId)
                }
            }
            .sheet(isPresented: $showAddContact) {
                AddContactView()
            }
            .refreshable {
                if let groupId = AppState.shared.user?.groupId {
                    contactService.fetchContacts(for: groupId)
                }
            }
        }
    }
    
    // Доступные роли из всех контактов
    private var availableRoles: [String] {
        Array(Set(contactService.contacts.map { $0.role })).sorted()
    }
    
    // Сгруппированные и отфильтрованные контакты
    private var groupedAndFilteredContacts: [String: [Contact]] {
        // Фильтруем контакты по поисковому запросу и выбранной роли
        let filteredContacts = contactService.contacts.filter { contact in
            let matchesSearch = searchText.isEmpty ||
                contact.name.localizedCaseInsensitiveContains(searchText) ||
                contact.phone.localizedCaseInsensitiveContains(searchText) ||
                contact.email.localizedCaseInsensitiveContains(searchText)
            
            let matchesRole = selectedRole == nil || contact.role == selectedRole
            
            return matchesSearch && matchesRole
        }
        
        // Группируем отфильтрованные контакты по роли
        return Dictionary(grouping: filteredContacts, by: { $0.role })
    }
}

// Кнопка фильтра
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}
