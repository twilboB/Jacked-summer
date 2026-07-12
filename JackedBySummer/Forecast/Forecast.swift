import Foundation

/// Deterministic bodyweight forecast. The language model never does this
/// arithmetic — it only comments on the result. Reproduced from the brief §10.
enum Forecast {

    enum State: String {
        case noData
        case hit
        case stalled
        case slow
        case ok
    }

    struct Result {
        var state: State
        /// Denoised (EMA) current weight — also the projection start.
        var trendWeightNow: Double
        /// Scale-trend rate, kg/week (slope × 7).
        var weeklyRate: Double
        /// trendWeightNow − goal.
        var toGoal: Double
        var centralDate: Date?
        var soonerDate: Date?
        var laterDate: Date?
        /// Whole weeks until the central date (nil unless a date exists).
        var weeksAway: Int?
        /// Calorie-deficit implied rate, kg/week (nil when too few calorie days).
        var deficitImpliedWeeklyRate: Double?
        var deficit: Int?
        var calorieAvg: Int?
    }

    struct WeightPoint {
        let date: Date
        let kg: Double
    }

    /// Tuning constants from the brief.
    private static let emaAlpha = 0.3
    private static let tau = 21.0            // days
    private static let hitThreshold = 0.15   // kg
    private static let flatWeekly = 0.05     // kg/week considered "flat"
    private static let slowDaysLimit = 900.0
    private static let rateFloorPerDay = 0.0007   // ~0.005 kg/week floor
    private static let maxProjectionDays = 3650.0  // cap "later" date

    /// - Parameters:
    ///   - weights: ascending by date.
    ///   - goal: goal weight, kg.
    ///   - calorieDaysLast21: (date, kcal) for days with food logged in the last 21 days.
    ///   - tdee: maintenance calories.
    static func compute(
        weights: [WeightPoint],
        goal: Double,
        calorieDaysLast21: [(date: Date, kcal: Int)],
        tdee: Int,
        today: Date = Date()
    ) -> Result {
        // 1. Need at least two entries.
        guard weights.count >= 2 else {
            return Result(state: .noData, trendWeightNow: weights.last?.kg ?? 0,
                          weeklyRate: 0, toGoal: 0)
        }

        let sorted = weights.sorted { $0.date < $1.date }
        let first = sorted.first!.date.startOfDay

        // 2. t_i in days since first entry; span = t of last.
        let ts = sorted.map { Double(first.dayCount(to: $0.date.startOfDay)) }
        let span = ts.last!
        guard span > 0 else {
            return Result(state: .noData, trendWeightNow: sorted.last!.kg,
                          weeklyRate: 0, toGoal: 0)
        }

        // 3. EMA (alpha 0.3) → trend weight now.
        var ema = sorted.first!.kg
        for p in sorted.dropFirst() {
            ema = emaAlpha * p.kg + (1 - emaAlpha) * ema
        }
        let trendNow = ema

        // 4. Recency-weighted least squares on raw points.
        let ws = ts.map { exp(-(span - $0) / tau) }
        let ys = sorted.map { $0.kg }
        let n = sorted.count

        var Sw = 0.0, Swx = 0.0, Swy = 0.0, Swxx = 0.0, Swxy = 0.0
        for i in 0..<n {
            let w = ws[i], x = ts[i], y = ys[i]
            Sw += w
            Swx += w * x
            Swy += w * y
            Swxx += w * x * x
            Swxy += w * x * y
        }
        let denom = Sw * Swxx - Swx * Swx
        let b = denom != 0 ? (Sw * Swxy - Swx * Swy) / denom : 0        // kg/day
        let a = Sw != 0 ? (Swy - b * Swx) / Sw : trendNow

        // 5. Weighted residual variance → standard error of slope.
        var wrss = 0.0
        for i in 0..<n {
            let r = ys[i] - (a + b * ts[i])
            wrss += ws[i] * r * r
        }
        let sigma2 = n > 2 ? wrss / Double(n - 2) : wrss
        let varB = denom != 0 ? sigma2 * Sw / denom : 0
        let seB = sqrt(max(0, varB))                                    // kg/day

        // 6. Weekly rate.
        let weeklyRate = b * 7

        // 7. To goal.
        let toGoal = trendNow - goal

        // 8. Calorie cross-check (needs at least four days with entries).
        var deficit: Int? = nil
        var calorieAvg: Int? = nil
        var impliedWeekly: Double? = nil
        if calorieDaysLast21.count >= 4 {
            let avg = Double(calorieDaysLast21.reduce(0) { $0 + $1.kcal }) / Double(calorieDaysLast21.count)
            calorieAvg = Int(avg.rounded())
            let d = Double(tdee) - avg
            deficit = Int(d.rounded())
            impliedWeekly = d * 7 / AppConstants.kcalPerKg
        }

        var result = Result(
            state: .ok,
            trendWeightNow: trendNow,
            weeklyRate: weeklyRate,
            toGoal: toGoal,
            deficitImpliedWeeklyRate: impliedWeekly,
            deficit: deficit,
            calorieAvg: calorieAvg
        )

        // 9. State + window.
        let absSlope = abs(b)
        let flat = abs(weeklyRate) < flatWeekly

        if abs(toGoal) < hitThreshold {
            result.state = .hit
            result.trendWeightNow = trendNow
            return result
        }

        // Stalled: trend not heading toward the goal, or essentially flat.
        if flat || sign(-b) != sign(toGoal) {
            result.state = .stalled
            return result
        }

        let centralDays = abs(toGoal) / absSlope
        let rateHi = absSlope + seB
        let rateLo = max(rateFloorPerDay, absSlope - seB)

        let soonerDays = min(maxProjectionDays, abs(toGoal) / rateHi)
        let laterDays = min(maxProjectionDays, abs(toGoal) / rateLo)
        let cappedCentral = min(maxProjectionDays, centralDays)

        result.centralDate = today.addingDays(Int(cappedCentral.rounded()))
        result.soonerDate = today.addingDays(Int(soonerDays.rounded()))
        result.laterDate = today.addingDays(Int(laterDays.rounded()))
        result.weeksAway = Int((cappedCentral / 7).rounded())

        result.state = centralDays > slowDaysLimit ? .slow : .ok
        return result
    }

    private static func sign(_ x: Double) -> Int {
        x > 0 ? 1 : (x < 0 ? -1 : 0)
    }
}
