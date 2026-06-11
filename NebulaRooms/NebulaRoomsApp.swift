import SwiftUI

@main
struct NebulaRoomsApp: App {
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
