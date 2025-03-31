//
//  GroupSettingsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  GroupSettingsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct GroupSettingsView: View {
    @StateObject private var groupService = GroupService.shared
    @State private var newName = ""

    var body: some View {
        Form {
            Section(header: Text("Название группы")) {
                TextField("Новое имя", text: $newName)
                Button("Обновить") {
                    groupService.updateGroupName(newName)
                }
            }

            Section(header: Text("Код приглашения")) {
                if let code = groupService.group?.code {
                    Text("Код: \(code)")
                    Button("Сгенерировать новый") {
                        groupService.regenerateCode()
                    }
                }
            }
        }
        .navigationTitle("Настройки группы")
        .onAppear {
            if let gid = AppState.shared.user?.groupId {
                groupService.fetchGroup(by: gid)
                newName = groupService.group?.name ?? ""
            }
        }
    }
}
