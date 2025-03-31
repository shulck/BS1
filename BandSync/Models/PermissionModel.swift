//
//  PermissionModel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  PermissionModel.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import Foundation
import FirebaseFirestore

struct PermissionModel: Identifiable, Codable {
    @DocumentID var id: String?
    var groupId: String
    var modules: [ModulePermission]
    
    struct ModulePermission: Codable, Hashable {
        var moduleId: ModuleType
        var roleAccess: [UserModel.UserRole]
        
        // Проверка, имеет ли роль доступ к модулю
        func hasAccess(role: UserModel.UserRole) -> Bool {
            return roleAccess.contains(role)
        }
    }
}

// Типы модулей приложения
enum ModuleType: String, Codable, CaseIterable, Identifiable {
    case calendar = "calendar"
    case setlists = "setlists"
    case finances = "finances"
    case merchandise = "merchandise"
    case tasks = "tasks"
    case chats = "chats"
    case contacts = "contacts"
    case admin = "admin"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .calendar: return "Календарь"
        case .setlists: return "Сетлисты"
        case .finances: return "Финансы"
        case .merchandise: return "Мерч"
        case .tasks: return "Задачи"
        case .chats: return "Чаты"
        case .contacts: return "Контакты"
        case .admin: return "Админ-панель"
        }
    }
    
    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .setlists: return "music.note.list"
        case .finances: return "dollarsign.circle"
        case .merchandise: return "bag"
        case .tasks: return "checklist"
        case .chats: return "message"
        case .contacts: return "person.crop.circle"
        case .admin: return "person.3"
        }
    }
}