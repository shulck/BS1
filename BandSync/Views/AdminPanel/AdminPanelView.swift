//
//  AdminPanelView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  AdminPanelView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct AdminPanelView: View {
    @State private var showUsers = false
    @State private var showSettings = false

    var body: some View {
        NavigationView {
            List {
                NavigationLink("Участники группы", destination: UsersListView())
                NavigationLink("Настройки группы", destination: GroupSettingsView())
            }
            .navigationTitle("Админ-панель")
        }
    }
}
