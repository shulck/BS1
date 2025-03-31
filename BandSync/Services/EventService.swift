//
//  EventService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  EventService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore


final class EventService: ObservableObject {
    static let shared = EventService()

    @Published var events: [Event] = []

    private let db = Firestore.firestore()

    func fetchEvents(for groupId: String) {
        db.collection("events")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments { [weak self] snapshot, error in
                if let docs = snapshot?.documents {
                    let events = docs.compactMap { try? $0.data(as: Event.self) }
                    DispatchQueue.main.async {
                        self?.events = events
                    }
                } else {
                    print("Ошибка загрузки событий: \(error?.localizedDescription ?? "неизвестно")")
                }
            }
    }

    func addEvent(_ event: Event, completion: @escaping (Bool) -> Void) {
        do {
            _ = try db.collection("events").addDocument(from: event) { error in
                if let error = error {
                    print("Ошибка добавления события: \(error.localizedDescription)")
                    completion(false)
                } else {
                    self.fetchEvents(for: event.groupId)
                    completion(true)
                }
            }
        } catch {
            print("Ошибка сериализации события: \(error)")
            completion(false)
        }
    }

    func updateEvent(_ event: Event, completion: @escaping (Bool) -> Void) {
        guard let id = event.id else { return }
        do {
            try db.collection("events").document(id).setData(from: event) { error in
                if let error = error {
                    print("Ошибка обновления события: \(error.localizedDescription)")
                    completion(false)
                } else {
                    self.fetchEvents(for: event.groupId)
                    completion(true)
                }
            }
        } catch {
            print("Ошибка сериализации события: \(error)")
            completion(false)
        }
    }

    func deleteEvent(_ event: Event) {
        guard let id = event.id else { return }
        db.collection("events").document(id).delete { error in
            if let error = error {
                print("Ошибка удаления: \(error.localizedDescription)")
            } else if let groupId = AppState.shared.user?.groupId {
                self.fetchEvents(for: groupId)
            }
        }
    }
}
