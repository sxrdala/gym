import Combine
import Foundation

enum JournalError: String, LocalizedError {
    case blank = "Enter a name to save."
    case duplicate = "This exercise is already on the list."
    case finished = "This workout has already finished."
    case missing = "This item is no longer available."
    case nutrients = "Enter whole numbers from 0 to 99,999. Each daily goal must be at least 1."
    case invalid = "Check the values and try again."
    case playlist = "Enter a Spotify playlist URI."
    case calendar = "Today is outside the training calendar."
    var errorDescription: String? { rawValue }
}

@MainActor
final class Journal: ObservableObject {
    @Published private(set) var snapshot = JournalSnapshot()
    @Published private(set) var isOpen = false
    @Published private(set) var openingError: String?
    private let store: JournalStore

    init(store: JournalStore) {
        self.store = store
        open()
    }

    func open() {
        guard !isOpen else { return }
        do {
            snapshot = try store.load()
            openingError = nil
            isOpen = true
        } catch {
            openingError = error.localizedDescription
        }
    }

    var activeWorkout: WorkoutSession? {
        snapshot.sessions.filter { $0.isActive && !$0.isCustom }.max { $0.startedAt < $1.startedAt }
    }

    func workout(_ id: UUID) -> WorkoutSession? {
        snapshot.sessions.first { $0.id == id }
    }

    var history: [WorkoutSession] {
        snapshot.sessions.filter { !$0.isActive }.sorted {
            ($0.completedAt ?? $0.startedAt) > ($1.completedAt ?? $1.startedAt)
        }
    }

    func lastSets(named name: String) -> [LoggedSet] {
        let key = name.liftKey
        for session in history where session.completedAt != nil {
            let entries = session.completedSets.filter { $0.exerciseName.liftKey == key }
            if !entries.isEmpty { return entries.sorted { $0.setNumber < $1.setNumber } }
        }
        return []
    }

    // Publish only after the disk write succeeds.
    private func commit(_ change: (inout JournalSnapshot) throws -> Void) throws {
        guard isOpen else { throw JournalError.missing }
        var candidate = snapshot
        try change(&candidate)
        try store.save(candidate)
        snapshot = candidate
    }

    var selectedDay: Date { TrainingDay.selection(snapshot.selectedDay) }

    func selectDay(_ day: Date) throws {
        let key = TrainingDay.key(day)
        guard TrainingDay.days.contains(where: { TrainingDay.key($0) == key }) else { throw JournalError.missing }
        try commit { $0.selectedDay = key }
    }

    func sessions(on day: Date) -> [WorkoutSession] {
        let key = TrainingDay.key(day)
        return snapshot.sessions.filter { $0.dayKey == key }
    }

    func createWorkout(named name: String, on day: Date) throws -> WorkoutSession {
        guard !name.trimmed.isEmpty else { throw JournalError.blank }
        var session = WorkoutSession(name: name.trimmed)
        session.assignedDay = TrainingDay.key(day)
        session.customWorkout = true
        try commit { $0.sessions.append(session) }
        return session
    }

    func start(_ routine: Routine?, on day: Date? = nil) throws -> WorkoutSession {
        if let activeWorkout { return activeWorkout }
        var session = WorkoutSession(name: routine?.name ?? "Quick workout")
        session.assignedDay = TrainingDay.key(day ?? session.startedAt)
        session.lifts = (routine?.ordered ?? []).map { exercise in
            let lift = ExerciseDraft(name: exercise.exerciseName, order: exercise.sortOrder,
                                     unit: exercise.preferredUnit, increment: exercise.defaultIncrement)
            return prefilled(lift, entries: [])
        }
        session.selectedLiftID = session.ordered.first?.id
        try commit { $0.sessions.append(session) }
        return session
    }

    private func updateWorkout(_ id: UUID, _ change: (inout WorkoutSession) throws -> Void) throws {
        try commit { candidate in
            guard let index = candidate.sessions.firstIndex(where: { $0.id == id }),
                  candidate.sessions[index].isActive else { throw JournalError.finished }
            try change(&candidate.sessions[index])
        }
    }

    func addLift(named name: String, unit: LoadUnit, to sessionID: UUID) throws {
        let name = name.trimmed
        guard !name.isEmpty else { throw JournalError.blank }
        try updateWorkout(sessionID) { session in
            guard !session.lifts.contains(where: { $0.name.liftKey == name.liftKey }) else { throw JournalError.duplicate }
            let weightUnit = session.isCustom ? snapshot.defaults.unit : unit
            let increment = session.isCustom ? snapshot.defaults.increment : unit.increment
            let lift = prefilled(ExerciseDraft(name: name, order: session.lifts.count,
                                               unit: weightUnit, increment: increment), entries: [])
            session.lifts.append(lift)
            session.selectedLiftID = lift.id
            if session.isCustom {
                for number in 1...snapshot.defaults.sets {
                    var entry = LoggedSet(lift: lift, number: number)
                    entry.isTarget = true
                    session.sets.append(entry)
                }
            }
        }
    }

    func selectLift(_ liftID: UUID, in sessionID: UUID) throws {
        try updateWorkout(sessionID) { session in
            guard session.lifts.contains(where: { $0.id == liftID }) else { throw JournalError.missing }
            session.selectedLiftID = liftID
        }
    }

    func updateDraft(_ liftID: UUID, in sessionID: UUID, _ change: (inout ExerciseDraft) -> Void) throws {
        try updateWorkout(sessionID) { session in
            let index = try liftIndex(liftID, in: session)
            change(&session.lifts[index])
        }
    }

    func log(_ liftID: UUID, in sessionID: UUID) throws {
        try updateWorkout(sessionID) { session in
            let index = try liftIndex(liftID, in: session)
            let lift = session.lifts[index]
            let number = session.entries(for: lift).count + 1
            var entry = LoggedSet(lift: lift, number: number)
            if session.isCustom { entry.isTarget = true }
            session.sets.append(entry)
            refreshDraft(at: index, in: &session)
        }
    }

    func edit(_ setID: UUID, in sessionID: UUID, kilograms: Double, reps: Int, unit: LoadUnit) throws {
        try updateWorkout(sessionID) { session in
            guard let index = session.sets.firstIndex(where: { $0.id == setID }) else { throw JournalError.missing }
            let draftIndex = try liftIndex(session.sets[index].liftID, in: session)
            session.sets[index].weight = unit.display(kilograms)
            session.sets[index].unit = unit
            session.sets[index].reps = reps
            refreshDraft(at: draftIndex, in: &session)
        }
    }

    func togglePerformed(_ setID: UUID, in sessionID: UUID) throws {
        try updateWorkout(sessionID) { session in
            guard session.isCustom, let index = session.sets.firstIndex(where: { $0.id == setID })
            else { throw JournalError.missing }
            session.sets[index].isTarget = session.sets[index].isTarget != true
            if session.sets[index].isTarget == false { session.sets[index].loggedAt = .now }
        }
    }

    func remove(_ setID: UUID, from sessionID: UUID) throws {
        try updateWorkout(sessionID) { session in
            guard let index = session.sets.firstIndex(where: { $0.id == setID }) else { throw JournalError.missing }
            let removed = session.sets.remove(at: index)
            let draftIndex = try liftIndex(removed.liftID, in: session)
            for position in session.sets.indices where session.sets[position].liftID == removed.liftID {
                if session.sets[position].setNumber > removed.setNumber {
                    session.sets[position].setNumber -= 1
                }
            }
            refreshDraft(at: draftIndex, in: &session)
        }
    }

    private func liftIndex(_ id: UUID, in session: WorkoutSession) throws -> Int {
        guard let index = session.lifts.firstIndex(where: { $0.id == id }) else { throw JournalError.missing }
        return index
    }

    private func refreshDraft(at index: Int, in session: inout WorkoutSession) {
        let lift = session.lifts[index]
        session.lifts[index] = prefilled(lift, entries: session.entries(for: lift))
    }

    private func prefilled(_ lift: ExerciseDraft, entries: [LoggedSet]) -> ExerciseDraft {
        var draft = lift
        let previous = lastSets(named: lift.name)
        if let reference = previous.first(where: { $0.setNumber == entries.count + 1 }) ?? entries.last {
            draft.draftKilograms = reference.kilograms
            draft.draftReps = reference.reps
        } else {
            draft.draftKilograms = lift.unit.kilograms(lift.unit.startingWeight)
            draft.draftReps = 8
        }
        return draft
    }

    func finish(_ sessionID: UUID) throws {
        try updateWorkout(sessionID) { session in
            session.completedAt = .now
            session.isActive = false
        }
    }

    func deleteFinished(_ id: UUID) throws {
        try commit { candidate in
            guard let index = candidate.sessions.firstIndex(where: { $0.id == id && !$0.isActive }) else {
                throw JournalError.missing
            }
            candidate.sessions.remove(at: index)
        }
    }

    func duplicateToToday(_ id: UUID, now: Date = .now) throws {
        let today = TrainingDay.key(now)
        guard TrainingDay.days.contains(where: { TrainingDay.key($0) == today }) else { throw JournalError.calendar }
        guard let source = workout(id), !source.isActive else { throw JournalError.missing }
        var copy = WorkoutSession(name: source.routineName, now: now)
        copy.customWorkout = true
        copy.assignedDay = today
        for old in source.ordered {
            var lift = ExerciseDraft(name: old.name, order: old.sortOrder, unit: old.preferredUnit, increment: old.defaultIncrement)
            lift.unit = old.unit
            lift.draftReps = old.draftReps
            lift.draftKilograms = old.draftKilograms
            copy.lifts.append(lift)
            for original in source.entries(for: old) {
                var entry = LoggedSet(lift: lift, number: original.setNumber)
                entry.reps = original.reps
                entry.weight = original.weight
                entry.unit = original.unit
                entry.isTarget = true
                copy.sets.append(entry)
            }
        }
        copy.selectedLiftID = copy.ordered.first?.id
        try commit {
            $0.sessions.append(copy)
            $0.selectedDay = today
        }
    }

    // Previously saved quick workouts keep their performed sets when opened in the card editor.
    func openInCardEditor(_ id: UUID) throws {
        guard let session = workout(id) else { throw JournalError.missing }
        if session.isActive && !session.isCustom {
            try updateWorkout(id) { $0.customWorkout = true }
        }
    }

    func savePreset(_ name: String, id: UUID? = nil) throws {
        guard !name.trimmed.isEmpty else { throw JournalError.blank }
        try commit { candidate in
            guard !candidate.presets.contains(where: { $0.id != id && $0.name.liftKey == name.liftKey })
            else { throw JournalError.duplicate }
            if let id {
                guard let i = candidate.presets.firstIndex(where: { $0.id == id }) else { throw JournalError.missing }
                candidate.presets[i].name = name.trimmed
            } else {
                candidate.presets.append(ExercisePreset(name: name.trimmed))
            }
        }
    }

    func deletePreset(_ id: UUID) throws {
        try commit { $0.presets.removeAll { $0.id == id } }
    }

    func saveDefaults(_ defaults: WorkoutDefaults) throws {
        guard (1...20).contains(defaults.sets), (0.25...100).contains(defaults.kgIncrement),
              (0.25...100).contains(defaults.lbIncrement) else { throw JournalError.invalid }
        try commit { $0.defaults = defaults }
    }

    func saveProfile(_ profile: AthleteProfile) throws {
        guard (1...600).contains(profile.weightKg), (30...300).contains(profile.heightCm),
              (1...200_000).contains(profile.stepGoal),
              profile.goals.values.allSatisfy({ (1...99_999).contains($0) }) else { throw JournalError.invalid }
        let key = TrainingDay.key(.now)
        try commit { candidate in
            if let steps = candidate.activity[key]?.steps {
                candidate.activity[key]?.steps = StepRecord(count: steps.count, weightKg: profile.weightKg)
            }
            if candidate.profile.goals != profile.goals {
                candidate.nutrition[TrainingDay.key(selectedDay)]?.goalOverride = nil
            }
            candidate.profile = profile
        }
    }

    func activity(on day: Date) -> DailyActivity {
        snapshot.activity[TrainingDay.key(day)] ?? DailyActivity()
    }

    func netCalories(on day: Date) -> Int {
        nutrition(on: day).consumed.calories - activity(on: day).burned
    }

    func recordSteps(_ count: Int, on day: Date) throws {
        guard (0...1_000_000).contains(count) else { throw JournalError.invalid }
        let previous = activity(on: day).steps
        let record = StepRecord(count: count, weightKg: previous?.weightKg ?? snapshot.profile.weightKg)
        if previous != record {
            try commit { $0.activity[TrainingDay.key(day), default: DailyActivity()].steps = record }
        }
    }

    func logCardio(_ name: String, minutes: Int, met: Double, on day: Date) throws {
        guard !name.trimmed.isEmpty else { throw JournalError.blank }
        guard (1...1440).contains(minutes), (0.1...40).contains(met) else { throw JournalError.invalid }
        let session = CardioSession(name: name.trimmed, minutes: minutes, met: met, weightKg: snapshot.profile.weightKg)
        try commit { $0.activity[TrainingDay.key(day), default: DailyActivity()].sessions.append(session) }
    }

    func deleteCardio(_ id: UUID, on day: Date) throws {
        try commit { $0.activity[TrainingDay.key(day)]?.sessions.removeAll { $0.id == id } }
    }

    func savePlaylist(name: String, uri: String) throws {
        guard !name.trimmed.isEmpty else { throw JournalError.blank }
        guard uri.trimmed.range(of: "^spotify:playlist:[A-Za-z0-9]{22}$", options: .regularExpression) != nil
        else { throw JournalError.playlist }
        try commit { $0.playlists.append(SavedPlaylist(name: name.trimmed, uri: uri.trimmed)) }
    }

    func deletePlaylist(_ id: UUID) throws {
        try commit { $0.playlists.removeAll { $0.id == id } }
    }

    func createRoutine(_ name: String) throws {
        guard !name.trimmed.isEmpty else { throw JournalError.blank }
        try commit { candidate in
            let order = (candidate.routines.map(\.sortOrder).max() ?? -1) + 1
            candidate.routines.append(Routine(name: name.trimmed, sortOrder: order))
        }
    }

    func updateRoutine(_ id: UUID, _ change: (inout Routine) throws -> Void) throws {
        try commit { candidate in
            guard let index = candidate.routines.firstIndex(where: { $0.id == id }) else { throw JournalError.missing }
            try change(&candidate.routines[index])
        }
    }

    func deleteRoutine(_ id: UUID) throws {
        try commit { $0.routines.removeAll { $0.id == id } }
    }

    func createTask(_ title: String) throws {
        guard !title.trimmed.isEmpty else { throw JournalError.blank }
        try commit { $0.tasks.append(DailyTask(title: title.trimmed)) }
    }

    func toggleTask(_ id: UUID) throws {
        try commit { candidate in
            guard let index = candidate.tasks.firstIndex(where: { $0.id == id }) else { throw JournalError.missing }
            candidate.tasks[index].isCompleted.toggle()
            candidate.tasks[index].completedAt = candidate.tasks[index].isCompleted ? .now : nil
        }
    }

    func deleteTask(_ id: UUID) throws {
        try commit { $0.tasks.removeAll { $0.id == id } }
    }

    func nutrition(on day: Date) -> DailyNutrition {
        var daily = snapshot.nutrition[TrainingDay.key(day)] ?? DailyNutrition()
        daily.goals = daily.goalOverride ?? snapshot.profile.goals
        return daily
    }

    func saveGoals(_ goals: Nutrients, on day: Date) throws {
        guard goals.values.allSatisfy({ (1...99_999).contains($0) }) else { throw JournalError.nutrients }
        try commit { $0.nutrition[TrainingDay.key(day), default: DailyNutrition()].goalOverride = goals }
    }

    private func validate(_ meal: Meal) throws {
        guard !meal.name.trimmed.isEmpty else { throw JournalError.blank }
        guard meal.nutrients.values.allSatisfy({ (0...99_999).contains($0) }) else { throw JournalError.nutrients }
    }

    func saveMeal(_ meal: Meal) throws {
        try validate(meal)
        try commit { $0.meals.append(meal) }
    }

    func logMeal(_ meal: Meal, on day: Date, at time: Date = .now) throws {
        try validate(meal)
        let calendar = TrainingDay.calendar
        let clock = calendar.dateComponents([.hour, .minute, .second], from: time)
        let loggedAt = calendar.date(bySettingHour: clock.hour!, minute: clock.minute!, second: clock.second!, of: day) ?? day
        try commit {
            $0.nutrition[TrainingDay.key(day), default: DailyNutrition()].entries
                .append(FoodEntry(meal: meal, loggedAt: loggedAt))
        }
    }

    func deleteFood(_ id: UUID, on day: Date) throws {
        try commit { $0.nutrition[TrainingDay.key(day)]?.entries.removeAll { $0.id == id } }
    }
}
