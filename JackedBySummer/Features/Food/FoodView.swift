import SwiftUI
import SwiftData
import FoundationModels
import UIKit
import PhotosUI
import Charts

// Tab 3 — Food. Calorie + protein tracking against a TDEE with a 500 kcal cut line.
// FoodView owns the Day/Week/Month segmented control and the shared selected date;
// each scope is a private subview. Charts live in this file.
//
// VERIFY against the iOS 27 SDK where noted: the `.glassProminent` button style,
// PhotosPicker transferable loading, Swift Charts `RuleMark` dashed strokes, and
// FoundationModels image attachment (used inside NutritionEstimator).

// MARK: - Root

struct FoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIAvailability.self) private var ai
    @Query(sort: \FoodEntryRecord.createdAt, order: .reverse) private var entries: [FoodEntryRecord]

    @State private var scope: FoodScope = .day
    @State private var selectedDate: Date = Date().startOfDay

    private var settings: AppSettings { SettingsStore.current(modelContext) }

    var body: some View {
        ScreenScaffold(title: "Food") {
            Picker("View", selection: $scope) {
                ForEach(FoodScope.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)

            switch scope {
            case .day:
                DayView(selectedDate: $selectedDate, entries: entries, settings: settings, ai: ai)
            case .week:
                WeekView(entries: entries, settings: settings)
            case .month:
                MonthView(entries: entries, settings: settings)
            }
        }
    }
}

enum FoodScope: String, CaseIterable, Identifiable {
    case day = "Day", week = "Week", month = "Month"
    var id: String { rawValue }
}

// MARK: - Day math helpers

private enum FoodMath {
    /// kcal per start-of-day, summed from the given entries.
    static func kcalByDay(_ entries: [FoodEntryRecord]) -> [Date: Int] {
        entries.reduce(into: [:]) { acc, e in
            acc[e.date.startOfDay, default: 0] += e.kcal
        }
    }
}

// MARK: - Day view

private struct DayView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedDate: Date
    let entries: [FoodEntryRecord]
    let settings: AppSettings
    let ai: AIAvailability

    private var today: Date { Date().startOfDay }
    private var isToday: Bool { selectedDate == today }

    private var dayEntries: [FoodEntryRecord] {
        entries.filter { $0.date.startOfDay == selectedDate }
    }

    var body: some View {
        VStack(spacing: 16) {
            navigator

            TotalsCard(totals: Stats.totals(of: dayEntries), settings: settings)

            if isToday {
                AddFoodCard(selectedDate: selectedDate, ai: ai)
            }

            entryList
        }
    }

    private var navigator: some View {
        HStack {
            Button {
                selectedDate = selectedDate.addingDays(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.glass)

            Spacer()

            VStack(spacing: 2) {
                Text(isToday ? "Today" : AppFormat.shortDate.string(from: selectedDate))
                    .font(.headline)
                if !isToday {
                    Button("Jump to today") { selectedDate = today }
                        .font(.caption)
                }
            }

            Spacer()

            Button {
                selectedDate = selectedDate.addingDays(1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.glass)
            .disabled(selectedDate >= today) // no future
        }
    }

    private var entryList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Logged")
            if dayEntries.isEmpty {
                GlassCard {
                    Text("Nothing logged yet.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            } else {
                GlassCard(padding: 8) {
                    VStack(spacing: 0) {
                        ForEach(dayEntries) { entry in
                            FoodRow(entry: entry) { delete(entry) }
                            if entry.id != dayEntries.last?.id {
                                Divider().opacity(0.15)
                            }
                        }
                    }
                }
            }
        }
    }

    private func delete(_ entry: FoodEntryRecord) {
        modelContext.delete(entry)
        try? modelContext.save()
    }
}

// MARK: - Totals card

private struct TotalsCard: View {
    let totals: Stats.DayTotals
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    @State private var editing = false

    private var cutLine: Int { settings.tdee - AppConstants.cutDeficit }
    private var leftToTDEE: Int { settings.tdee - totals.kcal }
    private var kcalFraction: Double {
        guard settings.tdee > 0 else { return 0 }
        return Double(totals.kcal) / Double(settings.tdee)
    }
    private var cutMarker: Double {
        guard settings.tdee > 0 else { return 0 }
        return Double(cutLine) / Double(settings.tdee)
    }
    private var proteinFraction: Double {
        guard settings.proteinTargetG > 0 else { return 0 }
        return Double(totals.protein) / Double(settings.proteinTargetG)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(totals.kcal)")
                            .font(.stat(52))
                            .contentTransition(.numericText())
                        Text("kcal consumed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(max(0, leftToTDEE))")
                            .font(.statSmall(24))
                            .foregroundStyle(leftToTDEE >= 0 ? Palette.green : Palette.red)
                        Text(leftToTDEE >= 0 ? "left to TDEE" : "over TDEE")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Calories vs TDEE, with the cut line marked.
                VStack(alignment: .leading, spacing: 4) {
                    MoltenProgressBar(fraction: kcalFraction, markerFraction: cutMarker)
                    HStack {
                        Text("TDEE \(settings.tdee)")
                        Spacer()
                        Text("Cut \(cutLine)")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }

                // Protein vs target.
                VStack(alignment: .leading, spacing: 4) {
                    MoltenProgressBar(fraction: proteinFraction)
                    HStack {
                        Text("Protein \(totals.protein)g")
                        Spacer()
                        Text("Target \(settings.proteinTargetG)g")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }

                HStack {
                    StatChip(value: "\(totals.carbs)", caption: "carbs g", tint: Palette.steel)
                    StatChip(value: "\(totals.fat)", caption: "fat g", tint: Palette.gold)
                }

                Button {
                    withAnimation { editing.toggle() }
                } label: {
                    Label(editing ? "Done" : "Edit targets", systemImage: "slider.horizontal.3")
                        .font(.caption)
                }
                .buttonStyle(.glass)

                if editing {
                    VStack(spacing: 8) {
                        LabeledContent("TDEE") {
                            TextField("TDEE", value: $settings.tdee, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Protein target (g)") {
                            TextField("Protein", value: $settings.proteinTargetG, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .font(.subheadline)
                    // Persist target edits as they change.
                    .onChange(of: settings.tdee) { _, _ in try? modelContext.save() }
                    .onChange(of: settings.proteinTargetG) { _, _ in try? modelContext.save() }
                }
            }
        }
    }
}

// MARK: - Add food card

private struct AddFoodCard: View {
    @Environment(\.modelContext) private var modelContext
    let selectedDate: Date
    let ai: AIAvailability

    // Text path
    @State private var descriptionText = ""

    // Photo path
    @State private var photoItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?

    // Camera path (photo / barcode / label)
    @State private var cameraPurpose: CameraPurpose?

    // AI request / result state
    @State private var lastRequest: EstimateRequest?
    @State private var heldPhoto: UIImage?          // kept only for opt-in escalation
    @State private var pendingEstimate: NutritionEstimate?
    @State private var pendingSource: FoodSource = .text
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Manual path (always available)
    @State private var manualName = ""
    @State private var manualKcal = ""
    @State private var manualProtein = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Add food")
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    if ai.isAvailable {
                        aiControls
                    } else {
                        Text(ai.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Estimating…").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    if let errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Palette.red)
                            Text(errorMessage).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            if lastRequest != nil {
                                Button("Retry") { if let r = lastRequest { perform(r) } }
                                    .font(.caption)
                            }
                        }
                    }

                    if let pendingEstimate {
                        EstimatePreview(
                            estimate: pendingEstimate,
                            canImprove: pendingEstimate.isLowConfidence && heldPhoto != nil,
                            onLog: { commitEstimate(pendingEstimate) },
                            onImprove: improve,
                            onDiscard: { self.pendingEstimate = nil }
                        )
                    }

                    Divider().opacity(0.15)
                    manualControls
                }
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                // VERIFY: PhotosPickerItem.loadTransferable(type:) on iOS 27.
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    pickedImage = img
                }
            }
        }
        .sheet(item: $cameraPurpose) { purpose in
            CameraPicker { image in
                guard let image else { return }
                switch purpose {
                case .photo:   perform(.photo(image))
                case .barcode: perform(.barcode(image))
                case .label:   perform(.label(image))
                }
            }
        }
    }

    // MARK: AI input controls

    @ViewBuilder private var aiControls: some View {
        // 1. Describe it
        VStack(alignment: .leading, spacing: 6) {
            TextField("Describe a meal…", text: $descriptionText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            Button {
                perform(.text(descriptionText))
            } label: {
                Label("Estimate", systemImage: "sparkles")
            }
            .buttonStyle(.glassProminent) // VERIFY: .glassProminent button style name (iOS 27).
            .disabled(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }

        // 2. Photo (library or camera)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Choose photo", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.glass)

                Button {
                    cameraPurpose = .photo
                } label: {
                    Label("Take photo", systemImage: "camera")
                }
                .buttonStyle(.glass)
            }
            if let pickedImage {
                HStack {
                    Image(uiImage: pickedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Button {
                        perform(.photo(pickedImage))
                    } label: {
                        Label("Estimate photo", systemImage: "sparkles")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(isLoading)
                }
            }
        }

        // 3 & 4. Scans
        HStack {
            Button {
                cameraPurpose = .barcode
            } label: {
                Label("Scan barcode", systemImage: "barcode.viewfinder")
            }
            .buttonStyle(.glass)

            Button {
                cameraPurpose = .label
            } label: {
                Label("Scan label", systemImage: "doc.text.viewfinder")
            }
            .buttonStyle(.glass)
        }
        .disabled(isLoading)
    }

    // MARK: Manual controls

    @ViewBuilder private var manualControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or log manually").font(.caption).foregroundStyle(.secondary)
            TextField("Name (optional)", text: $manualName)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("food.name")
            HStack {
                TextField("kcal", text: $manualKcal)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("food.kcal")
                TextField("protein g", text: $manualProtein)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("food.protein")
            }
            Button {
                logManual()
            } label: {
                Label("Log", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.glass)
            .accessibilityIdentifier("food.logManual")
            .disabled(!manualHasSomething)
        }
    }

    private var manualHasSomething: Bool {
        let hasName = !manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasKcal = Int(manualKcal) != nil
        let hasProtein = Int(manualProtein) != nil
        return hasName || hasKcal || hasProtein
    }

    // MARK: Actions

    private func perform(_ request: EstimateRequest) {
        lastRequest = request
        errorMessage = nil
        pendingEstimate = nil
        isLoading = true
        Task {
            do {
                let est: NutritionEstimate
                let source: FoodSource
                switch request {
                case .text(let t):
                    est = try await NutritionEstimator.estimate(text: t)
                    source = .text
                    heldPhoto = nil
                case .photo(let img):
                    est = try await NutritionEstimator.estimate(photo: img)
                    source = .photo
                    heldPhoto = img
                case .barcode(let img):
                    est = try await NutritionEstimator.estimate(barcodeImage: img)
                    source = .barcode
                    heldPhoto = img
                case .label(let img):
                    est = try await NutritionEstimator.estimate(labelImage: img)
                    source = .label
                    heldPhoto = img
                }
                pendingEstimate = est
                pendingSource = source
            } catch {
                errorMessage = "Couldn't estimate. \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    /// Opt-in network escalation. Only reachable when we still hold the photo.
    private func improve() {
        guard let img = heldPhoto else { return }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                pendingEstimate = try await NutritionEstimator.escalate(photo: img)
            } catch {
                errorMessage = "Couldn't improve estimate. \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func commitEstimate(_ estimate: NutritionEstimate) {
        let entry = estimate.makeEntry(date: selectedDate, source: pendingSource, now: Date())
        modelContext.insert(entry)
        try? modelContext.save()
        resetAI()
    }

    private func logManual() {
        guard manualHasSomething else { return }
        let name = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = FoodEntryRecord(
            date: selectedDate.startOfDay,
            name: name.isEmpty ? "Food" : name,
            kcal: Int(manualKcal) ?? 0,
            protein: Int(manualProtein) ?? 0,
            carbs: 0,
            fat: 0,
            note: "",
            confidence: "",
            source: FoodSource.manual.rawValue,
            createdAt: Date()
        )
        modelContext.insert(entry)
        try? modelContext.save()
        manualName = ""; manualKcal = ""; manualProtein = ""
    }

    private func resetAI() {
        pendingEstimate = nil
        descriptionText = ""
        pickedImage = nil
        photoItem = nil
        heldPhoto = nil
        lastRequest = nil
    }
}

private enum EstimateRequest {
    case text(String)
    case photo(UIImage)
    case barcode(UIImage)
    case label(UIImage)
}

private enum CameraPurpose: Int, Identifiable {
    case photo, barcode, label
    var id: Int { rawValue }
}

// MARK: - Estimate preview

private struct EstimatePreview: View {
    let estimate: NutritionEstimate
    let canImprove: Bool
    let onLog: () -> Void
    let onImprove: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(estimate.name.isEmpty ? "Estimate" : estimate.name)
                    .font(.headline)
                Spacer()
                ConfidenceTag(confidence: estimate.confidence)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(estimate.calories)")
                    .font(.stat(30))
                Text("P\(estimate.protein)  C\(estimate.carbs)  F\(estimate.fat)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !estimate.note.isEmpty {
                Text(estimate.note)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            HStack {
                Button {
                    onLog()
                } label: {
                    Label("Log", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.glassProminent)

                if canImprove {
                    Button {
                        onImprove()
                    } label: {
                        Label("Improve estimate", systemImage: "cloud.bolt")
                    }
                    .buttonStyle(.glass)
                }

                Spacer()

                Button(role: .cancel) {
                    onDiscard()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.glass)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Food row

private struct FoodRow: View {
    let entry: FoodEntryRecord
    let onDelete: () -> Void

    private var source: FoodSource? { FoodSource(rawValue: entry.source) }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.name.isEmpty ? "Food" : entry.name)
                        .font(.subheadline.weight(.medium))
                    if let source, source.showsMarker {
                        SourceMarker(source: source)
                    }
                    if !entry.confidence.isEmpty {
                        ConfidenceTag(confidence: entry.confidence)
                    }
                }
                Text("P\(entry.protein)  C\(entry.carbs)  F\(entry.fat)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(entry.kcal)")
                .font(.statSmall())
                .foregroundStyle(.primary)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Palette.red)
            .labelsHidden()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        // Deletion is via the inline trash button above. (A .swipeActions modifier
        // here would be inert: these rows live in a VStack, not a List.)
    }
}

// MARK: - Week view

private struct WeekView: View {
    let entries: [FoodEntryRecord]
    let settings: AppSettings

    private var bars: [DayBar] {
        let byDay = FoodMath.kcalByDay(entries)
        let start = Date().startOfDay
        return (0..<7).reversed().map { offset in
            let day = start.addingDays(-offset)
            return DayBar(
                date: day,
                label: AppFormat.weekdayInitial.string(from: day),
                kcal: byDay[day] ?? 0
            )
        }
    }

    private var average: Double {
        guard !bars.isEmpty else { return 0 }
        return Double(bars.reduce(0) { $0 + $1.kcal }) / Double(bars.count)
    }

    private var cutLine: Int { settings.tdee - AppConstants.cutDeficit }

    var body: some View {
        VStack(spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(Int(average.rounded()))")
                                .font(.stat(40))
                            Text("daily avg, last 7 days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        // Under TDEE is good, so goodWhenPositive: false.
                        DeltaLabel(value: average - Double(settings.tdee), unit: " kcal", goodWhenPositive: false)
                    }

                    CalorieChart(
                        bars: bars,
                        tdee: settings.tdee,
                        cutLine: cutLine,
                        xLabel: { $0.label }
                    )
                    .frame(height: 220)
                }
            }
        }
    }
}

// MARK: - Month view

private struct MonthView: View {
    let entries: [FoodEntryRecord]
    let settings: AppSettings

    /// Six week buckets of 7 days each, most recent last. Value = daily average.
    private var bars: [DayBar] {
        let byDay = FoodMath.kcalByDay(entries)
        let start = Date().startOfDay
        return (0..<6).reversed().map { weekOffset in
            let weekEnd = start.addingDays(-7 * weekOffset)
            let weekStart = weekEnd.addingDays(-6)
            let total = (0..<7).reduce(0) { sum, d in
                sum + (byDay[weekStart.addingDays(d)] ?? 0)
            }
            let avg = Int((Double(total) / 7.0).rounded())
            return DayBar(
                date: weekStart,
                label: AppFormat.weekdayInitial.string(from: weekStart), // week marker
                kcal: avg
            )
        }
    }

    /// 30-day average across the last 30 calendar days.
    private var thirtyDayAverage: Double {
        let byDay = FoodMath.kcalByDay(entries)
        let start = Date().startOfDay
        let total = (0..<30).reduce(0) { sum, d in
            sum + (byDay[start.addingDays(-d)] ?? 0)
        }
        return Double(total) / 30.0
    }

    private var cutLine: Int { settings.tdee - AppConstants.cutDeficit }

    var body: some View {
        VStack(spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(Int(thirtyDayAverage.rounded()))")
                                .font(.stat(40))
                            Text("daily avg, last 30 days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        DeltaLabel(value: thirtyDayAverage - Double(settings.tdee), unit: " kcal", goodWhenPositive: false)
                    }

                    CalorieChart(
                        bars: bars,
                        tdee: settings.tdee,
                        cutLine: cutLine,
                        xLabel: { AppFormat.shortDate.string(from: $0.date) }
                    )
                    .frame(height: 220)
                }
            }
        }
    }
}

// MARK: - Chart

private struct DayBar: Identifiable {
    let date: Date
    let label: String
    let kcal: Int
    var id: Date { date }
}

/// Shared bar chart with solid TDEE and dashed cut-line reference marks.
private struct CalorieChart: View {
    let bars: [DayBar]
    let tdee: Int
    let cutLine: Int
    let xLabel: (DayBar) -> String

    var body: some View {
        Chart {
            ForEach(bars) { bar in
                BarMark(
                    x: .value("Day", xLabel(bar)),
                    y: .value("kcal", bar.kcal)
                )
                .foregroundStyle(Palette.moltenGradient) // VERIFY: gradient foregroundStyle on BarMark.
                .cornerRadius(4)
            }

            RuleMark(y: .value("TDEE", tdee))
                .foregroundStyle(Palette.steel)
                .lineStyle(StrokeStyle(lineWidth: 1))
                .annotation(position: .top, alignment: .leading) {
                    Text("TDEE").font(.caption2).foregroundStyle(Palette.steel)
                }

            RuleMark(y: .value("Cut", cutLine))
                .foregroundStyle(Palette.green)
                // VERIFY: dashed StrokeStyle on RuleMark in Swift Charts (iOS 27).
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .annotation(position: .bottom, alignment: .leading) {
                    Text("Cut").font(.caption2).foregroundStyle(Palette.green)
                }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}

// MARK: - Preview

#Preview {
    FoodView()
        .environment(AIAvailability())
        .modelContainer(for: [
            GymSetRecord.self, KbLogRecord.self, FoodEntryRecord.self,
            WeightEntryRecord.self, AppSettings.self
        ], inMemory: true)
}
