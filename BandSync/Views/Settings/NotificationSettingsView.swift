import SwiftUI
import UserNotifications

struct NotificationPreferencesView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = false
    @State private var notificationsEnabled = false
    @State private var settings: NotificationManager.NotificationSettings
    @State private var showPermissionAlert = false
    
    init() {
        // Используем _settings для правильной инициализации
        _settings = State(initialValue: NotificationManager.shared.getNotificationSettings())
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Включить уведомления", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { newValue in
                            if newValue {
                                requestNotificationPermission()
                            }
                        }
                }
                
                if notificationsEnabled {
                    Section(header: Text("Типы уведомлений")) {
                        Toggle("События", isOn: $settings.eventNotificationsEnabled)
                        Toggle("Задачи", isOn: $settings.taskNotificationsEnabled)
                        Toggle("Сообщения", isOn: $settings.chatNotificationsEnabled)
                        Toggle("Системные", isOn: $settings.systemNotificationsEnabled)
                    }
                    
                    Section(header: Text("Напоминания о событиях")) {
                        Text("Уведомления будут отправлены:")
                        
                        Toggle("За день до события", isOn: Binding(
                            get: { settings.eventReminderIntervals.contains(24) },
                            set: { newValue in
                                if newValue {
                                    if !settings.eventReminderIntervals.contains(24) {
                                        settings.eventReminderIntervals.append(24)
                                    }
                                } else {
                                    settings.eventReminderIntervals.removeAll { $0 == 24 }
                                }
                            }
                        ))
                        
                        Toggle("За час до события", isOn: Binding(
                            get: { settings.eventReminderIntervals.contains(1) },
                            set: { newValue in
                                if newValue {
                                    if !settings.eventReminderIntervals.contains(1) {
                                        settings.eventReminderIntervals.append(1)
                                    }
                                } else {
                                    settings.eventReminderIntervals.removeAll { $0 == 1 }
                                }
                            }
                        ))
                    }
                    
                    Section(header: Text("Напоминания о задачах")) {
                        Text("Уведомления будут отправлены:")
                        
                        Toggle("За день до срока", isOn: Binding(
                            get: { settings.taskReminderIntervals.contains(24) },
                            set: { newValue in
                                if newValue {
                                    if !settings.taskReminderIntervals.contains(24) {
                                        settings.taskReminderIntervals.append(24)
                                    }
                                } else {
                                    settings.taskReminderIntervals.removeAll { $0 == 24 }
                                }
                            }
                        ))
                    }
                    
                    Section {
                        Button("Проверить уведомления") {
                            sendTestNotification()
                        }
                    }
                }
            }
            .navigationTitle("Уведомления")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveSettings()
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
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
            .alert("Разрешения", isPresented: $showPermissionAlert) {
                Button("Отмена", role: .cancel) {
                    notificationsEnabled = false
                }
                Button("Настройки") {
                    openSettings()
                }
            } message: {
                Text("Чтобы получать уведомления, необходимо дать разрешение в настройках устройства.")
            }
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
            DispatchQueue.main.async {
                notificationsEnabled = granted
                if !granted {
                    showPermissionAlert = true
                }
                isLoading = false
            }
        }
    }
    
    // Отправка тестового уведомления
    private func sendTestNotification() {
        NotificationManager.shared.scheduleLocalNotification(
            title: "Тестовое уведомление",
            body: "Это тестовое уведомление для проверки настроек",
            date: Date().addingTimeInterval(5),
            identifier: "test_notification_\(UUID().uuidString)",
            userInfo: ["type": "test"]
        ) { success in
            if success {
                // Уведомление запланировано
            }
        }
    }
    
    // Открытие настроек приложения
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // Сохранение настроек
    private func saveSettings() {
        NotificationManager.shared.updateNotificationSettings(settings)
        dismiss()
    }
}
