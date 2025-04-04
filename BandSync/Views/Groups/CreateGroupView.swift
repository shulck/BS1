import SwiftUI

struct CreateGroupView: View {
    @StateObject private var viewModel = GroupViewModel()
    @Environment(\.dismiss) var dismiss
    
    // Completion handler to inform parent view of result
    var onCompletion: ((Result<Void, Error>) -> Void)?
    
    init(onCompletion: ((Result<Void, Error>) -> Void)? = nil) {
        self.onCompletion = onCompletion
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Group information")) {
                    TextField("Group name", text: $viewModel.groupName)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                }
                
                Section {
                    Button("Create group") {
                        createGroup()
                    }
                    .disabled(viewModel.groupName.isEmpty || viewModel.isLoading)
                }
                
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                if let success = viewModel.successMessage {
                    Section {
                        Text(success)
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Create group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $viewModel.showSuccessAlert) {
                Alert(
                    title: Text("Success"),
                    message: Text("Group created successfully! You are now the admin of this group."),
                    dismissButton: .default(Text("OK")) {
                        dismiss()
                        onCompletion?(.success(()))
                    }
                )
            }
        }
    }
    
    private func createGroup() {
        viewModel.createGroup { result in
            switch result {
            case .success:
                // Update UI state
                viewModel.showSuccessAlert = true
                
                // Notify parent view if needed (will be called when alert is dismissed)
                // onCompletion?(.success(()))
            case .failure(let error):
                // Notify parent view
                onCompletion?(.failure(error))
            }
        }
    }
}
