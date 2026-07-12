import SwiftUI
import SwiftData

/// Root shell: the system Liquid Glass tab bar over the warm base.
/// Tabs in order: Lift, Bells, Food, Body.
struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Lift", systemImage: "dumbbell.fill") {
                LiftView()
            }
            Tab("Bells", systemImage: "flame.fill") {
                BellsView()
            }
            Tab("Food", systemImage: "fork.knife") {
                FoodView()
            }
            Tab("Body", systemImage: "figure") {
                BodyView()
            }
        }
    }
}

/// Shared chrome: the warm gradient behind a scrolling stack of glass cards.
/// Content scrolls behind the floating bars (soft scroll-edge effect).
struct ScreenScaffold<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(WarmBaseBackground())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

/// Small helper to fetch-or-create the single settings row.
enum SettingsStore {
    static func current(_ context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = AppSettings()
        context.insert(created)
        return created
    }
}

#Preview {
    ContentView()
        .environment(AIAvailability())
        .modelContainer(for: [
            GymSetRecord.self, KbLogRecord.self, FoodEntryRecord.self,
            WeightEntryRecord.self, AppSettings.self
        ], inMemory: true)
}
