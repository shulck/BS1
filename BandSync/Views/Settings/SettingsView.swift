//
//  SettingsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var appState = AppState.shared
    @State private var selectedLanguage = Bundle.main.preferredLocalizations.first ?? "en"
    @State private var showLogoutConfirmation = false
    @State private var showNotificationSettings = false
    
    // Доступные языки
    let languages = [
        ("en", "English"),
        ("ru", "Русский"),
        ("de", "Deutsch"),
        ("uk", "Українська")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // Информация о пользователе
                if let user = appState.user {
                    Section(header: Text("Account".localized)) {
                        HStack {
                            Image(systemName: "person.circle")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text(user.role.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                
                // Раздел приложения
                Section(header: Text("Application".localized)) {
                    // Выбор языка
                    Picker("Interface Language".localized, selection: $selectedLanguage) {
                        ForEach(languages, id: \.0) { languageCode, languageName in
                            Text(languageName).tag(languageCode)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: selectedLanguage) { newValue in
                        // Сохраняем выбранный язык
                        UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                        UserDefaults.standard.synchronize()
                        
                        // Показываем оповещение о необходимости перезапуска
                        showLanguageChangeAlert()
                    }
                    
                    // Настройки уведомлений
                    Button(action: {
                        showNotificationSettings = true
                    }) {
                        HStack {
                            Text("Notifications".localized)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Настройки кэша
                    NavigationLink(destination: CacheSettingsView()) {
                        HStack {
                            Text("Cache Settings".localized)
                            Spacer()
                        }
                    }
                }
                
                // Группа
                if let group = appState.user?.groupId {
                    Section(header: Text("Group".localized)) {
                        NavigationLink(destination: GroupDetailsView()) {
                            Label("Group Information".localized, systemImage: "music.mic")
                        }
                    }
                }
                
                // О приложении
                Section(header: Text("About".localized)) {
                    HStack {
                        Text("Version".localized)
                        Spacer()
                        Text(getAppVersion())
                            .foregroundColor(.gray)
                    }
                    
                    Link(destination: URL(string: "https://bandsync.app/privacy")!) {
                        HStack {
                            Text("Privacy Policy".localized)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote)
                        }
                    }
                    
                    Link(destination: URL(string: "https://bandsync.app/terms")!) {
                        HStack {
                            Text("Terms of Service".localized)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote)
                        }
                    }
                }
                
                // Выход
                Section {
                    Button(action: {
                        showLogoutConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Sign Out".localized)
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings".localized)
            .alert(isPresented: $showLogoutConfirmation) {
                Alert(
                    title: Text("Sign Out?".localized),
                    message: Text("Are you sure you want to sign out?".localized),
                    primaryButton: .destructive(Text("Sign Out".localized)) {
                        appState.logout()
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsView()
            }
        }
    }
    
    // Получение версии приложения
    private func getAppVersion() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(appVersion) (\(buildNumber))"
    }
    
    // Показать уведомление о смене языка
    private func showLanguageChangeAlert() {
        let alertController = UIAlertController(
            title: NSLocalizedString("Restart Required", comment: ""),
            message: NSLocalizedString("Please restart the app for the language change to take effect.", comment: ""),
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(
            title: NSLocalizedString("OK", comment: ""),
            style: .default,
            handler: nil
        ))
        
        // Получаем текущее окно для отображения alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alertController, animated: true, completion: nil)
        }
    }
}

// Представление с деталями группы
struct GroupDetailsView: View {
    @StateObject private var groupService = GroupService.shared
    
    var body: some View {
        List {
            if let group = groupService.group {
                Section(header: Text("Group Information".localized)) {
                    HStack {
                        Text("Name".localized)
                        Spacer()
                        Text(group.name)
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Members".localized)
                        Spacer()
                        Text("\(group.members.count)")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Invitation Code".localized)
                        Spacer()
                        Text(group.code)
                            .foregroundColor(.gray)
                        Button {
                            UIPasteboard.general.string = group.code
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                        }
                    }
                }
            } else {
                Text("Loading...".localized)
            }
        }
        .navigationTitle("Group".localized)
        .onAppear {
            if let groupId = AppState.shared.user?.groupId {
                groupService.fetchGroup(by: groupId)
            }
        }
    }
}

// Представление настроек уведомлений
struct NotificationSettingsView: View {
    @State private var isLoading = false
    @State private var notificationsEnabled = false
    @State private var eventNotifications = true
    @State private var chatNotifications = true
    @State private var taskNotifications = true
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Enable Notifications".localized, isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { newValue in
                            if newValue {
                                requestNotificationPermission()
                            }
                        }
                }
                
                if notificationsEnabled {
                    Section(header: Text("Notification Types".localized)) {
                        Toggle("Events".localized, isOn: $eventNotifications)
                        Toggle("Chats".localized, isOn: $chatNotifications)
                        Toggle("Tasks".localized, isOn: $taskNotifications)
                    }
                    
                    Section(header: Text("Event Reminders".localized)) {
                        Text("Events will send notifications:".localized)
                        Text("• 1 day before".localized)
                            .foregroundColor(.secondary)
                        Text("• 1 hour before".localized)
                            .foregroundColor(.secondary)
                    }
                    
                    Section(header: Text("Task Reminders".localized)) {
                        Text("Tasks will send notifications:".localized)
                        Text("• 1 day before due date".localized)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Notifications".localized)
            .onAppear {
                checkNotificationStatus()
            }
            .overlay(Group {
                if isLoading {
                    ProgressView()
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                        .shadow(radius: 3)
                }
            })
        }
    }
    
    // Проверка статуса разрешений на уведомления
    private func checkNotificationStatus() {
        isLoading = true
        NotificationManager.shared.checkAuthorizationStatus { status in
            notificationsEnabled = status == .authorized
            isLoading = false
        }
    }
    
    // Запрос разрешения на уведомления
    private func requestNotificationPermission() {
        isLoading = true
        NotificationManager.shared.requestAuthorization { granted in
            notificationsEnabled = granted
            isLoading = false
        }
    }
}
