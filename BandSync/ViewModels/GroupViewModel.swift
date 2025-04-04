import Foundation
import Combine
import FirebaseFirestore

final class GroupViewModel: ObservableObject {
    @Published var groupName = ""
    @Published var groupCode = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var pendingMembers: [String] = []
    @Published var members: [String] = []
    @Published var showSuccessAlert = false
    
    // Group code validation
    @Published var isValidCode = false
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Setup code validation publisher
        $groupCode
            .map { code -> Bool in
                return code.count == 6
            }
            .assign(to: \.isValidCode, on: self)
            .store(in: &cancellables)
    }
    
    // Create a new group
    func createGroup(completion: @escaping (Result<String, Error>) -> Void) {
        guard let userId = AuthService.shared.currentUserUID(), !groupName.isEmpty else {
            errorMessage = "You must specify a group name"
            completion(.failure(NSError(domain: "EmptyGroupName", code: -1, userInfo: [NSLocalizedDescriptionKey: "Group name cannot be empty"])))
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Generate a unique 6-character code
        let groupCode = generateUniqueCode()
        
        let newGroup = GroupModel(
            name: groupName.trimmingCharacters(in: .whitespacesAndNewlines),
            code: groupCode,
            members: [userId],
            pendingMembers: []
        )
        
        // First check if the group name already exists
        db.collection("groups")
            .whereField("name", isEqualTo: newGroup.name)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.handleError(error, "Error checking existing groups", completion)
                    return
                }
                
                // Check if group name already exists
                if let snapshot = snapshot, !snapshot.documents.isEmpty {
                    self.isLoading = false
                    self.errorMessage = "A group with this name already exists"
                    completion(.failure(NSError(domain: "DuplicateGroupName", code: -2, userInfo: [NSLocalizedDescriptionKey: "A group with this name already exists"])))
                    return
                }
                
                // Continue with group creation
                self.createGroupDocument(newGroup, userId: userId, completion: completion)
            }
    }
    
    // Helper method to create the group document
    private func createGroupDocument(_ newGroup: GroupModel, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        do {
            try db.collection("groups").addDocument(from: newGroup) { [weak self] error in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error creating group: \(error.localizedDescription)"
                    completion(.failure(error))
                    return
                }
                
                self.successMessage = "Group successfully created!"
                
                // Get the ID of the created group
                self.db.collection("groups")
                    .whereField("code", isEqualTo: newGroup.code)
                    .getDocuments { [weak self] snapshot, error in
                        guard let self = self else { return }
                        
                        if let error = error {
                            self.errorMessage = "Error getting group ID: \(error.localizedDescription)"
                            completion(.failure(error))
                            return
                        }
                        
                        if let groupId = snapshot?.documents.first?.documentID {
                            // Update user with group ID
                            UserService.shared.updateUserGroup(groupId: groupId) { result in
                                switch result {
                                case .success:
                                    // Also update user role to Admin
                                    self.db.collection("users").document(userId).updateData([
                                        "role": "Admin"
                                    ]) { error in
                                        if let error = error {
                                            self.errorMessage = "Error assigning administrator: \(error.localizedDescription)"
                                            completion(.failure(error))
                                        } else {
                                            // Create default permissions for the new group
                                            PermissionService.shared.createDefaultPermissions(for: groupId)
                                            completion(.success(groupId))
                                        }
                                    }
                                case .failure(let error):
                                    self.errorMessage = "Error updating user: \(error.localizedDescription)"
                                    completion(.failure(error))
                                }
                            }
                        } else {
                            self.errorMessage = "Could not find created group"
                            completion(.failure(NSError(domain: "GroupNotFound", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find created group"])))
                        }
                    }
            }
        } catch {
            isLoading = false
            errorMessage = "Error creating group: \(error.localizedDescription)"
            completion(.failure(error))
        }
    }
    
    // Join an existing group by code
    func joinGroup(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = AuthService.shared.currentUserUID() else {
            errorMessage = "You must be logged in"
            completion(.failure(NSError(domain: "UserNotLoggedIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "User is not logged in"])))
            return
        }
        
        guard !groupCode.isEmpty else {
            errorMessage = "You must specify a group code"
            completion(.failure(NSError(domain: "EmptyGroupCode", code: -1, userInfo: [NSLocalizedDescriptionKey: "Group code cannot be empty"])))
            return
        }
        
        // Validate code format
        guard isValidCode else {
            errorMessage = "Invalid group code format"
            completion(.failure(NSError(domain: "InvalidGroupCode", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid group code format"])))
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Check if user already belongs to a group
        UserService.shared.fetchCurrentUser { [weak self] success in
            guard let self = self else { return }
            
            if !success {
                self.isLoading = false
                self.errorMessage = "Error fetching user data"
                completion(.failure(NSError(domain: "UserFetchError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Error fetching user data"])))
                return
            }
            
            // Check if user already has a group and is not pending
            if let currentUser = UserService.shared.currentUser,
               let existingGroupId = currentUser.groupId {
                
                // Check if user is already in this group
                self.db.collection("groups").document(existingGroupId).getDocument { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.isLoading = false
                        self.errorMessage = "Error checking current group: \(error.localizedDescription)"
                        completion(.failure(error))
                        return
                    }
                    
                    if let group = try? snapshot?.data(as: GroupModel.self) {
                        if group.code == self.groupCode {
                            // Already in this group
                            self.isLoading = false
                            self.errorMessage = "You are already a member of this group"
                            completion(.failure(NSError(domain: "AlreadyInGroup", code: -4, userInfo: [NSLocalizedDescriptionKey: "You are already a member of this group"])))
                            return
                        }
                    }
                    
                    // Continue with the join process
                    self.findAndJoinGroup(userId: userId, completion: completion)
                }
            } else {
                // No existing group, proceed with join
                self.findAndJoinGroup(userId: userId, completion: completion)
            }
        }
    }
    
    // Helper method to find and join a group
    private func findAndJoinGroup(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("groups")
            .whereField("code", isEqualTo: groupCode)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error searching for group: \(error.localizedDescription)"
                    completion(.failure(error))
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    self.errorMessage = "Group with this code not found"
                    completion(.failure(NSError(domain: "GroupNotFound", code: -1, userInfo: [NSLocalizedDescriptionKey: "Group with this code not found"])))
                    return
                }
                
                let groupId = document.documentID
                
                // Check if user is already a member or pending
                do {
                    if let group = try document.data(as: GroupModel.self) {
                        if group.members.contains(userId) {
                            self.errorMessage = "You are already a member of this group"
                            completion(.failure(NSError(domain: "AlreadyMember", code: -1, userInfo: [NSLocalizedDescriptionKey: "You are already a member of this group"])))
                            return
                        }
                        
                        if group.pendingMembers.contains(userId) {
                            self.errorMessage = "Your request to join this group is already pending"
                            completion(.failure(NSError(domain: "AlreadyPending", code: -1, userInfo: [NSLocalizedDescriptionKey: "Your request to join this group is already pending"])))
                            return
                        }
                    }
                } catch {
                    self.errorMessage = "Error processing group data: \(error.localizedDescription)"
                    completion(.failure(error))
                    return
                }
                
                // Add user to pendingMembers
                self.db.collection("groups").document(groupId).updateData([
                    "pendingMembers": FieldValue.arrayUnion([userId])
                ]) { error in
                    if let error = error {
                        self.errorMessage = "Error joining group: \(error.localizedDescription)"
                        completion(.failure(error))
                    } else {
                        self.successMessage = "Join request sent. Waiting for confirmation."
                        
                        // Update user's groupId
                        UserService.shared.updateUserGroup(groupId: groupId) { result in
                            switch result {
                            case .success:
                                completion(.success(()))
                            case .failure(let error):
                                self.errorMessage = "Error updating user: \(error.localizedDescription)"
                                completion(.failure(error))
                            }
                        }
                    }
                }
            }
    }
    
    // Load group members
    func loadGroupMembers(groupId: String) {
        isLoading = true
        
        GroupService.shared.fetchGroup(by: groupId)
        
        // Subscribe to group updates
        GroupService.shared.$group
            .receive(on: DispatchQueue.main)
            .sink { [weak self] group in
                guard let self = self, let group = group else { return }
                
                self.isLoading = false
                self.members = group.members
                self.pendingMembers = group.pendingMembers
            }
            .store(in: &cancellables)
    }
    
    // Generate a unique 6-character code
    private func generateUniqueCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ123456789"
        let length = 6
        
        var result = ""
        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<characters.count)
            let randomCharacter = characters[characters.index(characters.startIndex, offsetBy: randomIndex)]
            result.append(randomCharacter)
        }
        
        return result
    }
    
    // Helper method for error handling
    private func handleError(_ error: Error, _ message: String, _ completion: @escaping (Result<String, Error>) -> Void) {
        isLoading = false
        errorMessage = "\(message): \(error.localizedDescription)"
        completion(.failure(error))
    }
}
