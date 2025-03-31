//
//  ContactsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  ContactsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct ContactsView: View {
    @StateObject private var service = ContactService.shared
    @State private var showAdd = false

    var body: some View {
        NavigationView {
            List {
                ForEach(groupedContacts.keys.sorted(), id: \.self) { role in
                    Section(header: Text(role)) {
                        ForEach(groupedContacts[role] ?? []) { contact in
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
            .navigationTitle("Контакты")
            .toolbar {
                Button {
                    showAdd = true
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
            }
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    service.fetchContacts(for: groupId)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddContactView()
            }
        }
    }

    private var groupedContacts: [String: [Contact]] {
        Dictionary(grouping: service.contacts, by: { $0.role })
    }
}
