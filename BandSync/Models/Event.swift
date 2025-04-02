import Foundation
import FirebaseFirestore

struct Event: Identifiable, Codable {
    @DocumentID var id: String?
    
    var title: String
    var date: Date
    var type: EventType
    var status: EventStatus
    var location: String?
    
    var organizerName: String?
    var organizerEmail: String?
    var organizerPhone: String?
    
    var coordinatorName: String?
    var coordinatorEmail: String?
    var coordinatorPhone: String?
    
    var hotelName: String?
    var hotelCheckIn: Date?
    var hotelCheckOut: Date?
    var hotelAddress: String? // Добавлено новое поле для адреса отеля
    
    var fee: Double?
    var currency: String?
    
    var notes: String?
    var schedule: [String]?
    
    var setlistId: String?
    var groupId: String
    var isPersonal: Bool
}
