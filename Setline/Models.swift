import Foundation

enum LoadUnit: String, Codable, CaseIterable, Identifiable {
    case kg, lb
    var id: Self { self }
    var increment: Double { self == .kg ? 2.5 : 5 }
    var startingWeight: Double { self == .kg ? 20 : 45 }

    func kilograms(_ value: Double) -> Double {
        self == .kg ? value : value * 0.45359237
    }

    func display(_ kilograms: Double) -> Double {
        let value = self == .kg ? kilograms : kilograms / 0.45359237
        return (value * 100).rounded() / 100
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var liftKey: String {
        trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}

struct JournalSnapshot: Codable, Equatable {
    var routines: [Routine] = []
    var sessions: [WorkoutSession] = []
    var tasks: [DailyTask] = []
    var selectedDay: String?
    var meals: [Meal] = []
    var nutrition: [String: DailyNutrition] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: CodingKeys.self)
        routines = try data.decode([Routine].self, forKey: .routines)
        sessions = try data.decode([WorkoutSession].self, forKey: .sessions)
        tasks = try data.decode([DailyTask].self, forKey: .tasks)
        selectedDay = try data.decodeIfPresent(String.self, forKey: .selectedDay)
        meals = try data.decodeIfPresent([Meal].self, forKey: .meals) ?? []
        nutrition = try data.decodeIfPresent([String: DailyNutrition].self, forKey: .nutrition) ?? [:]
    }
}

struct Routine: Codable, Identifiable, Equatable {
    private(set) var id = UUID()
    var name: String
    var sortOrder: Int
    var exercises: [RoutineExercise] = []

    var ordered: [RoutineExercise] { exercises.sorted { $0.sortOrder < $1.sortOrder } }

    init(name: String, sortOrder: Int) {
        self.name = name
        self.sortOrder = sortOrder
    }
}

struct RoutineExercise: Codable, Identifiable, Equatable {
    private(set) var id = UUID()
    var exerciseName: String
    var sortOrder: Int
    var preferredUnit: LoadUnit
    var defaultIncrement: Double

    init(name: String, order: Int, unit: LoadUnit) {
        exerciseName = name
        sortOrder = order
        preferredUnit = unit
        defaultIncrement = unit.increment
    }
}

struct WorkoutSession: Codable, Identifiable, Equatable {
    private(set) var id = UUID()
    var routineName: String
    var startedAt: Date
    var completedAt: Date?
    var isActive = true
    var selectedLiftID: UUID?
    var lifts: [ExerciseDraft] = []
    var sets: [LoggedSet] = []
    var assignedDay: String?
    var customWorkout: Bool?

    var isCustom: Bool { customWorkout == true }
    var dayKey: String { assignedDay ?? TrainingDay.key(startedAt) }
    var completedSets: [LoggedSet] { sets.filter { $0.isTarget != true } }

    var ordered: [ExerciseDraft] { lifts.sorted { $0.sortOrder < $1.sortOrder } }
    var selected: ExerciseDraft? { lifts.first { $0.id == selectedLiftID } ?? ordered.first }

    func entries(for lift: ExerciseDraft) -> [LoggedSet] {
        sets.filter { $0.liftID == lift.id }.sorted { $0.setNumber < $1.setNumber }
    }

    init(name: String, now: Date = .now) {
        routineName = name
        startedAt = now
    }
}

// Workouts keep their own order and drafts even if their routine changes.
struct ExerciseDraft: Codable, Identifiable, Equatable {
    private(set) var id = UUID()
    var name: String
    var sortOrder: Int
    var preferredUnit: LoadUnit
    var defaultIncrement: Double
    var unit: LoadUnit
    var draftKilograms: Double
    var draftReps = 8

    var increment: Double { unit == preferredUnit ? defaultIncrement : unit.increment }

    init(name: String, order: Int, unit: LoadUnit, increment: Double) {
        self.name = name
        sortOrder = order
        preferredUnit = unit
        defaultIncrement = increment
        self.unit = unit
        draftKilograms = unit.kilograms(unit.startingWeight)
    }
}

struct LoggedSet: Codable, Identifiable, Equatable {
    private(set) var id = UUID()
    var exerciseName: String
    var liftID: UUID
    var setNumber: Int
    var weight: Double
    var reps: Int
    var unit: LoadUnit
    var loggedAt = Date.now
    // Older journals contain only performed sets.
    var isTarget: Bool?

    var kilograms: Double { unit.kilograms(weight) }
    var summary: String {
        "\(weight.formatted(.number.precision(.fractionLength(0...2)))) \(unit.rawValue) × \(reps)"
    }

    init(lift: ExerciseDraft, number: Int) {
        exerciseName = lift.name
        liftID = lift.id
        setNumber = number
        weight = lift.unit.display(lift.draftKilograms)
        reps = lift.draftReps
        unit = lift.unit
    }
}

struct DailyTask: Codable, Identifiable, Equatable {
    private(set) var id = UUID()
    var title: String
    var isCompleted = false
    var createdAt = Date.now
    var completedAt: Date?

    init(title: String) {
        self.title = title
    }
}
