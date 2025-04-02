import SwiftUI

// Расширение для типа события, чтобы добавить цветовую кодировку
extension EventType {
    var color: Color {
        switch self {
        case .concert:
            return Color.red
        case .rehearsal:
            return Color.blue
        case .meeting:
            return Color.green
        case .interview:
            return Color.purple
        case .photoshoot:
            return Color.orange
        case .personal:
            return Color.gray
        }
    }
}

// Вспомогательное расширение для Event с getters удобными для отображения
extension Event {
    var isUpcoming: Bool {
        return date > Date()
    }
    
    var isPast: Bool {
        return date < Date()
    }
    
    var isToday: Bool {
        return Calendar.current.isDateInToday(date)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var typeColor: Color {
        return type.color
    }
}
