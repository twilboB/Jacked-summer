import Foundation

enum Stats {

    // MARK: - Kettlebell streaks (calendar-day based)

    /// Current streak in days. Walk back from today; if today isn't logged start
    /// from yesterday. If yesterday isn't logged either, the streak is zero.
    static func currentStreak(loggedDays: Set<Date>, today: Date = Date()) -> Int {
        let start = today.startOfDay
        var cursor: Date
        if loggedDays.contains(start) {
            cursor = start
        } else {
            let yesterday = start.addingDays(-1)
            guard loggedDays.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while loggedDays.contains(cursor) {
            count += 1
            cursor = cursor.addingDays(-1)
        }
        return count
    }

    /// Longest run of consecutive logged calendar days across all history.
    static func longestStreak(loggedDays: Set<Date>) -> Int {
        guard !loggedDays.isEmpty else { return 0 }
        let sorted = loggedDays.sorted()
        var best = 1
        var run = 1
        for i in 1..<sorted.count {
            if sorted[i - 1].addingDays(1) == sorted[i] {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }
        return best
    }

    /// Rolling seven-day window (oldest first) of whether each day was logged.
    static func lastSevenDays(loggedDays: Set<Date>, today: Date = Date()) -> [Bool] {
        let start = today.startOfDay
        return (0..<7).reversed().map { offset in
            loggedDays.contains(start.addingDays(-offset))
        }
    }

    static func lastSevenLabels(today: Date = Date()) -> [String] {
        let start = today.startOfDay
        return (0..<7).reversed().map { offset in
            AppFormat.weekdayInitial.string(from: start.addingDays(-offset))
        }
    }

    // MARK: - Lift volume

    /// Volume for a single set (weight × reps), 0 when either is missing.
    static func setVolume(weightKg: Double?, reps: Int?) -> Double {
        guard let w = weightKg, let r = reps else { return 0 }
        return w * Double(r)
    }

    static func volume(of records: [GymSetRecord]) -> Double {
        records.reduce(0) { $0 + setVolume(weightKg: $1.weightKg, reps: $1.reps) }
    }

    // MARK: - Food aggregation

    struct DayTotals {
        var kcal: Int = 0
        var protein: Int = 0
        var carbs: Int = 0
        var fat: Int = 0
    }

    static func totals(of entries: [FoodEntryRecord]) -> DayTotals {
        entries.reduce(into: DayTotals()) { acc, e in
            acc.kcal += e.kcal
            acc.protein += e.protein
            acc.carbs += e.carbs
            acc.fat += e.fat
        }
    }
}
