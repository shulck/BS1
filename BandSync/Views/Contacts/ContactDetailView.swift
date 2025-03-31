//
//  ContactDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  ContactDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct ContactDetailView: View {
    let contact: Contact

    var body: some View {
        Form {
            Section(header: Text("Информация")) {
                Text("Имя: \(contact.name)")
                Text("Роль: \(contact.role)")
            }

            Section(header: Text("Контакты")) {
                Button {
                    call(phone: contact.phone)
                } label: {
                    Label(contact.phone, systemImage: "phone")
                }

                Button {
                    sendEmail(to: contact.email)
                } label: {
                    Label(contact.email, systemImage: "envelope")
                }
            }
        }
        .navigationTitle(contact.name)
    }

    private func call(phone: String) {
        if let url = URL(string: "tel://\(phone)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func sendEmail(to: String) {
        if let url = URL(string: "mailto:\(to)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
