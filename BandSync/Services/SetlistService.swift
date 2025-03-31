//
//  SetlistService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  SetlistService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore


final class SetlistService: ObservableObject {
    static let shared = SetlistService()
    
    @Published var setlists: [Setlist] = []

    private let db = Firestore.firestore()

    func fetchSetlists(for groupId: String) {
        db.collection("setlists")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments { [weak self] snapshot, error in
                if let docs = snapshot?.documents {
                    let items = docs.compactMap { try? $0.data(as: Setlist.self) }
                    DispatchQueue.main.async {
                        self?.setlists = items
                    }
                } else {
                    print("Ошибка загрузки сетлистов: \(error?.localizedDescription ?? "неизвестно")")
                }
            }
    }

    func addSetlist(_ setlist: Setlist, completion: @escaping (Bool) -> Void) {
        do {
            _ = try db.collection("setlists").addDocument(from: setlist) { error in
                if let error = error {
                    print("Ошибка добавления сетлиста: \(error.localizedDescription)")
                    completion(false)
                } else {
                    self.fetchSetlists(for: setlist.groupId)
                    completion(true)
                }
            }
        } catch {
            print("Ошибка сериализации сетлиста: \(error)")
            completion(false)
        }
    }

    func updateSetlist(_ setlist: Setlist, completion: @escaping (Bool) -> Void) {
        guard let id = setlist.id else { return }
        do {
            try db.collection("setlists").document(id).setData(from: setlist) { error in
                if let error = error {
                    print("Ошибка обновления сетлиста: \(error.localizedDescription)")
                    completion(false)
                } else {
                    self.fetchSetlists(for: setlist.groupId)
                    completion(true)
                }
            }
        } catch {
            print("Ошибка сериализации: \(error)")
            completion(false)
        }
    }

    func deleteSetlist(_ setlist: Setlist) {
        guard let id = setlist.id else { return }
        db.collection("setlists").document(id).delete { error in
            if let error = error {
                print("Ошибка удаления сетлиста: \(error.localizedDescription)")
            } else if let groupId = AppState.shared.user?.groupId {
                self.fetchSetlists(for: groupId)
            }
        }
    }
}
