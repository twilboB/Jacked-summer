import Foundation
import SwiftUI
import FoundationModels

/// Observes whether the on-device model is usable so the UI can hide AI buttons
/// and lean on manual entry when it isn't. Checked once and reused.
///
/// VERIFY against the iOS 27 SDK: `SystemLanguageModel.default.availability`
/// and the `.available` / `.unavailable(reason:)` cases.
@Observable
final class AIAvailability {
    enum Status: Equatable {
        case available
        case unavailable(String)
    }

    private(set) var status: Status = .unavailable("Checking…")

    var isAvailable: Bool {
        if case .available = status { return true }
        return false
    }

    /// A short, user-facing note describing why AI is off.
    var note: String {
        switch status {
        case .available: return ""
        case .unavailable(let reason): return reason
        }
    }

    init() {
        refresh()
    }

    func refresh() {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            status = .available
        case .unavailable(let reason):
            status = .unavailable(Self.describe(reason))
        @unknown default:
            status = .unavailable("On-device intelligence is not available on this device.")
        }
    }

    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        // VERIFY the exact reason cases against the SDK.
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence. Manual logging still works."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to enable AI estimates."
        case .modelNotReady:
            return "The on-device model is still downloading. Manual logging still works."
        @unknown default:
            return "On-device intelligence is not available right now. Manual logging still works."
        }
    }
}
