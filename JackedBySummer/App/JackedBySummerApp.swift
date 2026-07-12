import SwiftUI
import SwiftData

@main
struct JackedBySummerApp: App {
    /// Shared availability check for the on-device model.
    @State private var ai = AIAvailability()

    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: GymSetRecord.self,
                KbLogRecord.self,
                FoodEntryRecord.self,
                WeightEntryRecord.self,
                AppSettings.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

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
