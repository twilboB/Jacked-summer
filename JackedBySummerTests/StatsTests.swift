import XCTest
@testable import JackedBySummer

/// Unit tests for streak, volume, and aggregation helpers.
final class StatsTests: XCTestCase {

    private let base: Date = {
        var c = DateComponents()
        c.year = 2025; c.month = 6; c.day = 1
        return Calendar.current.date(from: c)!.startOfDay
    }()

    private func days(_ offsets: [Int]) -> Set<Date> {
        Set(offsets.map { base.addingDays($0) })
    }

    // MARK: Current streak

    func testCurrentStreakCountsFromTodayWhenLogged() {
        let logged = days([10, 9, 8])
        XCTAssertEqual(Stats.currentStreak(loggedDays: logged, today: base.addingDays(10)), 3)
    }

    func testCurrentStreakCountsFromYesterdayWhenTodayMissing() {
        let logged = days([9, 8, 7])
        XCTAssertEqual(Stats.currentStreak(loggedDays: logged, today: base.addingDays(10)), 3)
    }

    func testCurrentStreakZeroWhenNeitherTodayNorYesterday() {
        let logged = days([7, 6])
        XCTAssertEqual(Stats.currentStreak(loggedDays: logged, today: base.addingDays(10)), 0)
    }

    func testCurrentStreakBreaksOnGap() {
        let logged = days([10, 9, 7, 6])
        XCTAssertEqual(Stats.currentStreak(loggedDays: logged, today: base.addingDays(10)), 2)
    }

    func testCurrentStreakEmpty() {
        XCTAssertEqual(Stats.currentStreak(loggedDays: [], today: base.addingDays(10)), 0)
    }

    // MARK: Longest streak

    func testLongestStreak() {
        XCTAssertEqual(Stats.longestStreak(loggedDays: days([1, 2, 3, 10, 11])), 3)
        XCTAssertEqual(Stats.longestStreak(loggedDays: days([5])), 1)
        XCTAssertEqual(Stats.longestStreak(loggedDays: []), 0)
        XCTAssertEqual(Stats.longestStreak(loggedDays: days([1, 2, 3, 4, 5])), 5)
        XCTAssertEqual(Stats.longestStreak(loggedDays: days([1, 2, 4, 5, 6, 7, 9])), 4)
    }

    // MARK: Last seven days

    func testLastSevenDaysShape() {
        // days oldest->newest for today=10 are [4,5,6,7,8,9,10]; logged {4,8,10}
        let result = Stats.lastSevenDays(loggedDays: days([10, 8, 4]), today: base.addingDays(10))
        XCTAssertEqual(result, [true, false, false, false, true, false, true])
    }

    func testLastSevenDaysAllLogged() {
        let result = Stats.lastSevenDays(loggedDays: days([10, 9, 8, 7, 6, 5, 4]), today: base.addingDays(10))
        XCTAssertEqual(result.filter { $0 }.count, 7)
    }

    func testLastSevenLabelsCount() {
        XCTAssertEqual(Stats.lastSevenLabels(today: base.addingDays(10)).count, 7)
    }

    // MARK: Volume

    func testSetVolume() {
        XCTAssertEqual(Stats.setVolume(weightKg: 40, reps: 10), 400, accuracy: 1e-9)
        XCTAssertEqual(Stats.setVolume(weightKg: nil, reps: 10), 0, accuracy: 1e-9)
        XCTAssertEqual(Stats.setVolume(weightKg: 40, reps: nil), 0, accuracy: 1e-9)
    }

    func testVolumeOfRecords() {
        let recs = [
            GymSetRecord(week: 1, exerciseId: "a", setIndex: 0, weightKg: 40, reps: 10),
            GymSetRecord(week: 1, exerciseId: "a", setIndex: 1, weightKg: 42.5, reps: 8),
            GymSetRecord(week: 1, exerciseId: "a", setIndex: 2, weightKg: nil, reps: 8), // ignored
        ]
        XCTAssertEqual(Stats.volume(of: recs), 40 * 10 + 42.5 * 8, accuracy: 1e-9)
    }

    // MARK: Food totals

    func testFoodTotals() {
        let now = Date()
        let entries = [
            FoodEntryRecord(date: base, name: "a", kcal: 500, protein: 40, carbs: 50, fat: 10, createdAt: now),
            FoodEntryRecord(date: base, name: "b", kcal: 300, protein: 25, carbs: 20, fat: 8, createdAt: now),
        ]
        let t = Stats.totals(of: entries)
        XCTAssertEqual(t.kcal, 800)
        XCTAssertEqual(t.protein, 65)
        XCTAssertEqual(t.carbs, 70)
        XCTAssertEqual(t.fat, 18)
    }
}
