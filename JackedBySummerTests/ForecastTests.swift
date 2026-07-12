import XCTest
@testable import JackedBySummer

/// Unit tests for the deterministic forecast (§10 of the brief).
/// These mirror a Python reference implementation that was run and verified
/// independently; the expected values here are analytically or numerically known.
final class ForecastTests: XCTestCase {

    // A fixed, deterministic base date so nothing depends on "now".
    private let base: Date = {
        var c = DateComponents()
        c.year = 2025; c.month = 1; c.day = 1
        return Calendar.current.date(from: c)!.startOfDay
    }()

    private func points(_ pairs: [(Int, Double)]) -> [Forecast.WeightPoint] {
        pairs.map { Forecast.WeightPoint(date: base.addingDays($0.0), kg: $0.1) }
    }

    func testNoDataWithFewerThanTwoEntries() {
        XCTAssertEqual(Forecast.compute(weights: [], goal: 82, calorieDaysLast21: [], tdee: 2800).state, .noData)
        XCTAssertEqual(Forecast.compute(weights: points([(0, 100)]), goal: 82, calorieDaysLast21: [], tdee: 2800).state, .noData)
    }

    func testNoDataWhenAllOnSameDay() {
        let r = Forecast.compute(weights: points([(5, 100), (5, 99)]), goal: 82, calorieDaysLast21: [], tdee: 2800)
        XCTAssertEqual(r.state, .noData)
    }

    func testPerfectLinearDeclineRecoversExactSlope() {
        // w = 100 - 0.1t for 29 daily points. Slope must be exactly -0.1/day => -0.7/wk.
        let lin = points((0...28).map { ($0, 100.0 - 0.1 * Double($0)) })
        let r = Forecast.compute(weights: lin, goal: 82, calorieDaysLast21: [], tdee: 2800, today: base.addingDays(100))
        XCTAssertEqual(r.weeklyRate, -0.7, accuracy: 1e-6)
        XCTAssertEqual(r.state, .ok)
        // EMA trend lags slightly above the last raw value (97.2).
        XCTAssertGreaterThan(r.trendWeightNow, 97.2)
        XCTAssertEqual(r.trendWeightNow, 97.4333, accuracy: 1e-3)
        XCTAssertEqual(r.toGoal, r.trendWeightNow - 82, accuracy: 1e-9)
        // Zero residual => zero slope error => sooner == central == later.
        XCTAssertEqual(r.soonerDate, r.centralDate)
        XCTAssertEqual(r.laterDate, r.centralDate)
        XCTAssertNotNil(r.weeksAway)
    }

    func testFlatSeriesIsStalled() {
        let flat = points((0...14).map { ($0, 90.0) })
        let r = Forecast.compute(weights: flat, goal: 82, calorieDaysLast21: [], tdee: 2800)
        XCTAssertEqual(r.state, .stalled)
        XCTAssertEqual(r.weeklyRate, 0, accuracy: 1e-6)
    }

    func testGainingWhileGoalBelowIsStalled() {
        let up = points((0...14).map { ($0, 90.0 + 0.05 * Double($0)) })
        let r = Forecast.compute(weights: up, goal: 82, calorieDaysLast21: [], tdee: 2800)
        XCTAssertEqual(r.state, .stalled)
    }

    func testWithinThresholdIsHit() {
        let hit = points((0..<10).map { ($0, 82.10 - 0.001 * Double($0)) })
        let r = Forecast.compute(weights: hit, goal: 82, calorieDaysLast21: [], tdee: 2800)
        XCTAssertEqual(r.state, .hit)
    }

    func testLargeGapWithModestRateIsSlow() {
        // start 150, -0.06/day (not flat), goal 82 => ~1097 central days > 900.
        let slow = points((0..<40).map { ($0, 150.0 - 0.06 * Double($0)) })
        let r = Forecast.compute(weights: slow, goal: 82, calorieDaysLast21: [], tdee: 2800, today: base.addingDays(200))
        XCTAssertEqual(r.state, .slow)
    }

    func testShallowSubFlatSlopeIsStalledNotSlow() {
        // -0.005/day = -0.035/wk is below the 0.05/wk flat threshold => stalled.
        let shallow = points((0..<40).map { ($0, 90.0 - 0.005 * Double($0)) })
        let r = Forecast.compute(weights: shallow, goal: 82, calorieDaysLast21: [], tdee: 2800, today: base.addingDays(200))
        XCTAssertEqual(r.state, .stalled)
    }

    func testCalorieCrossCheckNeedsFourDays() {
        let lin = points((0...28).map { ($0, 100.0 - 0.1 * Double($0)) })
        let cals: [(date: Date, kcal: Int)] = [
            (base.addingDays(0), 2300), (base.addingDays(1), 2400),
            (base.addingDays(2), 2200), (base.addingDays(3), 2500),
        ]
        let r = Forecast.compute(weights: lin, goal: 82, calorieDaysLast21: cals, tdee: 2800, today: base.addingDays(100))
        XCTAssertEqual(r.calorieAvg, 2350)
        XCTAssertEqual(r.deficit, 450)
        XCTAssertEqual(r.deficitImpliedWeeklyRate ?? 0, Double(2800 - 2350) * 7 / 7700, accuracy: 1e-9)

        let under = Forecast.compute(weights: lin, goal: 82,
                                     calorieDaysLast21: Array(cals.prefix(3)), tdee: 2800, today: base.addingDays(100))
        XCTAssertNil(under.deficitImpliedWeeklyRate)
        XCTAssertNil(under.deficit)
        XCTAssertNil(under.calorieAvg)
    }

    func testWindowOrderingWithNoise() {
        let noisy = points([(0, 100), (3, 99.6), (6, 99.9), (9, 99.0),
                            (12, 98.8), (15, 98.9), (18, 98.2), (21, 98.0)])
        let r = Forecast.compute(weights: noisy, goal: 82, calorieDaysLast21: [], tdee: 2800, today: base.addingDays(100))
        if r.state == .ok || r.state == .slow {
            let s = r.soonerDate!, c = r.centralDate!, l = r.laterDate!
            XCTAssertLessThanOrEqual(s, c)
            XCTAssertLessThanOrEqual(c, l)
        }
    }
}
