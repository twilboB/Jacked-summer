import Foundation
import FoundationModels

/// Compact, structured snapshot of the whole app, fed to the coach as JSON.
struct CoachSummary: Codable {
    struct KeyLift: Codable {
        var name: String
        var topSetKg: Double
        var reps: Int
        var weekOverWeekWeightChangeKg: Double
    }
    struct WeighIn: Codable {
        var date: String
        var kg: Double
    }

    // Targets
    var goalWeightKg: Double
    var tdee: Int

    // Body / forecast
    var trendWeightNowKg: Double
    var scaleWeeklyRateKg: Double
    var forecastState: String
    var forecastCentralDate: String?
    var forecastSoonerDate: String?
    var forecastLaterDate: String?

    // Calories
    var calorieAvg: Int?
    var deficit: Int?
    var deficitImpliedWeeklyRateKg: Double?

    var recentWeighIns: [WeighIn]

    // Lifting
    var currentWeek: Int
    var totalVolumeThisWeekKg: Double
    var totalVolumeLastWeekKg: Double
    var keyLifts: [KeyLift]

    // Kettlebell
    var kbCurrentStreak: Int
    var kbLongestStreak: Int
    var kbTotalSessions: Int
    var kbSessionsLast7: Int
    var kbMaxUnbrokenSwings: Int?
    var kbBestComplexTimeSec: Int?

    func jsonString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }
}

/// Produces a short, blunt, realistic coaching read from the combined data.
///
/// VERIFY against the iOS 27 SDK: plain-text `session.respond(to:)` and
/// `PrivateCloudComputeLanguageModel`.
enum CoachService {

    static let instructions = """
    You are a sharp, encouraging but realistic strength and physique coach \
    reading an athlete's cut data. Write three to four short sentences, ninety \
    words maximum. Open with a genuine specific win from the data, for example a \
    lift that went up, a live streak, or a clean downward trend. Then reconcile \
    the scale trend against what the calorie deficit implies if both are present, \
    naming the likely reason for any gap such as water retention or soft calorie \
    estimates. Then give one or two concrete nudges tied to the actual numbers. \
    Motivating but never hype or empty flattery. If something is slipping, say so \
    plainly. Holding onto muscle is the priority. Plain direct Australian English. \
    No emojis, no bullet points, no headings. Never invent numbers beyond those provided.
    """

    /// On-device coach read (default).
    static func read(summary: CoachSummary) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: summary.jsonString())
        return response.content
    }

    /// Opt-in deeper weekly review via Private Cloud Compute (network, larger context).
    static func deepReview(summary: CoachSummary) async throws -> String {
        let session = LanguageModelSession(
            model: PrivateCloudComputeLanguageModel(),
            instructions: instructions
        )
        let response = try await session.respond(to: summary.jsonString())
        return response.content
    }
}
