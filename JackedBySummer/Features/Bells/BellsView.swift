import SwiftUI
import SwiftData

/// Tab 2 "Bells" — the kettlebell programme, gamified around a daily streak.
/// One session may be logged per calendar day; logging again the same day
/// re-points that day at whichever plan day was tapped.
struct BellsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [KbLogRecord]

    /// Every calendar day that carries a logged session.
    private var loggedDays: Set<Date> {
        Set(records.map { $0.date.startOfDay })
    }

    private var currentStreak: Int {
        Stats.currentStreak(loggedDays: loggedDays)
    }

    private var longestStreak: Int {
        Stats.longestStreak(loggedDays: loggedDays)
    }

    /// The record logged for today, if any (at most one per calendar day).
    private var todayRecord: KbLogRecord? {
        let today = Date().startOfDay
        return records.first { $0.date.startOfDay == today }
    }

    var body: some View {
        ScreenScaffold(title: "Bells") {
            StreakHero(
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                sessions: records.count
            )

            MilestoneTrack(
                currentStreak: currentStreak,
                longestStreak: longestStreak
            )

            weekStrip

            SectionHeader(title: "The seven days")

            ForEach(KettlebellContent.days) { day in
                DayCard(
                    day: day,
                    isLoggedToday: todayRecord?.dayNumber == day.id,
                    bestText: bestText(for: day),
                    onLog: { value in log(day: day, benchmarkValue: value) }
                )
            }

            footnote
        }
    }

    // MARK: - Sections

    private var weekStrip: some View {
        let flags = Stats.lastSevenDays(loggedDays: loggedDays)
        let count = flags.filter { $0 }.count
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "This week")
                DotStrip(filled: flags, labels: Stats.lastSevenLabels())
                Text("\(count) / 7 this week")
                    .font(.statSmall(18))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footnote: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Label("Programming note", systemImage: "info.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(KettlebellContent.programmingNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Best benchmark per day

    /// Formatted "Best" string for a day's benchmark, or nil when none exists.
    private func bestText(for day: KbDay) -> String? {
        switch day.benchmark {
        case .none:
            return nil
        case .swings:
            let values = records
                .filter { $0.dayNumber == day.id }
                .compactMap(\.benchmarkValue)
            guard let best = values.max() else { return nil }
            return "\(Int(best))"
        case .complexTime:
            let values = records
                .filter { $0.dayNumber == day.id }
                .compactMap(\.benchmarkValue)
            guard let best = values.min() else { return nil } // lower is better
            return AppFormat.clock(best)
        }
    }

    // MARK: - Logging

    /// Log a session for TODAY. If a record already exists for today's calendar
    /// day it is repointed to this plan day (and benchmark); otherwise a new one
    /// is inserted. Enforces one session per calendar day.
    private func log(day: KbDay, benchmarkValue: Double?) {
        let today = Date().startOfDay
        if let existing = todayRecord {
            existing.dayNumber = day.id
            existing.benchmarkValue = benchmarkValue
        } else {
            modelContext.insert(
                KbLogRecord(date: today, dayNumber: day.id, benchmarkValue: benchmarkValue)
            )
        }
        try? modelContext.save()
    }
}

// MARK: - Streak hero

private struct StreakHero: View {
    let currentStreak: Int
    let longestStreak: Int
    let sessions: Int

    var body: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 16) {
                FlameView(alive: currentStreak > 0, size: 56)

                VStack(alignment: .leading, spacing: 0) {
                    Text("\(currentStreak)")
                        .font(.stat(64))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text(currentStreak == 1 ? "day streak" : "days streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    StatChip(value: "\(longestStreak)", caption: "Best", tint: Palette.gold, systemImage: "trophy.fill")
                    StatChip(value: "\(sessions)", caption: "Sessions", systemImage: "checklist")
                }
                .frame(width: 96)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current streak \(currentStreak) days. Best \(longestStreak). \(sessions) sessions.")
        }
    }
}

// MARK: - Milestone track

private struct MilestoneTrack: View {
    let currentStreak: Int
    let longestStreak: Int

    private var nextMilestone: Int? {
        KettlebellContent.milestones.first { currentStreak < $0 }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Milestones")

                HStack(spacing: 10) {
                    ForEach(KettlebellContent.milestones, id: \.self) { threshold in
                        MilestoneBadge(
                            threshold: threshold,
                            lit: longestStreak >= threshold
                        )
                    }
                }

                if let next = nextMilestone {
                    let fraction = Double(currentStreak) / Double(next)
                    MoltenProgressBar(fraction: fraction)
                    Text("Next: \(next) days (\(currentStreak) / \(next))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    MoltenProgressBar(fraction: 1)
                    Label("All milestones reached", systemImage: "crown.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.gold)
                }
            }
        }
    }
}

private struct MilestoneBadge: View {
    let threshold: Int
    let lit: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(lit ? AnyShapeStyle(Palette.moltenGradient) : AnyShapeStyle(Color.white.opacity(0.08)))
                Circle()
                    .strokeBorder(lit ? Palette.gold.opacity(0.8) : .white.opacity(0.12), lineWidth: 1)
                Image(systemName: lit ? "flame.fill" : "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(lit ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.secondary))
            }
            .frame(width: 40, height: 40)

            Text("\(threshold)")
                .font(.statSmall(15))
                .foregroundStyle(lit ? AnyShapeStyle(Palette.gold) : AnyShapeStyle(Color.secondary))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(threshold) day milestone, \(lit ? "reached" : "locked")")
    }
}

// MARK: - Day card

private struct DayCard: View {
    let day: KbDay
    let isLoggedToday: Bool
    let bestText: String?
    let onLog: (Double?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    // Benchmark inputs (local editing state).
    @State private var swingsText = ""
    @State private var minutesText = ""
    @State private var secondsText = ""

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                header

                DisclosureGroup(isExpanded: $expanded) {
                    Text(day.prescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                } label: {
                    Text("Prescription")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.molten)
                }

                if day.benchmark != .none {
                    BenchmarkField(
                        benchmark: day.benchmark,
                        swingsText: $swingsText,
                        minutesText: $minutesText,
                        secondsText: $secondsText,
                        bestText: bestText
                    )
                }

                logButton
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: expanded)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("\(day.id)")
                .font(.stat(22))
                .frame(width: 40, height: 40)
                .background(Palette.moltenGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(day.name)
                    .font(.headline)
                Text(day.formatTag)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if isLoggedToday {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(Palette.green)
                    .accessibilityLabel("Logged today")
            }
        }
    }

    private var logButton: some View {
        Button {
            onLog(currentBenchmarkValue())
        } label: {
            Label(isLoggedToday ? "Logged today" : "Log today",
                  systemImage: isLoggedToday ? "checkmark" : "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent) // VERIFY: iOS 27 prominent glass button style name
        .tint(Palette.molten)
    }

    /// Parse the benchmark inputs into a stored value for this day's benchmark.
    private func currentBenchmarkValue() -> Double? {
        switch day.benchmark {
        case .none:
            return nil
        case .swings:
            guard let n = Int(swingsText.trimmingCharacters(in: .whitespaces)), n > 0 else { return nil }
            return Double(n)
        case .complexTime:
            let mins = Int(minutesText.trimmingCharacters(in: .whitespaces)) ?? 0
            let secs = Int(secondsText.trimmingCharacters(in: .whitespaces)) ?? 0
            let total = mins * 60 + secs
            return total > 0 ? Double(total) : nil
        }
    }
}

// MARK: - Benchmark input

private struct BenchmarkField: View {
    let benchmark: KbBenchmark
    @Binding var swingsText: String
    @Binding var minutesText: String
    @Binding var secondsText: String
    let bestText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch benchmark {
            case .none:
                EmptyView()

            case .swings:
                HStack {
                    TextField("Max unbroken swings", text: $swingsText)
                        .keyboardType(.numberPad)
                        .font(.statSmall(18))
                        .textFieldStyle(.plain)
                    if let bestText {
                        Text("Best: \(bestText)")
                            .font(.caption)
                            .foregroundStyle(Palette.gold)
                    }
                }

            case .complexTime:
                HStack(spacing: 8) {
                    TextField("min", text: $minutesText)
                        .keyboardType(.numberPad)
                        .frame(width: 48)
                    Text(":")
                        .foregroundStyle(.secondary)
                    TextField("sec", text: $secondsText)
                        .keyboardType(.numberPad)
                        .frame(width: 48)
                    Spacer(minLength: 0)
                    if let bestText {
                        Text("Best: \(bestText)")
                            .font(.caption)
                            .foregroundStyle(Palette.gold)
                    }
                }
                .font(.statSmall(18))
                .textFieldStyle(.plain)
            }
        }
        .padding(10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    BellsView()
        .modelContainer(for: [
            GymSetRecord.self, KbLogRecord.self, FoodEntryRecord.self,
            WeightEntryRecord.self, AppSettings.self
        ], inMemory: true)
}
