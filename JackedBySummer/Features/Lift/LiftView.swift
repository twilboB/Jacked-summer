import SwiftUI
import SwiftData
import UIKit

// Tab 1 — "Lift"
//
// A two-day split logged week to week. The point is progressive overload:
// every set shows last week's number as a faint "ghost" target and lights
// molten when the entered value matches or beats it.
//
// VERIFY (iOS 27 Liquid Glass): `.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)`,
// `.tint(_:)` on those styles, and `GlassEffectContainer(spacing:)` — names/shapes
// have shifted across betas. `GlassCard`, `.pickerStyle(.segmented)` are project/SDK stable.

struct LiftView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSets: [GymSetRecord]

    @State private var currentWeek: Int = 1
    @State private var selectedDay: Int = 1
    @State private var didInitWeek = false

    // MARK: Derived

    /// Highest week that actually has logged sets (defaults to 1 when empty).
    private var highestWeek: Int {
        allSets.map(\.week).max() ?? 1
    }

    private var day: LiftDay { LiftContent.day(selectedDay) }

    var body: some View {
        ScreenScaffold(title: "Lift") {
            WeekSelector(
                currentWeek: currentWeek,
                highestWeek: highestWeek,
                onPrev: { if currentWeek > 1 { currentWeek -= 1 } },
                onNext: { if currentWeek < highestWeek { currentWeek += 1 } },
                onStartNext: { currentWeek = highestWeek + 1 }
            )

            dayPicker

            ForEach(blocks(for: day.exercises)) { block in
                switch block.kind {
                case .straight(let exercise):
                    ExerciseCardView(
                        exercise: exercise,
                        currentWeek: currentWeek,
                        recordFor: record(for:exerciseId:setIndex:),
                        fetchOrCreate: fetchOrCreate(week:exerciseId:setIndex:),
                        save: save
                    )
                    .id("\(currentWeek)-\(exercise.id)")

                case .superset(let group, let exercises):
                    SupersetHeader(group: group)
                    ForEach(exercises) { exercise in
                        ExerciseCardView(
                            exercise: exercise,
                            currentWeek: currentWeek,
                            recordFor: record(for:exerciseId:setIndex:),
                            fetchOrCreate: fetchOrCreate(week:exerciseId:setIndex:),
                            save: save
                        )
                        .id("\(currentWeek)-\(exercise.id)")
                    }
                }
            }

            SessionTotalCard(
                thisWeekVolume: dayVolume(day: day, week: currentWeek),
                lastWeekVolume: dayVolume(day: day, week: currentWeek - 1)
            )
        }
        .onAppear {
            guard !didInitWeek else { return }
            currentWeek = highestWeek
            didInitWeek = true
        }
    }

    // MARK: Day picker

    private var dayPicker: some View {
        // VERIFY: GlassEffectContainer(spacing:) — clusters the segmented control's glass.
        GlassEffectContainer(spacing: 8) {
            Picker("Day", selection: $selectedDay) {
                Text("Day 1").tag(1)
                Text("Day 2").tag(2)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Record lookup / persistence

    /// The persisted set for (week, exerciseId, setIndex), if one exists.
    private func record(for week: Int, exerciseId: String, setIndex: Int) -> GymSetRecord? {
        allSets.first {
            $0.week == week && $0.exerciseId == exerciseId && $0.setIndex == setIndex
        }
    }

    /// Returns the existing record or inserts a fresh empty one for first-time edits.
    private func fetchOrCreate(week: Int, exerciseId: String, setIndex: Int) -> GymSetRecord {
        if let existing = record(for: week, exerciseId: exerciseId, setIndex: setIndex) {
            return existing
        }
        let created = GymSetRecord(week: week, exerciseId: exerciseId, setIndex: setIndex)
        modelContext.insert(created)
        return created
    }

    private func save() {
        try? modelContext.save()
    }

    // MARK: Volume helpers

    /// Total volume for one exercise in a given week (sum over its sets).
    private func volume(of exercise: Exercise, week: Int) -> Double {
        (0..<exercise.sets).reduce(0.0) { acc, i in
            let r = record(for: week, exerciseId: exercise.id, setIndex: i)
            return acc + Stats.setVolume(weightKg: r?.weightKg, reps: r?.reps)
        }
    }

    /// Total volume for the whole day in a given week.
    private func dayVolume(day: LiftDay, week: Int) -> Double {
        day.exercises.reduce(0.0) { $0 + volume(of: $1, week: week) }
    }

    // MARK: Superset grouping

    /// Group consecutive exercises that share the same superset group.
    private func blocks(for exercises: [Exercise]) -> [ExerciseBlock] {
        var result: [ExerciseBlock] = []
        var index = 0
        while index < exercises.count {
            let exercise = exercises[index]
            switch exercise.style {
            case .straight:
                result.append(ExerciseBlock(kind: .straight(exercise)))
                index += 1
            case .superset(let group):
                var members: [Exercise] = []
                while index < exercises.count,
                      case .superset(let g) = exercises[index].style, g == group {
                    members.append(exercises[index])
                    index += 1
                }
                result.append(ExerciseBlock(kind: .superset(group: group, members)))
            }
        }
        return result
    }
}

// MARK: - Superset grouping model

private struct ExerciseBlock: Identifiable {
    enum Kind {
        case straight(Exercise)
        case superset(group: String, [Exercise])
    }
    let kind: Kind

    var id: String {
        switch kind {
        case .straight(let e): return "straight-\(e.id)"
        case .superset(let group, _): return "superset-\(group)"
        }
    }
}

// MARK: - Week selector

private struct WeekSelector: View {
    let currentWeek: Int
    let highestWeek: Int
    let onPrev: () -> Void
    let onNext: () -> Void
    let onStartNext: () -> Void

    private var canGoPrev: Bool { currentWeek > 1 }
    private var canGoNext: Bool { currentWeek < highestWeek }
    private var atHighest: Bool { currentWeek == highestWeek }

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Button(action: onPrev) {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass) // VERIFY: Liquid Glass secondary button style
                    .disabled(!canGoPrev)
                    .accessibilityLabel("Previous week")

                    Spacer()

                    Text("Week \(currentWeek)")
                        .font(.stat(30))
                        .contentTransition(.numericText())
                        .accessibilityLabel("Week \(currentWeek)")

                    Spacer()

                    Button(action: onNext) {
                        Image(systemName: "chevron.right")
                            .font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass) // VERIFY
                    .disabled(!canGoNext)
                    .accessibilityLabel("Next week")
                }

                Button(action: onStartNext) {
                    Label("Start Week \(highestWeek + 1)", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent) // VERIFY: Liquid Glass prominent button style
                .tint(Palette.molten)
                .disabled(!atHighest)
            }
        }
    }
}

// MARK: - Superset header

private struct SupersetHeader: View {
    let group: String

    var body: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.molten)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.uppercased())
                        .font(.subheadline.weight(.bold))
                        .kerning(0.5)
                        .foregroundStyle(Palette.molten)
                    Text("Do these back to back, rest after the pair.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Exercise card

private struct ExerciseCardView: View {
    let exercise: Exercise
    let currentWeek: Int
    let recordFor: (Int, String, Int) -> GymSetRecord?
    let fetchOrCreate: (Int, String, Int) -> GymSetRecord
    let save: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    private var thisWeekVolume: Double {
        (0..<exercise.sets).reduce(0.0) { acc, i in
            let r = recordFor(currentWeek, exercise.id, i)
            return acc + Stats.setVolume(weightKg: r?.weightKg, reps: r?.reps)
        }
    }

    private var lastWeekVolume: Double {
        (0..<exercise.sets).reduce(0.0) { acc, i in
            let r = recordFor(currentWeek - 1, exercise.id, i)
            return acc + Stats.setVolume(weightKg: r?.weightKg, reps: r?.reps)
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                header

                if expanded {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(exercise.form)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Label(exercise.cue, systemImage: "lightbulb.fill")
                            .font(.callout)
                            .foregroundStyle(Palette.gold)
                    }
                }

                if let note = exercise.progressionNote {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Divider().overlay(Color.white.opacity(0.08))

                // Column captions
                HStack {
                    Text("").frame(width: 52, alignment: .leading)
                    Text("Weight (kg)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                    Text("Reps")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<exercise.sets, id: \.self) { setIndex in
                    SetRowView(
                        setIndex: setIndex,
                        current: recordFor(currentWeek, exercise.id, setIndex),
                        lastWeek: recordFor(currentWeek - 1, exercise.id, setIndex),
                        onCommit: { weightKg, reps in
                            // Skip creating an empty record for an untouched set.
                            let existing = recordFor(currentWeek, exercise.id, setIndex)
                            if existing == nil && weightKg == nil && reps == nil { return }
                            let record = fetchOrCreate(currentWeek, exercise.id, setIndex)
                            record.weightKg = weightKg
                            record.reps = reps
                            save()
                        }
                    )
                    .id("\(currentWeek)-\(exercise.id)-\(setIndex)")
                }

                HStack {
                    Text("vs last week")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    DeltaLabel(value: thisWeekVolume - lastWeekVolume, unit: " kg", goodWhenPositive: true)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.headline)
                Text("\(exercise.sets) × \(exercise.repScheme)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if reduceMotion {
                    expanded.toggle()
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .rotationEffect(.degrees(expanded ? 180 : 0))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glass) // VERIFY
            .accessibilityLabel(expanded ? "Hide form for \(exercise.name)" : "Show form for \(exercise.name)")
        }
    }
}

// MARK: - Set row

private struct SetRowView: View {
    let setIndex: Int
    let current: GymSetRecord?
    let lastWeek: GymSetRecord?
    let onCommit: (Double?, Int?) -> Void

    @State private var weightText: String
    @State private var repsText: String

    init(
        setIndex: Int,
        current: GymSetRecord?,
        lastWeek: GymSetRecord?,
        onCommit: @escaping (Double?, Int?) -> Void
    ) {
        self.setIndex = setIndex
        self.current = current
        self.lastWeek = lastWeek
        self.onCommit = onCommit
        _weightText = State(initialValue: current?.weightKg.map { AppFormat.kg($0) } ?? "")
        _repsText = State(initialValue: current?.reps.map(String.init) ?? "")
    }

    private var parsedWeight: Double? {
        let trimmed = weightText.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : Double(trimmed)
    }

    private var parsedReps: Int? {
        let trimmed = repsText.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : Int(trimmed)
    }

    /// Ghost targets from last week (nil when there is no target).
    private var weightPlaceholder: String {
        lastWeek?.weightKg.map { AppFormat.kg($0) } ?? "—"
    }
    private var repsPlaceholder: String {
        lastWeek?.reps.map(String.init) ?? "—"
    }

    /// Molten when this set matches or beats last week's volume (needs a real target).
    private var beaten: Bool {
        let lastVol = Stats.setVolume(weightKg: lastWeek?.weightKg, reps: lastWeek?.reps)
        guard lastVol > 0 else { return false }
        let thisVol = Stats.setVolume(weightKg: parsedWeight, reps: parsedReps)
        return thisVol >= lastVol
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                if beaten {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(Palette.molten)
                }
                Text("Set \(setIndex + 1)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(beaten ? Palette.molten : .secondary)
            }
            .frame(width: 52, alignment: .leading)

            field(text: $weightText, placeholder: weightPlaceholder, keyboard: .decimalPad)
            field(text: $repsText, placeholder: repsPlaceholder, keyboard: .numberPad)
        }
        .onChange(of: weightText) { onCommit(parsedWeight, parsedReps) }
        .onChange(of: repsText) { onCommit(parsedWeight, parsedReps) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Set \(setIndex + 1)"
            + (beaten ? ", target beaten" : "")
            + ". Last week \(weightPlaceholder) kilograms for \(repsPlaceholder) reps."
        )
    }

    private func field(text: Binding<String>, placeholder: String, keyboard: UIKeyboardType) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.statSmall(20))
            .foregroundStyle(beaten ? Palette.molten : .primary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(beaten ? Palette.molten.opacity(0.14) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(beaten ? Palette.molten.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - Session total

private struct SessionTotalCard: View {
    let thisWeekVolume: Double
    let lastWeekVolume: Double

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Session Total")
                HStack(alignment: .firstTextBaseline) {
                    Text(AppFormat.kg(thisWeekVolume, decimals: 0))
                        .font(.stat(40))
                        .contentTransition(.numericText())
                    Text("kg")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    DeltaLabel(value: thisWeekVolume - lastWeekVolume, unit: " kg", goodWhenPositive: true)
                }
                Text("Total volume this day vs last week.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LiftView()
        .modelContainer(for: [
            GymSetRecord.self, KbLogRecord.self, FoodEntryRecord.self,
            WeightEntryRecord.self, AppSettings.self
        ], inMemory: true)
}
