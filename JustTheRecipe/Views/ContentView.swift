import SwiftUI
import SwiftData

// MARK: - Content View
// Root view that manages navigation state.

struct ContentView: View {
    
    var body: some View {
        HomeLibraryView()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(PersistenceController.preview.container)
}
// some changes to send to Git
