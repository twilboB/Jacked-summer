import Foundation
import SwiftData

/// A single shared `ModelContainer` used by both the SwiftUI app and the App
/// Intents. Siri can run an intent while the app is backgrounded or not running,
/// so both paths must read and write the same on-disk store.
///
/// `ModelContainer` is `Sendable`, so a static constant is safe under Swift 6.
enum SharedStore {
    static let container: ModelContainer = {
        // UI tests pass `-uiTestingResetState YES` to start from a clean,
        // in-memory store so assertions are deterministic.
        let uiTesting = ProcessInfo.processInfo.arguments.contains("-uiTestingResetState")
        do {
            return try ModelContainer(
                for: GymSetRecord.self,
                KbLogRecord.self,
                FoodEntryRecord.self,
                WeightEntryRecord.self,
                AppSettings.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: uiTesting)
            )
        } catch {
            fatalError("Failed to create shared ModelContainer: \(error)")
        }
    }()
}
