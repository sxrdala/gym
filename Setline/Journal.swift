import Combine
import Foundation

enum JournalError: String, LocalizedError {
    case blank = "Enter a name to save."
    case duplicate = "This exercise is already on the list."
    case finished = "This workout has already finished."
    case missing = "This item is no longer available."
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
        snapshot.sessions.filter(\.isActive).max { $0.startedAt < $1.startedAt }
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
            let entries = session.sets.filter { $0.exerciseName.liftKey == key }
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

    func start(_ routine: Routine?) throws -> WorkoutSession {
        if let activeWorkout { return activeWorkout }
        var session = WorkoutSession(name: routine?.name ?? "Quick workout")
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
            let lift = ExerciseDraft(name: name, order: session.lifts.count, unit: unit, increment: unit.increment)
            session.lifts.append(prefilled(lift, entries: []))
            session.selectedLiftID = lift.id
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
            session.sets.append(LoggedSet(lift: lift, number: number))
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
}
