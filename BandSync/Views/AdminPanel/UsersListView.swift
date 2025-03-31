//
//  UsersListView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  UsersListView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct UsersListView: View {
    @StateObject private var groupService = GroupService.shared
    @StateObject private var userService = UserService.shared

    var body: some View {
        List {
            if let members = groupService.group?.members {
                Section(header: Text("Участники")) {
                    ForEach(members, id: \.self) { uid in
                        HStack {
                            Text(uid)
                            Spacer()
                            NavigationLink("Роль", destination: RoleView(userId: uid))
                        }
                    }
                }
            }

            if let pending = groupService.group?.pendingMembers, !pending.isEmpty {
                Section(header: Text("Ожидают одобрения")) {
                    ForEach(pending, id: \.self) { uid in
                        HStack {
                            Text(uid)
                            Spacer()
                            Button("Принять") {
                                groupService.approveUser(userId: uid)
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Отклонить") {
                                groupService.rejectUser(userId: uid)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .navigationTitle("Участники группы")
        .onAppear {
            if let gid = AppState.shared.user?.groupId {
                groupService.fetchGroup(by: gid)
            }
        }
    }
}
