import SwiftUI
import FirebaseFirestore

struct UsersListView: View {
    @StateObject private var groupService = GroupService.shared
    @State private var showingRoleView = false
    @State private var selectedUserId = ""
    @State private var selectedUser: UserModel?
    @State private var showingDeleteConfirmation = false
    @State private var userToDelete: UserModel? = nil
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isRefreshing = false
    
    var body: some View {
        ZStack {
            List {
                if !groupService.groupMembers.isEmpty {
                    Section(header: Text("Members")) {
                        ForEach(groupService.groupMembers) { user in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.name)
                                        .font(.headline)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    HStack {
                                        Text("Role: \(user.role.rawValue)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        // Show "You" badge for current user
                                        if user.id == AppState.shared.user?.id {
                                            Text("You")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue)
                                                .foregroundColor(.white)
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                // Action buttons
                                if user.id != AppState.shared.user?.id {
                                    Menu {
                                        Button("Change role") {
                                            selectedUserId = user.id
                                            selectedUser = user
                                            showingRoleView = true
                                        }
                                        
                                        Button("Remove from group", role: .destructive) {
                                            userToDelete = user
                                            showingDeleteConfirmation = true
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // Pending approvals
                if !groupService.pendingMembers.isEmpty {
                    Section(header: Text("Awaiting approval")) {
                        ForEach(groupService.pendingMembers) { user in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.name)
                                        .font(.headline)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Accept/reject buttons
                                HStack(spacing: 12) {
                                    Button {
                                        approveUser(userId: user.id)
                                    } label: {
                                        Text("Accept")
                                            .foregroundColor(.green)
                                    }
                                    
                                    Button {
                                        rejectUser(userId: user.id)
                                    } label: {
                                        Text("Decline")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // Invitation code section
                if let group = groupService.group {
                    Section(header: Text("Invitation code")) {
                        HStack {
                            Text(group.code)
                                .font(.system(.title3, design: .monospaced))
                                .bold()
                            
                            Spacer()
                            
                            Button {
                                UIPasteboard.general.string = group.code
                                showCopyAlert()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Button("Generate new code") {
                            regenerateCode()
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // Error message
                if let error = groupService.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                // Empty state
                if groupService.groupMembers.isEmpty && groupService.pendingMembers.isEmpty {
                    Section {
                        Text("No members in this group yet. Share your invitation code to invite people to join.")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
            }
            .navigationTitle("Group members")
            .onAppear {
                loadGroupData()
            }
            .sheet(isPresented: $showingRoleView) {
                RoleSelectionView(user: selectedUser)
            }
            .alert(isPresented: $showingDeleteConfirmation) {
                Alert(
                    title: Text("Remove member?"),
                    message: Text("Are you sure you want to remove \(userToDelete?.name ?? "this user") from the group? They will need a new invitation to rejoin."),
                    primaryButton: .destructive(Text("Remove")) {
                        if let user = userToDelete {
                            removeUser(userId: user.id)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .refreshable {
                isRefreshing = true
                loadGroupData()
                // Set a timeout for the refreshing state
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isRefreshing = false
                }
            }
            
            // Loading overlay
            if groupService.isLoading || isRefreshing {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                    )
            }
        }
    }
    
    // Load group data
    private func loadGroupData() {
        if let groupId = AppState.shared.user?.groupId {
            groupService.fetchGroup(by: groupId)
        }
    }
    
    // Approve user
    private func approveUser(userId: String) {
        groupService.approveUser(userId: userId)
    }
    
    // Reject user
    private func rejectUser(userId: String) {
        groupService.rejectUser(userId: userId)
    }
    
    // Remove user
    private func removeUser(userId: String) {
        groupService.removeUser(userId: userId)
    }
    
    // Regenerate invitation code
    private func regenerateCode() {
        groupService.regenerateCode()
        
        // Show confirmation after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if groupService.errorMessage == nil {
                showAlert(title: "Success", message: "A new invitation code has been generated.")
            }
        }
    }
    
    // Show copy confirmation
    private func showCopyAlert() {
        showAlert(title: "Copied", message: "Invitation code copied to clipboard")
    }
    
    // Helper to show a simple alert
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// Role selection view
struct RoleSelectionView: View {
    var user: UserModel?
    @StateObject private var groupService = GroupService.shared
    @State private var selectedRole: UserModel.UserRole = .member
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    if let user = user {
                        Section(header: Text("User information")) {
                            Text("Name: \(user.name)")
                            Text("Email: \(user.email)")
                            Text("Current role: \(user.role.rawValue)")
                        }
                    }
                    
                    Section(header: Text("Select new role")) {
                        ForEach(UserModel.UserRole.allCases, id: \.self) { role in
                            Button {
                                selectedRole = role
                            } label: {
                                HStack {
                                    Text(role.rawValue)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedRole == role {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    
                    Section {
                        Button("Save") {
                            updateRole()
                        }
                        .disabled(user?.role == selectedRole || groupService.isLoading)
                    }
                    
                    // Role descriptions
                    Section(header: Text("Role descriptions")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Admin: Full access to all features, including group management")
                                .font(.caption)
                            
                            Text("Manager: Access to most features except admin panel")
                                .font(.caption)
                            
                            Text("Musician: Access to rehearsals, setlists, and basic features")
                                .font(.caption)
                            
                            Text("Member: Basic access to view content only")
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if let error = groupService.errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }
                .navigationTitle("Change role")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text(alertTitle),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK")) {
                            if alertTitle == "Success" {
                                dismiss()
                            }
                        }
                    )
                }
                .onAppear {
                    if let user = user {
                        selectedRole = user.role
                    }
                }
                
                // Loading overlay
                if groupService.isLoading {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(10)
                        )
                }
            }
        }
    }
    
    // Update user role
    private func updateRole() {
        guard let userId = user?.id else { return }
        
        groupService.changeUserRole(userId: userId, newRole: selectedRole)
        
        // Show confirmation after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let error = groupService.errorMessage {
                showAlert(title: "Error", message: error)
            } else {
                showAlert(title: "Success", message: "Role updated successfully")
            }
        }
    }
    
    // Helper to show a simple alert
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
