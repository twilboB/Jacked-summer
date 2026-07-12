import XCTest
@testable import JackedBySummer

/// Sanity tests for static content, date helpers, formatters, and enum mappings.
final class ContentAndModelTests: XCTestCase {

    // MARK: Lift content

    func testLiftContentShape() {
        XCTAssertEqual(LiftContent.days.count, 2)
        XCTAssertEqual(LiftContent.day(1).id, 1)
        XCTAssertEqual(LiftContent.day(2).id, 2)
        // Every exercise has a stable, unique id and at least one set.
        let ids = LiftContent.days.flatMap { $0.exercises.map(\.id) }
        XCTAssertEqual(ids.count, Set(ids).count, "exercise ids must be unique")
        for ex in LiftContent.days.flatMap(\.exercises) {
            XCTAssertGreaterThan(ex.sets, 0)
            XCTAssertFalse(ex.name.isEmpty)
        }
    }

    func testSupersetPairingExists() {
        // Each day should contain exactly one superset group of two exercises.
        for day in LiftContent.days {
            let groups = day.exercises.compactMap { ex -> String? in
                if case let .superset(group) = ex.style { return group }
                return nil
            }
            let counts = Dictionary(grouping: groups, by: { $0 }).mapValues(\.count)
            XCTAssertEqual(counts.count, 1, "one superset group per day")
            XCTAssertEqual(counts.values.first, 2, "superset group must pair two exercises")
        }
    }

    // MARK: Kettlebell content

    func testKettlebellContentShape() {
        XCTAssertEqual(KettlebellContent.days.count, 7)
        XCTAssertEqual(KettlebellContent.day(1).benchmark, .swings)
        XCTAssertEqual(KettlebellContent.day(4).benchmark, .complexTime)
        XCTAssertEqual(KettlebellContent.milestones, [3, 7, 14, 30, 60, 100])
        for (i, d) in KettlebellContent.days.enumerated() {
            XCTAssertEqual(d.id, i + 1)
            XCTAssertFalse(d.prescription.isEmpty)
        }
    }

    // MARK: Date helpers

    func testDateHelpers() {
        var c = DateComponents(); c.year = 2025; c.month = 3; c.day = 10
        let d = Calendar.current.date(from: c)!.startOfDay
        XCTAssertEqual(d.addingDays(5).dayCount(to: d), -5)
        XCTAssertEqual(d.dayCount(to: d.addingDays(5)), 5)
        XCTAssertEqual(d.addingDays(0), d)
    }

    // MARK: Formatters

    func testClockFormat() {
        XCTAssertEqual(AppFormat.clock(0), "0:00")
        XCTAssertEqual(AppFormat.clock(65), "1:05")
        XCTAssertEqual(AppFormat.clock(600), "10:00")
        XCTAssertEqual(AppFormat.clock(125), "2:05")
    }

    func testKgFormat() {
        XCTAssertEqual(AppFormat.kg(82.34), "82.3")
        XCTAssertEqual(AppFormat.kg(82.0, decimals: 0), "82")
    }

    // MARK: Enums

    func testFoodSourceMarkers() {
        XCTAssertTrue(FoodSource.photo.showsMarker)
        XCTAssertTrue(FoodSource.barcode.showsMarker)
        XCTAssertTrue(FoodSource.label.showsMarker)
        XCTAssertFalse(FoodSource.manual.showsMarker)
        XCTAssertFalse(FoodSource.text.showsMarker)
        for s in FoodSource.allCases { XCTAssertFalse(s.symbolName.isEmpty) }
    }

    func testConstants() {
        XCTAssertEqual(AppConstants.kcalPerKg, 7700, accuracy: 1e-9)
        XCTAssertEqual(AppConstants.cutDeficit, 500)
    }
}
