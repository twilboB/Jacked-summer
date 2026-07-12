import Foundation

/// Whether an exercise is performed on its own or as part of a superset pair.
enum SetStyle: Equatable {
    case straight
    /// Part of a labelled superset group (e.g. "Superset A").
    case superset(group: String)
}

/// A single exercise definition (static content, not persisted).
struct Exercise: Identifiable, Equatable {
    let id: String
    let name: String
    let sets: Int
    let repScheme: String
    let form: String
    let cue: String
    let style: SetStyle
    /// "Add reps before weight" style progression hint, shown when present.
    let progressionNote: String?

    init(
        id: String,
        name: String,
        sets: Int,
        repScheme: String,
        form: String,
        cue: String,
        style: SetStyle = .straight,
        progressionNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.repScheme = repScheme
        self.form = form
        self.cue = cue
        self.style = style
        self.progressionNote = progressionNote
    }
}

/// A training day: an ordered list of exercises.
struct LiftDay: Identifiable {
    let id: Int          // 1 or 2
    let title: String
    let exercises: [Exercise]
}

enum LiftContent {
    static let days: [LiftDay] = [day1, day2]

    static func day(_ n: Int) -> LiftDay { n == 2 ? day2 : day1 }

    // MARK: Day 1 — chest / shoulders / biceps
    static let day1 = LiftDay(
        id: 1,
        title: "Day 1",
        exercises: [
            Exercise(
                id: "d1_incline_db_press",
                name: "Incline DB Press",
                sets: 3,
                repScheme: "8–10",
                form: "Bench at about 30°, press two dumbbells from shoulder level up and slightly together, lower under control to the upper chest with elbows around 45°, not flared straight out.",
                cue: "Drive the chest up to the dumbbells, not the dumbbells to the ceiling."
            ),
            Exercise(
                id: "d1_lateral_raise",
                name: "Lateral Raise",
                sets: 3,
                repScheme: "12–15",
                form: "Slight fixed bend in the elbows, raise out to the sides to shoulder height leading with the elbows, lower slowly, no swinging.",
                cue: "Lead with your elbows and pour the jug, pinkies a touch higher than thumbs.",
                style: .superset(group: "Superset A"),
                progressionNote: "Add reps before weight here."
            ),
            Exercise(
                id: "d1_db_curl",
                name: "DB Curl",
                sets: 3,
                repScheme: "10–12",
                form: "Elbows pinned to your sides, curl up while rotating the pinky toward you, squeeze at the top, lower slowly to a full stretch.",
                cue: "Pin the elbows, turn the pinky up at the top, no swing.",
                style: .superset(group: "Superset A")
            ),
            Exercise(
                id: "d1_dumbbell_flye",
                name: "Dumbbell Flye",
                sets: 3,
                repScheme: "12–15",
                form: "Lie on a flat bench with the dumbbells pressed above the chest, soft fixed elbows, lower them out to the sides in a wide arc until you feel a stretch across the chest, then bring them back together over the chest. Dumbbells only, no cable machine.",
                cue: "Hug a barrel, keep the elbows soft, big stretch then squeeze."
            ),
        ]
    )

    // MARK: Day 2 — chest / shoulders / biceps
    static let day2 = LiftDay(
        id: 2,
        title: "Day 2",
        exercises: [
            Exercise(
                id: "d2_flat_press_or_dips",
                name: "Flat Press or Weighted Dips",
                sets: 3,
                repScheme: "8–10",
                form: "Press with blades pulled back and down into the bench, lower to mid chest, press from that stable base. Dips: lean the torso forward, elbows tracking back, lower to a chest stretch then press.",
                cue: "Pull your shoulder blades together and down and keep them there the whole set."
            ),
            Exercise(
                id: "d2_seated_db_shoulder_press",
                name: "Seated DB Shoulder Press",
                sets: 3,
                repScheme: "8–10",
                form: "Back supported, press the dumbbells overhead from ear height, stop just short of locking them together, lower under control.",
                cue: "Ribs down, do not arch the lower back, press straight up the centreline."
            ),
            Exercise(
                id: "d2_lateral_raise",
                name: "Lateral Raise",
                sets: 3,
                repScheme: "12–15",
                form: "Slight fixed bend in the elbows, raise out to the sides to shoulder height leading with the elbows, lower slowly.",
                cue: "Lead with your elbows and pour the jug.",
                style: .superset(group: "Superset B"),
                progressionNote: "Add reps before weight here."
            ),
            Exercise(
                id: "d2_incline_or_hammer_curl",
                name: "Incline or Hammer Curl",
                sets: 3,
                repScheme: "10–12",
                form: "Incline: sit back so the arms hang behind the body for a stretch then curl. Hammer: neutral grip, curl, control the lower.",
                cue: "Let the arms hang back for the stretch, no swing, own the negative.",
                style: .superset(group: "Superset B")
            ),
        ]
    )
}
