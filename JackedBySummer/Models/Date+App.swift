import Foundation

extension Calendar {
    /// The user's current calendar, used consistently for all day math.
    static var app: Calendar { Calendar.current }
}

extension Date {
    /// Start of this date's day in the current local time zone.
    var startOfDay: Date { Calendar.app.startOfDay(for: self) }

    /// Whole calendar days from `self` to `other` (positive if `other` is later).
    func dayCount(to other: Date) -> Int {
        let a = startOfDay
        let b = other.startOfDay
        return Calendar.app.dateComponents([.day], from: a, to: b).day ?? 0
    }

    func addingDays(_ days: Int) -> Date {
        Calendar.app.date(byAdding: .day, value: days, to: self) ?? self
    }
}

enum AppConstants {
    /// Energy per kilogram of body mass, kcal.
    static let kcalPerKg: Double = 7700
    /// Standing deficit target below TDEE for the "lean out" cut line.
    static let cutDeficit: Int = 500
}

enum AppFormat {
    static func kg(_ value: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f", value)
    }

    /// Seconds -> "m:ss".
    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()

    static let weekdayInitial: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEEE" // single-letter weekday
        return f
    }()
}
