import Foundation

/// Which benchmark, if any, a kettlebell day captures.
enum KbBenchmark: Equatable {
    case none
    /// Max unbroken swings, higher is better.
    case swings
    /// Complex time in seconds, lower is better.
    case complexTime
}

struct KbDay: Identifiable {
    let id: Int          // 1...7
    let name: String
    let formatTag: String
    let prescription: String
    let benchmark: KbBenchmark
}

enum KettlebellContent {
    static let days: [KbDay] = [
        KbDay(
            id: 1,
            name: "Swing EMOM Ladder",
            formatTag: "EMOM · 24 min",
            prescription: "Warm up 3 minutes, then a 24 minute EMOM. Odd minutes: 15 heavy swings. Even minutes: 6 cleans each side. Every 6th minute: max unbroken swings. Finish with 3 minutes of hollow holds and planks.",
            benchmark: .swings
        ),
        KbDay(
            id: 2,
            name: "Gym A + KB Press & Core",
            formatTag: "Gym day · 5 rounds",
            prescription: "Full body barbell session, then 5 rounds resting 60 seconds: 5 strict presses each side, 6 push presses each side, suitcase hold 40 seconds each side, 30 second hollow hold.",
            benchmark: .none
        ),
        KbDay(
            id: 3,
            name: "Halo + Press Density",
            formatTag: "E2MOM · 20 min",
            prescription: "Every 2 minutes for 20 minutes (10 rounds): 5 kneeling halos each direction, 5 strict presses each side. Finisher 8 minutes: alternating swings and goblet squats, 30 seconds on and 15 off.",
            benchmark: .none
        ),
        KbDay(
            id: 4,
            name: "Complex Chipper",
            formatTag: "5 rounds for time",
            prescription: "5 rounds for time resting 60 seconds between rounds: 8 cleans each side, 8 front squats, 8 push presses each side, 12 swings.",
            benchmark: .complexTime
        ),
        KbDay(
            id: 5,
            name: "Gym B + KB Push, Pull & Core",
            formatTag: "Gym day · 6 rounds",
            prescription: "Full body barbell session, then 6 rounds resting 60 seconds: 6 single arm presses each side, 8 bent over rows each side, 8 push presses each side, overhead hold 30 seconds each side.",
            benchmark: .none
        ),
        KbDay(
            id: 6,
            name: "Snatch & Squat Intervals",
            formatTag: "5 × 4 min",
            prescription: "5 rounds of 4 minutes with 1 minute rest, the hardest day: 8 snatches each side, 10 goblet squats, 10 swings.",
            benchmark: .none
        ),
        KbDay(
            id: 7,
            name: "Grind & Core Strength",
            formatTag: "4 rounds heavy",
            prescription: "4 rounds, heavy, full rest, tension over heart rate: 5 kneeling halos each direction, suitcase hold 45 seconds each side, 5 tempo front squats (5 seconds down), max goblet squat hold.",
            benchmark: .none
        ),
    ]

    static func day(_ n: Int) -> KbDay { days[max(0, min(6, n - 1))] }

    /// Programming note shown on the Bells tab.
    static let programmingNote = "Keep the heavy ballistic days (1, 4, 6) clear of gym days so the posterior chain is fresh. If recovery trends down three weeks running, turn one kettlebell day into a walk."

    /// Milestone thresholds (days) for the badge track.
    static let milestones = [3, 7, 14, 30, 60, 100]
}
