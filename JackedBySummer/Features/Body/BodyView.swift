import SwiftUI
import SwiftData
import Charts
import FoundationModels

/// Tab 4 "Body" — bodyweight tracking, the deterministic forecast, and the
/// on-device coach read. The maths lives in `Forecast`; the model here only
/// assembles inputs and renders results.
struct BodyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIAvailability.self) private var ai

    /// Ascending by date so `first`/`last` mean earliest/latest.
    @Query(sort: \WeightEntryRecord.date, order: .forward) private var weights: [WeightEntryRecord]
    @Query private var food: [FoodEntryRecord]
    @Query private var gymSets: [GymSetRecord]
    @Query private var kbLogs: [KbLogRecord]

    // MARK: - Derived data

    private var settings: AppSettings { SettingsStore.current(modelContext) }

    /// (date, total kcal) for each of the last 21 calendar days that has food logged.
    private var calorieDaysLast21: [(date: Date, kcal: Int)] {
        let today = Date().startOfDay
        let start = today.addingDays(-20) // inclusive 21-day window
        let recent = food.filter { $0.date.startOfDay >= start && $0.date.startOfDay <= today }
        let grouped = Dictionary(grouping: recent) { $0.date.startOfDay }
        return grouped
            .map { (date: $0.key, kcal: $0.value.reduce(0) { $0 + $1.kcal }) }
            .sorted { $0.date < $1.date }
    }

    private var forecast: Forecast.Result {
        Forecast.compute(
            weights: weights.map { Forecast.WeightPoint(date: $0.date, kg: $0.kg) },
            goal: settings.goalWeightKg,
            calorieDaysLast21: calorieDaysLast21,
            tdee: settings.tdee
        )
    }

    private var goalBinding: Binding<Double> {
        Binding(
            get: { settings.goalWeightKg },
            set: { settings.goalWeightKg = $0; try? modelContext.save() }
        )
    }

    var body: some View {
        ScreenScaffold(title: "Body") {
            CurrentWeightCard(weights: weights, goal: goalBinding)

            LogWeightCard(lastKg: weights.last?.kg) { kg in
                logToday(kg)
            }

            ForecastCard(result: forecast)

            if weights.count >= 2 {
                TrendChart(weights: weights, goal: settings.goalWeightKg)
            }

            CoachCard(summaryProvider: makeCoachSummary)
        }
    }

    // MARK: - Logging (upsert one entry per calendar day)

    private func logToday(_ kg: Double) {
        let today = Date().startOfDay
        if let existing = weights.first(where: { $0.date.startOfDay == today }) {
            existing.kg = kg
        } else {
            modelContext.insert(WeightEntryRecord(date: today, kg: kg))
        }
        try? modelContext.save()
    }

    // MARK: - Coach summary assembly

    private func makeCoachSummary() -> CoachSummary {
        let f = forecast

        let recent = weights.suffix(6).map {
            CoachSummary.WeighIn(date: AppFormat.shortDate.string(from: $0.date), kg: $0.kg)
        }

        let currentWeek = gymSets.map(\.week).max() ?? 1
        let thisWeekSets = gymSets.filter { $0.week == currentWeek }
        let lastWeekSets = gymSets.filter { $0.week == currentWeek - 1 }

        // Top set per distinct exercise this week (max weight), up to five lifts.
        let exerciseIds = Array(Set(thisWeekSets.map(\.exerciseId))).sorted().prefix(5)
        let keyLifts: [CoachSummary.KeyLift] = exerciseIds.compactMap { id in
            let sets = thisWeekSets.filter { $0.exerciseId == id }
            guard let top = sets.max(by: { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }),
                  let topW = top.weightKg else { return nil }
            let lastTopW = lastWeekSets
                .filter { $0.exerciseId == id }
                .compactMap(\.weightKg)
                .max() ?? topW
            return CoachSummary.KeyLift(
                name: id, // exerciseId stands in for a display name
                topSetKg: topW,
                reps: top.reps ?? 0,
                weekOverWeekWeightChangeKg: topW - lastTopW
            )
        }

        let kbDays = Set(kbLogs.map { $0.date.startOfDay })
        let today = Date().startOfDay
        let sevenAgo = today.addingDays(-6)
        let kbLast7 = kbLogs.filter { $0.date.startOfDay >= sevenAgo && $0.date.startOfDay <= today }.count
        let maxSwings = kbLogs.filter { $0.dayNumber == 1 }.compactMap(\.benchmarkValue).max().map { Int($0) }
        let bestComplex = kbLogs.filter { $0.dayNumber == 4 }.compactMap(\.benchmarkValue).min().map { Int($0) }

        return CoachSummary(
            goalWeightKg: settings.goalWeightKg,
            tdee: settings.tdee,
            trendWeightNowKg: f.trendWeightNow,
            scaleWeeklyRateKg: f.weeklyRate,
            forecastState: f.state.rawValue,
            forecastCentralDate: f.centralDate.map { AppFormat.mediumDate.string(from: $0) },
            forecastSoonerDate: f.soonerDate.map { AppFormat.mediumDate.string(from: $0) },
            forecastLaterDate: f.laterDate.map { AppFormat.mediumDate.string(from: $0) },
            calorieAvg: f.calorieAvg,
            deficit: f.deficit,
            deficitImpliedWeeklyRateKg: f.deficitImpliedWeeklyRate,
            recentWeighIns: Array(recent),
            currentWeek: currentWeek,
            totalVolumeThisWeekKg: Stats.volume(of: thisWeekSets),
            totalVolumeLastWeekKg: Stats.volume(of: lastWeekSets),
            keyLifts: keyLifts,
            kbCurrentStreak: Stats.currentStreak(loggedDays: kbDays),
            kbLongestStreak: Stats.longestStreak(loggedDays: kbDays),
            kbTotalSessions: kbLogs.count,
            kbSessionsLast7: kbLast7,
            kbMaxUnbrokenSwings: maxSwings,
            kbBestComplexTimeSec: bestComplex
        )
    }
}

// MARK: - Current weight

private struct CurrentWeightCard: View {
    let weights: [WeightEntryRecord]
    @Binding var goal: Double

    private var current: Double? { weights.last?.kg }
    private var first: Double? { weights.first?.kg }

    /// Change over ~7 days: latest vs the entry closest to seven days before it.
    private var delta7: Double? {
        guard let latest = weights.last, weights.count >= 2 else { return nil }
        let target = latest.date.addingDays(-7)
        guard let ref = weights.dropLast().min(by: {
            abs($0.date.dayCount(to: target)) < abs($1.date.dayCount(to: target))
        }) else { return nil }
        return latest.kg - ref.kg
    }

    private var deltaAll: Double? {
        guard let c = current, let f = first, weights.count >= 2 else { return nil }
        return c - f
    }

    /// Progress from the first logged weight toward the goal, clamped 0...1.
    private var progress: Double {
        guard let c = current, let f = first else { return 0 }
        let span = f - goal
        guard abs(span) > 0.0001 else { return c <= goal ? 1 : 0 }
        return min(1, max(0, (f - c) / span))
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Current weight")

                if let c = current {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(AppFormat.kg(c))
                            .font(.stat(52))
                            .contentTransition(.numericText())
                        Text("kg")
                            .font(.statSmall(20))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 20) {
                        if let d7 = delta7 {
                            labelled("7-day") {
                                DeltaLabel(value: d7, unit: " kg", goodWhenPositive: false)
                            }
                        }
                        if let dAll = deltaAll {
                            labelled("Since start") {
                                DeltaLabel(value: dAll, unit: " kg", goodWhenPositive: false)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        MoltenProgressBar(fraction: progress)
                        HStack {
                            Text("Goal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                            // Editable goal, bound straight to settings.
                            Stepper(value: $goal, in: 40...200, step: 0.5) {
                                Text("\(AppFormat.kg(goal)) kg")
                                    .font(.statSmall(17))
                                    .contentTransition(.numericText())
                            }
                            .labelsHidden()
                            Text("\(AppFormat.kg(goal)) kg")
                                .font(.statSmall(17))
                                .foregroundStyle(Palette.molten)
                        }
                    }
                } else {
                    Text("No weigh-ins yet. Log your first below.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func labelled<V: View>(_ caption: String, @ViewBuilder _ value: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            value()
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Log today

private struct LogWeightCard: View {
    let lastKg: Double?
    let onLog: (Double) -> Void

    @State private var weightText = ""
    @FocusState private var focused: Bool

    private var parsed: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Log today")

                HStack(spacing: 10) {
                    TextField("Weight", text: $weightText)
                        .keyboardType(.decimalPad)
                        .focused($focused)
                        .font(.stat(28))
                        .textFieldStyle(.plain)
                    Text("kg")
                        .font(.statSmall(18))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    if let kg = parsed, kg > 0 {
                        onLog(kg)
                        focused = false
                    }
                } label: {
                    Label("Log", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent) // VERIFY: iOS 27 prominent glass button style
                .tint(Palette.molten)
                .disabled((parsed ?? 0) <= 0)

                Text("Weigh in first thing after the bathroom. Trust the trend, not the day.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if weightText.isEmpty, let lastKg {
                weightText = AppFormat.kg(lastKg)
            }
        }
    }
}

// MARK: - Forecast

private struct ForecastCard: View {
    let result: Forecast.Result

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Forecast")

                switch result.state {
                case .noData:
                    Text("Log at least two weigh-ins to forecast.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                case .hit:
                    trendNow
                    Label("You're at goal. Hold the trend and keep the muscle.",
                          systemImage: "checkmark.seal.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Palette.green)
                    rates

                case .stalled:
                    trendNow
                    Label("Trend has stalled. Nudge the deficit or check logging consistency.",
                          systemImage: "pause.circle")
                        .font(.callout)
                        .foregroundStyle(Palette.gold)
                    rates

                case .slow, .ok:
                    trendNow
                    projection
                    rates
                    notes
                }
            }
        }
    }

    private var trendNow: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(AppFormat.kg(result.trendWeightNow))
                    .font(.stat(40))
                    .contentTransition(.numericText())
                Text("kg trend")
                    .font(.statSmall(18))
                    .foregroundStyle(.secondary)
            }
            Text("Denoised weight now")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var projection: some View {
        if let central = result.centralDate {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .foregroundStyle(Palette.molten)
                    Text(AppFormat.mediumDate.string(from: central))
                        .font(.statSmall(20))
                    if let weeks = result.weeksAway {
                        Text("~\(weeks) \(weeks == 1 ? "week" : "weeks") away")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let sooner = result.soonerDate, let later = result.laterDate {
                    Text("Likely between \(AppFormat.mediumDate.string(from: sooner)) and \(AppFormat.mediumDate.string(from: later))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if result.state == .slow {
                    Text("At this pace it's a long road — worth tightening the deficit.")
                        .font(.caption)
                        .foregroundStyle(Palette.gold)
                }
            }
        }
    }

    private var rates: some View {
        HStack(spacing: 12) {
            StatChip(
                value: AppFormat.kg(result.weeklyRate),
                caption: "kg/wk scale",
                systemImage: "chart.line.downtrend.xyaxis"
            )
            StatChip(
                value: result.deficitImpliedWeeklyRate.map { AppFormat.kg($0) } ?? "—",
                caption: "kg/wk deficit",
                systemImage: "flame"
            )
        }
    }

    @ViewBuilder
    private var notes: some View {
        if abs(result.weeklyRate) > 1.0 {
            Label("Ease toward 0.5–0.8 kg/week to protect muscle.",
                  systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(Palette.gold)
        }
        if let implied = result.deficitImpliedWeeklyRate,
           abs(abs(result.weeklyRate) - abs(implied)) > 0.2 {
            Label("The gap between these two is the signal.",
                  systemImage: "arrow.left.arrow.right")
                .font(.caption)
                .foregroundStyle(Palette.steel)
        }
    }
}

// MARK: - Trend chart

private struct TrendChart: View {
    let weights: [WeightEntryRecord]
    let goal: Double

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Trend")

                // VERIFY: Swift Charts API (LineMark / RuleMark / axis modifiers) on iOS 27.
                Chart {
                    ForEach(weights) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.kg)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Palette.molten)
                    }

                    RuleMark(y: .value("Goal", goal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(Palette.steel)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Goal \(AppFormat.kg(goal))")
                                .font(.caption2)
                                .foregroundStyle(Palette.steel)
                        }
                }
                .frame(height: 200)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4))
                }
            }
        }
    }
}

// MARK: - Coach

private struct CoachCard: View {
    let summaryProvider: () -> CoachSummary

    @Environment(AIAvailability.self) private var ai
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var text: String?
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Coach")

                if !ai.isAvailable {
                    Label(ai.note, systemImage: "sparkles.slash")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    content
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let text {
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
                .transition(reduceMotion ? .identity : .opacity)
        }

        if loading {
            HStack(spacing: 8) {
                ProgressView()
                Text("Reading your data…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        if let errorMessage {
            HStack(spacing: 8) {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Palette.red)
                Spacer(minLength: 0)
                Button("Retry") { Task { await generate(deep: false) } }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.molten)
            }
        }

        HStack(spacing: 10) {
            Button {
                Task { await generate(deep: false) }
            } label: {
                Label(text == nil ? "Read my data" : "Refresh",
                      systemImage: text == nil ? "sparkles" : "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent) // VERIFY: iOS 27 prominent glass button style
            .tint(Palette.molten)
            .disabled(loading)

            Button {
                Task { await generate(deep: true) }
            } label: {
                Label("Deeper review", systemImage: "cloud")
            }
            .buttonStyle(.glass) // VERIFY: iOS 27 secondary glass button style
            .disabled(loading)
        }
    }

    @MainActor
    private func generate(deep: Bool) async {
        loading = true
        errorMessage = nil
        let summary = summaryProvider()
        do {
            // VERIFY: CoachService/FoundationModels session APIs on iOS 27.
            let result = deep
                ? try await CoachService.deepReview(summary: summary)
                : try await CoachService.read(summary: summary)
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                text = result
            }
        } catch {
            errorMessage = "Couldn't reach the coach. Try again."
        }
        loading = false
    }
}

// MARK: - Preview

#Preview {
    BodyView()
        .environment(AIAvailability())
        .modelContainer(for: [
            GymSetRecord.self, KbLogRecord.self, FoodEntryRecord.self,
            WeightEntryRecord.self, AppSettings.self
        ], inMemory: true)
}
