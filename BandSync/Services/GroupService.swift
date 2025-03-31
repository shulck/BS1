//
//  GroupService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  GroupService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore


final class GroupService: ObservableObject {
    static let shared = GroupService()

    @Published var group: GroupModel?

    private let db = Firestore.firestore()

    func fetchGroup(by id: String) {
        db.collection("groups").document(id).addSnapshotListener { snapshot, _ in
            if let data = try? snapshot?.data(as: GroupModel.self) {
                DispatchQueue.main.async {
                    self.group = data
                }
            }
        }
    }

    func approveUser(userId: String) {
        guard let groupId = group?.id else { return }

        db.collection("groups").document(groupId).updateData([
            "pendingMembers": FieldValue.arrayRemove([userId]),
            "members": FieldValue.arrayUnion([userId])
        ])
    }

    func rejectUser(userId: String) {
        guard let groupId = group?.id else { return }

        db.collection("groups").document(groupId).updateData([
            "pendingMembers": FieldValue.arrayRemove([userId])
        ])
    }

    func removeUser(userId: String) {
        guard let groupId = group?.id else { return }

        db.collection("groups").document(groupId).updateData([
            "members": FieldValue.arrayRemove([userId])
        ])
    }

    func updateGroupName(_ newName: String) {
        guard let groupId = group?.id else { return }

        db.collection("groups").document(groupId).updateData([
            "name": newName
        ])
    }

    func regenerateCode() {
        guard let groupId = group?.id else { return }
        let newCode = UUID().uuidString.prefix(6).uppercased()

        db.collection("groups").document(groupId).updateData([
            "code": String(newCode)
        ])
    }
}
