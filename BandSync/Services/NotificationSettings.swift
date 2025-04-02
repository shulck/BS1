//
//  NotificationSettings.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//
import Foundation
import SwiftUI

// Расширим настройки уведомлений NotificationManager
extension NotificationManager {
    // Настройки уведомлений с новыми интервалами для событий
    struct NotificationSettings: Codable {
        var eventNotificationsEnabled = true
        var taskNotificationsEnabled = true
        var chatNotificationsEnabled = true
        var systemNotificationsEnabled = true
        
        // Интервалы уведомлений для событий (в часах)
        var eventReminderIntervals = [24, 12, 1] // За день, вечером накануне, за час
        
        // Интервалы уведомлений для задач (в часах)
        var taskReminderIntervals = [24] // За день
        
        // Включение отдельных настроек для личных событий
        var personalEventExtraNotifications = true
    }
}
