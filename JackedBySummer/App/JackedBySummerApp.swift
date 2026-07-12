import SwiftUI
import SwiftData

@main
struct JackedBySummerApp: App {
    /// Shared availability check for the on-device model.
    @State private var ai = AIAvailability()

    /// Shared with the App Intents (Siri) so both read/write the same store.
    private let container = SharedStore.container

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(ai)
                .tint(Palette.molten)        // molten identity on controls
                .preferredColorScheme(.dark) // run in dark appearance
        }
        .modelContainer(container)
    }
}
