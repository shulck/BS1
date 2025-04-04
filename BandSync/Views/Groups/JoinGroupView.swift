import SwiftUI

struct JoinGroupView: View {
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
                Section(header: Text("Group code")) {
                    TextField("Enter invitation code", text: $viewModel.groupCode)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .onChange(of: viewModel.groupCode) { newValue in
                            // Format and validate code
                            viewModel.groupCode = newValue.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                }
                
                if !viewModel.isValidCode && !viewModel.groupCode.isEmpty {
                    Text("Group code should be 6 characters")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                Section {
                    Button("Join") {
                        joinGroup()
                    }
                    .disabled(!isJoinEnabled || viewModel.isLoading)
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
            .navigationTitle("Join group")
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
                    message: Text("Join request sent successfully! Waiting for approval."),
                    dismissButton: .default(Text("OK")) {
                        dismiss()
                        onCompletion?(.success(()))
                    }
                )
            }
        }
    }
    
    // Enable join button only for valid codes
    private var isJoinEnabled: Bool {
        return viewModel.isValidCode && !viewModel.groupCode.isEmpty
    }
    
    private func joinGroup() {
        viewModel.joinGroup { result in
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
