import SwiftUI

@main
struct ZenFireBrowserApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppCrashReporter.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        AppCrashReporter.shared.markSessionActive()
                    case .background:
                        AppCrashReporter.shared.markCleanExit()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}
