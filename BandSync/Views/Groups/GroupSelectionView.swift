import SwiftUI

struct GroupSelectionView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = GroupViewModel()
    @State private var showCreateGroup = false
    @State private var showJoinGroup = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                Image(systemName: "music.mic")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .padding()
                
                Text("Welcome to BandSync!")
                    .font(.title.bold())
                
                Text("To get started, create a new group or join an existing one")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 15) {
                    Button(action: {
                        showCreateGroup = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Create new group")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        showJoinGroup = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Join a group")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                Button("Log out") {
                    appState.logout()
                }
                .padding(.bottom, 20)
            }
            .padding()
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView(onCompletion: { result in
                    switch result {
                    case .success:
                        // Successfully created group, refresh app state
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            appState.refreshAuthState()
                        }
                    case .failure(let error):
                        // Show error alert
                        errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                })
            }
            .sheet(isPresented: $showJoinGroup) {
                JoinGroupView(onCompletion: { result in
                    switch result {
                    case .success:
                        // Successfully joined group, refresh app state
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            appState.refreshAuthState()
                        }
                    case .failure(let error):
                        // Show error alert
                        errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                })
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            
            // Loading overlay
            if viewModel.isLoading {
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
        .onAppear {
            // Set loading state
            viewModel.isLoading = false
        }
    }
}
