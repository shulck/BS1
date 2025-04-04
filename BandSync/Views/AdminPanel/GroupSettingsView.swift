import SwiftUI

struct GroupSettingsView: View {
    @StateObject private var groupService = GroupService.shared
    @State private var newName = ""
    @State private var showRenameConfirmation = false
    @State private var showCodeConfirmation = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var successMessage = ""
    @State private var errorMessage = ""
    @State private var isEditing = false
    
    var body: some View {
        ZStack {
            Form {
                // Group name
                Section(header: Text("Group name")) {
                    if isEditing {
                        TextField("Group name", text: $newName)
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                        
                        HStack {
                            Button("Cancel") {
                                isEditing = false
                                loadGroupName()
                            }
                            .foregroundColor(.red)
                            
                            Spacer()
                            
                            Button("Save") {
                                updateGroupName()
                            }
                            .disabled(newName.isEmpty || newName == groupService.group?.name || groupService.isLoading)
                            .foregroundColor(.blue)
                        }
                    } else {
                        HStack {
                            Text(groupService.group?.name ?? "Loading...")
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button(action: {
                                isEditing = true
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // Invitation code
                if let group = groupService.group {
                    Section(header: Text("Invitation code")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Share this code with others to invite them to join your group.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text(group.code)
                                    .font(.system(.title3, design: .monospaced))
                                    .bold()
                                
                                Spacer()
                                
                                Button {
                                    UIPasteboard.general.string = group.code
                                    showCopiedAlert()
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                            
                            Button("Generate new code") {
                                showCodeConfirmation = true
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                // Group statistics
                Section(header: Text("Group statistics")) {
                    Label("Total members: \(groupService.groupMembers.count)", systemImage: "person.3")
                    
                    let adminCount = groupService.groupMembers.filter { $0.role == .admin }.count
                    Label("Administrators: \(adminCount)", systemImage: "person.fill.checkmark")
                    
                    let pendingCount = groupService.pendingMembers.count
                    if pendingCount > 0 {
                        NavigationLink {
                            UsersListView()
                        } label: {
                            Label("Pending approvals: \(pendingCount)", systemImage: "person.badge.clock")
                                .foregroundColor(pendingCount > 0 ? .blue : .primary)
                        }
                    } else {
                        Label("Pending approvals: 0", systemImage: "person.badge.clock")
                    }
                }
                
                // More actions
                Section(header: Text("More options")) {
                    NavigationLink(destination: UsersListView()) {
                        Label("Manage members", systemImage: "person.3")
                    }
                    
                    NavigationLink(destination: PermissionsView()) {
                        Label("Manage permissions", systemImage: "lock.shield")
                    }
                }
                
                // Display error
                if let error = groupService.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Group settings")
            .onAppear {
                loadGroupData()
            }
            .alert("Rename group?", isPresented: $showRenameConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    confirmUpdateGroupName()
                }
            } message: {
                Text("Are you sure you want to rename this group to '\(newName)'?")
            }
            .alert("Generate new code?", isPresented: $showCodeConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Generate") {
                    regenerateCode()
                }
            } message: {
                Text("The old code will no longer be valid. All members who haven't joined yet will need to use the new code.")
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(successMessage)
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .refreshable {
                loadGroupData()
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
    
    // Load group data
    private func loadGroupData() {
        if let groupId = AppState.shared.user?.groupId {
            groupService.fetchGroup(by: groupId)
            loadGroupName()
        }
    }
    
    // Load group name
    private func loadGroupName() {
        newName = groupService.group?.name ?? ""
    }
    
    // Update group name
    private func updateGroupName() {
        // Validate name
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            showError("Group name cannot be empty")
            return
        }
        
        // Show confirmation
        showRenameConfirmation = true
    }
    
    // Confirm group name update
    private func confirmUpdateGroupName() {
        groupService.updateGroupName(newName)
        
        // Check for success
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if groupService.errorMessage == nil {
                isEditing = false
                showSuccess("Group renamed successfully")
            } else {
                showError(groupService.errorMessage ?? "Unknown error")
            }
        }
    }
    
    // Regenerate invitation code
    private func regenerateCode() {
        groupService.regenerateCode()
        
        // Check for success
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if groupService.errorMessage == nil {
                showSuccess("New invitation code generated successfully")
            } else {
                showError(groupService.errorMessage ?? "Unknown error")
            }
        }
    }
    
    // Show copied confirmation
    private func showCopiedAlert() {
        showSuccess("Invitation code copied to clipboard")
    }
    
    // Show success message
    private func showSuccess(_ message: String) {
        successMessage = message
        showSuccessAlert = true
    }
    
    // Show error message
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
}
