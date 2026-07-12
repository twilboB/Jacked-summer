import Foundation
import SwiftData

// MARK: - Persistence models
//
// All dates are normalised to start-of-day in the user's local time zone before
// they are stored. See `Date+App.swift` for the `startOfDay` helper used at the
// call sites that create these records.

/// One logged set of one exercise in a given training week.
@Model
final class GymSetRecord {
    /// Training week number (monotonic, user-facing "Week N").
    var week: Int
    /// Stable identifier of the exercise (see `LiftContent`).
    var exerciseId: String
    /// Zero-based index of the set within the exercise for that week.
    var setIndex: Int
    var weightKg: Double?
    var reps: Int?

    init(week: Int, exerciseId: String, setIndex: Int, weightKg: Double? = nil, reps: Int? = nil) {
        self.week = week
        self.exerciseId = exerciseId
        self.setIndex = setIndex
        self.weightKg = weightKg
        self.reps = reps
    }
}

/// One logged kettlebell session on a given calendar day.
@Model
final class KbLogRecord {
    /// Start-of-day date the session was logged for.
    var date: Date
    /// Which of the seven plan days this was (1...7).
    var dayNumber: Int
    /// Benchmark value: swing reps for day 1, complex time in seconds for day 4.
    var benchmarkValue: Double?

    init(date: Date, dayNumber: Int, benchmarkValue: Double? = nil) {
        self.date = date
        self.dayNumber = dayNumber
        self.benchmarkValue = benchmarkValue
    }
}

/// A single food entry contributing to a day's calorie and macro totals.
@Model
final class FoodEntryRecord {
    /// Start-of-day date the entry counts against.
    var date: Date
    var name: String
    var kcal: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var note: String
    /// "low", "med", "high", or "" when not AI-sourced.
    var confidence: String
    /// One of `FoodSource` raw values: text, photo, barcode, label, manual.
    var source: String
    var createdAt: Date

    init(
        date: Date,
        name: String,
        kcal: Int,
        protein: Int,
        carbs: Int,
        fat: Int,
        note: String = "",
        confidence: String = "",
        source: String = FoodSource.manual.rawValue,
        createdAt: Date
    ) {
        self.date = date
        self.name = name
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.note = note
        self.confidence = confidence
        self.source = source
        self.createdAt = createdAt
    }
}

/// One bodyweight reading. At most one per calendar day; re-logging updates it.
@Model
final class WeightEntryRecord {
    /// Start-of-day date, unique per day (enforced in the logging code).
    var date: Date
    var kg: Double

    init(date: Date, kg: Double) {
        self.date = date
        self.kg = kg
    }
}

/// Singleton-style user settings. Exactly one row is created on first launch.
@Model
final class AppSettings {
    var tdee: Int
    var proteinTargetG: Int
    var goalWeightKg: Double

    init(tdee: Int = 2800, proteinTargetG: Int = 175, goalWeightKg: Double = 82) {
        self.tdee = tdee
        self.proteinTargetG = proteinTargetG
        self.goalWeightKg = goalWeightKg
    }
}

// MARK: - Supporting enums

/// Where a food entry's numbers came from. Stored as the raw string on the record.
enum FoodSource: String, CaseIterable {
    case text
    case photo
    case barcode
    case label
    case manual

    var symbolName: String {
        switch self {
        case .text: return "text.alignleft"
        case .photo: return "camera.fill"
        case .barcode: return "barcode.viewfinder"
        case .label: return "doc.text.viewfinder"
        case .manual: return "pencil"
        }
    }

    var showsMarker: Bool {
        switch self {
        case .photo, .barcode, .label: return true
        case .text, .manual: return false
        }
    }
}

enum Confidence: String, CaseIterable {
    case low, med, high

    var label: String {
        switch self {
        case .low: return "Low"
        case .med: return "Med"
        case .high: return "High"
        }
    }
}
