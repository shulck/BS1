//
//  NewChatView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  NewChatView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct NewChatView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var isGroup = true

    var body: some View {
        NavigationView {
            Form {
                TextField("Название чата", text: $name)
                Toggle("Групповой чат", isOn: $isGroup)
            }
            .navigationTitle("Новый чат")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        createChat()
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

    private func createChat() {
        guard let currentId = AppState.shared.user?.id else { return }
        let participants = [currentId]
        let type: ChatType = isGroup ? .group : .direct

        ChatService.shared.createChat(name: name, type: type, participants: participants) { success in
            if success { dismiss() }
        }
    }
}
