import SwiftUI

@main
struct VolcVeinApp: App {
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.managedObjectContext, persistence.viewContext)
                .preferredColorScheme(.dark)
        }
    }
}
