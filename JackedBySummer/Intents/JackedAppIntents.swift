import AppIntents
import SwiftData
import Foundation
import FoundationModels

// App Intents expose the core "log in a couple of taps" actions to Siri,
// Spotlight, Shortcuts, and the new Apple-Intelligence Siri. Each intent writes
// to the SAME store the app uses (SharedStore.container) so voice logging and
// in-app logging stay consistent.
//
// VERIFY against the iOS 27 SDK: the App Intents surface is stable since iOS 16,
// but confirm AppShortcut phrase syntax and any Apple-Intelligence "assistant
// schema" opt-ins if you later adopt @AssistantIntent for richer Siri context.

// MARK: - Errors

enum JBSIntentError: Error, CustomLocalizedStringResourceConvertible {
    case aiUnavailable
    case badValue

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .aiUnavailable:
            return "On-device intelligence isn't available on this device, so I can't estimate food by description. Open Jacked by Summer to log it manually."
        case .badValue:
            return "That value didn't look right. Try again."
        }
    }
}

// MARK: - Shared helpers

@MainActor
enum IntentSupport {
    struct DayCalories { var consumed: Int; var tdee: Int; var left: Int; var cutLeft: Int }

    static func caloriesToday() -> DayCalories {
        let ctx = SharedStore.container.mainContext
        let today = Date().startOfDay
        let descriptor = FetchDescriptor<FoodEntryRecord>(predicate: #Predicate { $0.date == today })
        let entries = (try? ctx.fetch(descriptor)) ?? []
        let consumed = entries.reduce(0) { $0 + $1.kcal }
        let settings = SettingsStore.current(ctx)
        let cutLine = settings.tdee - AppConstants.cutDeficit
        return DayCalories(
            consumed: consumed,
            tdee: settings.tdee,
            left: settings.tdee - consumed,
            cutLeft: cutLine - consumed
        )
    }

    static func kettlebellLoggedDays() -> Set<Date> {
        let ctx = SharedStore.container.mainContext
        let all = (try? ctx.fetch(FetchDescriptor<KbLogRecord>())) ?? []
        return Set(all.map { $0.date.startOfDay })
    }
}

// MARK: - Kettlebell day enum (for the Log Kettlebell intent)

enum KbDayChoice: Int, AppEnum {
    case day1 = 1, day2, day3, day4, day5, day6, day7

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Kettlebell Day")

    static let caseDisplayRepresentations: [KbDayChoice: DisplayRepresentation] = [
        .day1: "Day 1 — Swing EMOM Ladder",
        .day2: "Day 2 — Gym A + KB Press & Core",
        .day3: "Day 3 — Halo + Press Density",
        .day4: "Day 4 — Complex Chipper",
        .day5: "Day 5 — Gym B + KB Push, Pull & Core",
        .day6: "Day 6 — Snatch & Squat Intervals",
        .day7: "Day 7 — Grind & Core Strength",
    ]
}

// MARK: - Log bodyweight

struct LogWeightIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Bodyweight"
    static let description = IntentDescription("Record today's bodyweight in Jacked by Summer.")
    static let openAppWhenRun = false

    @Parameter(title: "Weight (kg)")
    var weightKg: Double

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard weightKg > 0 else { throw JBSIntentError.badValue }
        let ctx = SharedStore.container.mainContext
        let today = Date().startOfDay
        let descriptor = FetchDescriptor<WeightEntryRecord>(predicate: #Predicate { $0.date == today })
        if let existing = try ctx.fetch(descriptor).first {
            existing.kg = weightKg
        } else {
            ctx.insert(WeightEntryRecord(date: today, kg: weightKg))
        }
        try ctx.save()
        return .result(dialog: "Logged \(AppFormat.kg(weightKg)) kilograms for today.")
    }
}

// MARK: - Log a kettlebell session

struct LogKettlebellIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Kettlebell Session"
    static let description = IntentDescription("Mark today's kettlebell session done and keep the streak alive.")
    static let openAppWhenRun = false

    @Parameter(title: "Which day")
    var day: KbDayChoice

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ctx = SharedStore.container.mainContext
        let today = Date().startOfDay
        // One session per calendar day: update today's record or insert a new one.
        let descriptor = FetchDescriptor<KbLogRecord>(predicate: #Predicate { $0.date == today })
        if let existing = try ctx.fetch(descriptor).first {
            existing.dayNumber = day.rawValue
        } else {
            ctx.insert(KbLogRecord(date: today, dayNumber: day.rawValue))
        }
        try ctx.save()

        let streak = Stats.currentStreak(loggedDays: IntentSupport.kettlebellLoggedDays())
        let flame = streak > 0 ? " Streak: \(streak) day\(streak == 1 ? "" : "s")." : ""
        return .result(dialog: "Logged today's kettlebell session.\(flame)")
    }
}

// MARK: - Log food by description (on-device estimate)

struct LogFoodByDescriptionIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Food by Description"
    static let description = IntentDescription("Describe what you ate and log an on-device nutrition estimate.")
    static let openAppWhenRun = false

    @Parameter(title: "What did you eat?")
    var foodDescription: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // The estimate needs Apple Intelligence; fail clearly if unavailable.
        guard case .available = SystemLanguageModel.default.availability else {
            throw JBSIntentError.aiUnavailable
        }
        let estimate = try await NutritionEstimator.estimate(text: foodDescription)

        let ctx = SharedStore.container.mainContext
        let entry = estimate.makeEntry(date: Date().startOfDay, source: .text, now: Date())
        ctx.insert(entry)
        try ctx.save()

        let left = IntentSupport.caloriesToday().left
        return .result(dialog: "Logged \(estimate.name), about \(estimate.calories) calories. You have \(left) calories left today.")
    }
}

// MARK: - Log calories manually (no AI needed)

struct LogCaloriesIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Calories"
    static let description = IntentDescription("Quickly log calories, and optionally protein, in Jacked by Summer.")
    static let openAppWhenRun = false

    @Parameter(title: "Calories")
    var calories: Int

    @Parameter(title: "Protein (g)")
    var protein: Int?

    @Parameter(title: "Name")
    var name: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard calories >= 0 else { throw JBSIntentError.badValue }
        let ctx = SharedStore.container.mainContext
        let entry = FoodEntryRecord(
            date: Date().startOfDay,
            name: (name?.isEmpty == false ? name! : "Quick add"),
            kcal: calories,
            protein: protein ?? 0,
            carbs: 0,
            fat: 0,
            source: FoodSource.manual.rawValue,
            createdAt: Date()
        )
        ctx.insert(entry)
        try ctx.save()

        let left = IntentSupport.caloriesToday().left
        return .result(dialog: "Logged \(calories) calories. You have \(left) left today.")
    }
}

// MARK: - Query: calories left today

struct CaloriesLeftIntent: AppIntent {
    static let title: LocalizedStringResource = "Calories Left Today"
    static let description = IntentDescription("Ask how many calories you have left today.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let c = IntentSupport.caloriesToday()
        let cutLine = "To stay in your cut you have \(max(0, c.cutLeft)) left."
        return .result(dialog: "You've had \(c.consumed) of \(c.tdee) calories. \(c.left) left to maintenance. \(cutLine)")
    }
}

// MARK: - Query: kettlebell streak

struct KettlebellStreakIntent: AppIntent {
    static let title: LocalizedStringResource = "Kettlebell Streak"
    static let description = IntentDescription("Ask about your current kettlebell streak.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let days = IntentSupport.kettlebellLoggedDays()
        let current = Stats.currentStreak(loggedDays: days)
        let best = Stats.longestStreak(loggedDays: days)
        if current == 0 {
            return .result(dialog: "Your streak is cold. Log a session today to start it again. Best ever: \(best) days.")
        }
        return .result(dialog: "Your kettlebell streak is \(current) day\(current == 1 ? "" : "s"). Best ever: \(best).")
    }
}

// MARK: - App Shortcuts (auto-offered to Siri / Spotlight / the new Siri)

struct JackedShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWeightIntent(),
            phrases: [
                "Log my weight in \(.applicationName)",
                "Record my bodyweight in \(.applicationName)",
            ],
            shortTitle: "Log Weight",
            systemImageName: "scalemass"
        )
        AppShortcut(
            intent: LogKettlebellIntent(),
            phrases: [
                "Log a kettlebell session in \(.applicationName)",
                "I did my kettlebells in \(.applicationName)",
            ],
            shortTitle: "Log Kettlebell",
            systemImageName: "flame.fill"
        )
        AppShortcut(
            intent: LogFoodByDescriptionIntent(),
            phrases: [
                "Log food in \(.applicationName)",
                "Estimate a meal in \(.applicationName)",
            ],
            shortTitle: "Log Food",
            systemImageName: "fork.knife"
        )
        AppShortcut(
            intent: LogCaloriesIntent(),
            phrases: [
                "Log calories in \(.applicationName)",
                "Quick add calories in \(.applicationName)",
            ],
            shortTitle: "Log Calories",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: CaloriesLeftIntent(),
            phrases: [
                "How many calories do I have left in \(.applicationName)",
                "Calories left in \(.applicationName)",
            ],
            shortTitle: "Calories Left",
            systemImageName: "gauge.with.dots.needle.33percent"
        )
        AppShortcut(
            intent: KettlebellStreakIntent(),
            phrases: [
                "What's my streak in \(.applicationName)",
                "Kettlebell streak in \(.applicationName)",
            ],
            shortTitle: "Streak",
            systemImageName: "flame"
        )
    }
}
