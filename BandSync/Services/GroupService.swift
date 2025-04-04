import Foundation
import FirebaseFirestore
import Combine

final class GroupService: ObservableObject {
    static let shared = GroupService()

    @Published var group: GroupModel?
    @Published var groupMembers: [UserModel] = []
    @Published var pendingMembers: [UserModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        // Clean up listeners when service is deallocated
        removeListeners()
    }
    
    // Remove all active listeners
    private func removeListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // Get group information by ID with real-time updates
    func fetchGroup(by id: String) {
        isLoading = true
        errorMessage = nil
        
        // Remove existing listeners before adding new ones
        removeListeners()
        
        let listener = db.collection("groups").document(id).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.errorMessage = "Error loading group: \(error.localizedDescription)"
                self.isLoading = false
                return
            }
            
            if let data = try? snapshot?.data(as: GroupModel.self) {
                DispatchQueue.main.async {
                    self.group = data
                    self.fetchGroupMembers(groupId: id)
                }
            } else {
                self.errorMessage = "Error converting group data"
                self.isLoading = false
            }
        }
        
        // Store listener for cleanup
        listeners.append(listener)
    }

    // Get information about group users with batch queries
    private func fetchGroupMembers(groupId: String) {
        guard let group = self.group else { return }
        
        // Clear existing data
        self.groupMembers = []
        self.pendingMembers = []
        
        // Check if there are members to fetch
        if group.members.isEmpty && group.pendingMembers.isEmpty {
            self.isLoading = false
            return
        }
        
        // Get active members with batch query
        if !group.members.isEmpty {
            db.collection("users")
                .whereField("id", in: group.members)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error fetching group members: \(error.localizedDescription)")
                        self.errorMessage = "Error loading members: \(error.localizedDescription)"
                        return
                    }
                    
                    if let docs = snapshot?.documents {
                        let members = docs.compactMap { try? $0.data(as: UserModel.self) }
                        DispatchQueue.main.async {
                            self.groupMembers = members
                            self.isLoading = false
                        }
                    } else {
                        self.isLoading = false
                    }
                }
        }
        
        // Get pending members with batch query
        if !group.pendingMembers.isEmpty {
            db.collection("users")
                .whereField("id", in: group.pendingMembers)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error fetching pending members: \(error.localizedDescription)")
                        self.errorMessage = "Error loading pending members: \(error.localizedDescription)"
                        return
                    }
                    
                    if let docs = snapshot?.documents {
                        let members = docs.compactMap { try? $0.data(as: UserModel.self) }
                        DispatchQueue.main.async {
                            self.pendingMembers = members
                        }
                    }
                }
        }
    }
    
    // Approve user (move from pending to members)
    func approveUser(userId: String) {
        guard let groupId = group?.id else {
            errorMessage = "Group information not available"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let batch = db.batch()
        
        // Reference to group document
        let groupRef = db.collection("groups").document(groupId)
        
        // Reference to user document
        let userRef = db.collection("users").document(userId)
        
        // Remove from pending and add to members in one transaction
        batch.updateData([
            "pendingMembers": FieldValue.arrayRemove([userId]),
            "members": FieldValue.arrayUnion([userId])
        ], forDocument: groupRef)
        
        // Set user role to Member
        batch.updateData([
            "role": UserModel.UserRole.member.rawValue
        ], forDocument: userRef)
        
        // Commit the batch
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error approving user: \(error.localizedDescription)"
                } else {
                    self.successMessage = "User approved successfully"
                    
                    // Update local data
                    if let pendingIndex = self.pendingMembers.firstIndex(where: { $0.id == userId }) {
                        var approvedUser = self.pendingMembers[pendingIndex]
                        approvedUser.role = .member
                        
                        // Remove from pending
                        self.pendingMembers.remove(at: pendingIndex)
                        
                        // Add to members
                        self.groupMembers.append(approvedUser)
                    }
                }
            }
        }
    }

    // Reject user application
    func rejectUser(userId: String) {
        guard let groupId = group?.id else {
            errorMessage = "Group information not available"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let batch = db.batch()
        
        // Reference to group document
        let groupRef = db.collection("groups").document(groupId)
        
        // Reference to user document
        let userRef = db.collection("users").document(userId)
        
        // Remove from pending members
        batch.updateData([
            "pendingMembers": FieldValue.arrayRemove([userId])
        ], forDocument: groupRef)
        
        // Clear groupId in user profile
        batch.updateData([
            "groupId": FieldValue.delete()
        ], forDocument: userRef)
        
        // Commit the batch
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error rejecting user: \(error.localizedDescription)"
                } else {
                    self.successMessage = "User rejected successfully"
                    
                    // Update local data - remove from pending list
                    if let pendingIndex = self.pendingMembers.firstIndex(where: { $0.id == userId }) {
                        self.pendingMembers.remove(at: pendingIndex)
                    }
                }
            }
        }
    }

    // Remove user from group
    func removeUser(userId: String) {
        guard let groupId = group?.id else {
            errorMessage = "Group information not available"
            return
        }
        
        // Check if user is the last admin
        if isLastAdmin(userId) {
            errorMessage = "Cannot remove the last administrator from group"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let batch = db.batch()
        
        // Reference to group document
        let groupRef = db.collection("groups").document(groupId)
        
        // Reference to user document
        let userRef = db.collection("users").document(userId)
        
        // Remove from members list
        batch.updateData([
            "members": FieldValue.arrayRemove([userId])
        ], forDocument: groupRef)
        
        // Clear groupId in user profile and reset role
        batch.updateData([
            "groupId": FieldValue.delete(),
            "role": UserModel.UserRole.member.rawValue
        ], forDocument: userRef)
        
        // Commit the batch
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error removing user: \(error.localizedDescription)"
                } else {
                    self.successMessage = "User removed successfully"
                    
                    // Update local data - remove from members list
                    if let memberIndex = self.groupMembers.firstIndex(where: { $0.id == userId }) {
                        self.groupMembers.remove(at: memberIndex)
                    }
                }
            }
        }
    }

    // Update group name with validation
    func updateGroupName(_ newName: String) {
        guard let groupId = group?.id else {
            errorMessage = "Group information not available"
            return
        }
        
        // Validate input
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errorMessage = "Group name cannot be empty"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // First check if the name already exists in another group
        db.collection("groups")
            .whereField("name", isEqualTo: trimmedName)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.isLoading = false
                    self.errorMessage = "Error checking group name: \(error.localizedDescription)"
                    return
                }
                
                // Check if name is already used by another group
                if let snapshot = snapshot, !snapshot.documents.isEmpty {
                    for document in snapshot.documents {
                        if document.documentID != groupId {
                            // Found another group with the same name
                            self.isLoading = false
                            self.errorMessage = "A group with this name already exists"
                            return
                        }
                    }
                }
                
                // Name is unique or belongs to this group, proceed with update
                self.db.collection("groups").document(groupId).updateData([
                    "name": trimmedName
                ]) { error in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        if let error = error {
                            self.errorMessage = "Error updating name: \(error.localizedDescription)"
                        } else {
                            self.successMessage = "Group name updated successfully"
                            
                            // Update local data
                            self.group?.name = trimmedName
                        }
                    }
                }
            }
    }

    // Generate new invitation code
    func regenerateCode() {
        guard let groupId = group?.id else {
            errorMessage = "Group information not available"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Generate a new, unique 6-character code
        let newCode = generateUniqueCode()

        db.collection("groups").document(groupId).updateData([
            "code": newCode
        ]) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error updating code: \(error.localizedDescription)"
                } else {
                    self.successMessage = "Invitation code updated successfully"
                    
                    // Update local data
                    self.group?.code = newCode
                }
            }
        }
    }
    
    // Change user role
    func changeUserRole(userId: String, newRole: UserModel.UserRole) {
        // Safety check - don't allow changing role of the last admin
        if newRole != .admin && isLastAdmin(userId) {
            errorMessage = "Cannot change role of the last administrator"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        db.collection("users").document(userId).updateData([
            "role": newRole.rawValue
        ]) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error changing role: \(error.localizedDescription)"
                } else {
                    self.successMessage = "User role updated successfully"
                    
                    // Update local data
                    if let memberIndex = self.groupMembers.firstIndex(where: { $0.id == userId }) {
                        var updatedUser = self.groupMembers[memberIndex]
                        updatedUser.role = newRole
                        self.groupMembers[memberIndex] = updatedUser
                    }
                }
            }
        }
    }
    
    // Check if a user is the last admin in the group
    private func isLastAdmin(_ userId: String) -> Bool {
        let admins = groupMembers.filter { $0.role == .admin }
        return admins.count == 1 && admins.first?.id == userId
    }
    
    // Generate a unique invitation code
    private func generateUniqueCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Omitting easily confused characters
        let length = 6
        
        var result = ""
        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<characters.count)
            let randomCharacter = characters[characters.index(characters.startIndex, offsetBy: randomIndex)]
            result.append(randomCharacter)
        }
        
        return result
    }
    
    // Export group data (for backup)
    func exportGroupData(completion: @escaping (Result<Data, Error>) -> Void) {
        guard let groupId = group?.id else {
            let error = NSError(domain: "GroupService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No group loaded"])
            completion(.failure(error))
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Create a dictionary to hold all group data
        var exportData: [String: Any] = [:]
        
        // Start with the group itself
        fetchGroupOnce(by: groupId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let group):
                exportData["group"] = group
                
                // Now we could fetch related data like events, setlists, etc.
                // This would be implemented based on your app's specific needs
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
                    DispatchQueue.main.async {
                        self.isLoading = false
                        completion(.success(jsonData))
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Error serializing group data: \(error.localizedDescription)"
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Error exporting group data: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Fetch group data once (not as a listener)
    func fetchGroupOnce(by id: String, completion: @escaping (Result<GroupModel, Error>) -> Void) {
        db.collection("groups").document(id).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            do {
                if let snapshot = snapshot, let group = try? snapshot.data(as: GroupModel.self) {
                    completion(.success(group))
                } else {
                    let error = NSError(domain: "GroupService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Group not found"])
                    completion(.failure(error))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
}
