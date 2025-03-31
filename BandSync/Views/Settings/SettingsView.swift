//
//  SettingsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import SwiftUI

struct SettingsView: View {
    @StateObject private var locManager = LocalizationManager.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Язык интерфейса")) {
                    Picker("Язык", selection: $locManager.currentLanguage) {
                        ForEach(LocalizationManager.Language.allCases) { lang in
                            Text(lang.name).tag(lang)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    Button("Выйти") {
                        AppState.shared.logout()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Настройки")
        }
    }
}
