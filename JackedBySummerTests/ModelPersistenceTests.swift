import XCTest
import SwiftData
@testable import JackedBySummer

/// Integration tests that exercise the SwiftData schema in an in-memory store.
/// These prove the @Model graph is valid and round-trips, and check the
/// once-per-day upsert semantics the app relies on for weight and kettlebell logs.
@MainActor
final class ModelPersistenceTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: GymSetRecord.self, KbLogRecord.self, FoodEntryRecord.self,
            WeightEntryRecord.self, AppSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func testSchemaRoundTrips() throws {
        let ctx = try makeContext()
        ctx.insert(GymSetRecord(week: 1, exerciseId: "d1_incline_db_press", setIndex: 0, weightKg: 30, reps: 10))
        ctx.insert(KbLogRecord(date: Date().startOfDay, dayNumber: 1, benchmarkValue: 42))
        ctx.insert(FoodEntryRecord(date: Date().startOfDay, name: "Eggs", kcal: 200, protein: 18, carbs: 2, fat: 14, createdAt: Date()))
        ctx.insert(WeightEntryRecord(date: Date().startOfDay, kg: 90))
        ctx.insert(AppSettings())
        try ctx.save()

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<GymSetRecord>()).count, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<KbLogRecord>()).count, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<FoodEntryRecord>()).count, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WeightEntryRecord>()).count, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<AppSettings>()).count, 1)
    }

    func testSettingsStoreCreatesExactlyOne() throws {
        let ctx = try makeContext()
        let a = SettingsStore.current(ctx)
        a.tdee = 2600
        try ctx.save()
        let b = SettingsStore.current(ctx)
        XCTAssertEqual(b.tdee, 2600, "second call must return the same settings row")
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<AppSettings>()).count, 1)
    }

    /// Demonstrates the one-weigh-in-per-day rule that the Body tab implements.
    func testWeightUpsertPerDay() throws {
        let ctx = try makeContext()
        let today = Date().startOfDay

        func logWeight(_ kg: Double) throws {
            let descriptor = FetchDescriptor<WeightEntryRecord>(
                predicate: #Predicate { $0.date == today }
            )
            if let existing = try ctx.fetch(descriptor).first {
                existing.kg = kg
            } else {
                ctx.insert(WeightEntryRecord(date: today, kg: kg))
            }
            try ctx.save()
        }

        try logWeight(90.0)
        try logWeight(89.5) // same day -> update, not insert
        let all = try ctx.fetch(FetchDescriptor<WeightEntryRecord>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.kg, 89.5)
    }

    func testFoodTotalsAcrossEntries() throws {
        let ctx = try makeContext()
        let day = Date().startOfDay
        ctx.insert(FoodEntryRecord(date: day, name: "a", kcal: 500, protein: 40, carbs: 50, fat: 10, createdAt: Date()))
        ctx.insert(FoodEntryRecord(date: day, name: "b", kcal: 300, protein: 25, carbs: 20, fat: 8, createdAt: Date()))
        try ctx.save()
        let entries = try ctx.fetch(FetchDescriptor<FoodEntryRecord>())
        let totals = Stats.totals(of: entries)
        XCTAssertEqual(totals.kcal, 800)
        XCTAssertEqual(totals.protein, 65)
    }
}
