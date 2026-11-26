import Foundation

struct AthleteProfile: Codable, Equatable {
    var weightKg = 70.0
    var heightCm = 170.0
    var goals = Nutrients.defaultGoals
    var stepGoal = 10_000
}

struct WorkoutDefaults: Codable, Equatable {
    var sets = 2
    var unit = LoadUnit.kg
    var kgIncrement = 2.5
    var lbIncrement = 5.0
    var increment: Double { unit == .kg ? kgIncrement : lbIncrement }
}

struct ExercisePreset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String

    static func seeded(routines: [Routine] = []) -> [Self] {
        let common = ["Back squat", "Bench press", "Deadlift", "Overhead press", "Dumbbell row",
                      "Pull-up", "Lat pulldown", "Leg press", "Biceps curl", "Triceps extension"]
        var used = Set<String>()
        return (common + routines.flatMap(\.ordered).map(\.exerciseName)).compactMap {
            guard !$0.trimmed.isEmpty, used.insert($0.liftKey).inserted else { return nil }
            return Self(name: $0.trimmed)
        }
    }
}

struct StepRecord: Codable, Equatable {
    let count: Int
    let weightKg: Double
    let calories: Int

    init(count: Int, weightKg: Double) {
        self.count = count
        self.weightKg = weightKg
        // Estimated walking cost per step per kilogram.
        calories = Int((Double(count) * weightKg * 0.0005).rounded())
    }
}

struct CardioSession: Codable, Identifiable, Equatable {
    var id = UUID()
    let name: String
    let minutes: Int
    let met: Double
    let weightKg: Double
    let calories: Int

    init(name: String, minutes: Int, met: Double, weightKg: Double) {
        self.name = name
        self.minutes = minutes
        self.met = met
        self.weightKg = weightKg
        calories = Int((met * weightKg * Double(minutes) / 60).rounded())
    }
}

struct DailyActivity: Codable, Equatable {
    var steps: StepRecord?
    var sessions: [CardioSession] = []
    var burned: Int { (steps?.calories ?? 0) + sessions.reduce(0) { $0 + $1.calories } }
}

struct SavedPlaylist: Codable, Identifiable, Equatable {
    var id = UUID()
    let name: String
    let uri: String
}
