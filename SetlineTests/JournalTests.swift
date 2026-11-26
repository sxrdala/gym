import XCTest
@testable import GymBlox

final class JournalTests: XCTestCase {
    @MainActor
    private func withDisk(_ test: (JournalStore) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try test(JournalStore(url: directory.appendingPathComponent("journal.json")))
    }

    @MainActor
    func testReopenRestoresTwoCommittedSetsAndDraft() throws {
        try withDisk { store in
            let writer = Journal(store: store)
            let sessionID = try writer.start(nil).id
            XCTAssertEqual(try store.load().sessions.first?.id, sessionID)
            try writer.addLift(named: "Bench press", unit: .kg, to: sessionID)
            let liftID = try XCTUnwrap(writer.activeWorkout?.selected?.id)
            try writer.log(liftID, in: sessionID)
            XCTAssertEqual(try store.load().sessions.first?.sets.count, 1)
            try writer.updateDraft(liftID, in: sessionID) {
                $0.draftKilograms = 22.5
                $0.draftReps = 7
            }
            try writer.log(liftID, in: sessionID)
            try writer.updateDraft(liftID, in: sessionID) { $0.draftReps = 6 }

            let reader = Journal(store: store)
            let restored = try XCTUnwrap(reader.activeWorkout)
            let lift = try XCTUnwrap(restored.selected)
            let entries = restored.entries(for: lift)
            XCTAssertEqual(restored.id, sessionID)
            XCTAssertEqual(lift.id, liftID)
            XCTAssertEqual(entries.map(\.setNumber), [1, 2])
            XCTAssertEqual(entries.map(\.weight), [20, 22.5])
            XCTAssertEqual(entries.map(\.reps), [8, 7])
            XCTAssertEqual(entries.map(\.unit), [.kg, .kg])
            XCTAssertEqual(lift.draftReps, 6)
            XCTAssertEqual(try reader.start(nil).id, sessionID)
            XCTAssertEqual(try store.load(), writer.snapshot)
        }
    }

    @MainActor
    func testEditDeleteUndoAndFinishAreImmediatelyVisible() throws {
        try withDisk { store in
            let writer = Journal(store: store)
            let sessionID = try writer.start(nil).id
            try writer.addLift(named: "Squat", unit: .lb, to: sessionID)
            let liftID = try XCTUnwrap(writer.activeWorkout?.selected?.id)
            try writer.log(liftID, in: sessionID)
            try writer.log(liftID, in: sessionID)
            let entries = try XCTUnwrap(writer.activeWorkout?.sets)
            let second = entries[1]
            try writer.edit(second.id, in: sessionID, kilograms: 50, reps: 4, unit: .kg)
            let edited = Journal(store: store).activeWorkout?.sets
            let editCopy = try XCTUnwrap(edited?.first { $0.id == second.id })
            XCTAssertEqual(editCopy.weight, 50)
            XCTAssertEqual(editCopy.reps, 4)
            XCTAssertEqual(editCopy.unit, .kg)

            try writer.remove(entries[0].id, from: sessionID)
            let afterDelete = try XCTUnwrap(Journal(store: store).activeWorkout?.sets)
            XCTAssertEqual(afterDelete.map(\.id), [second.id])
            XCTAssertEqual(afterDelete.map(\.setNumber), [1])
            try writer.log(liftID, in: sessionID)
            let lastID = try XCTUnwrap(writer.activeWorkout?.sets.last?.id)
            try writer.remove(lastID, from: sessionID)
            XCTAssertEqual(Journal(store: store).activeWorkout?.sets.map(\.id), [second.id])

            try writer.finish(sessionID)
            let reader = Journal(store: store)
            XCTAssertNil(reader.activeWorkout)
            let history = try XCTUnwrap(reader.history.first)
            XCTAssertNotNil(history.completedAt)
            XCTAssertEqual(history.sets.count, 1)
        }
    }

    @MainActor
    func testTaskChangesSaveOnEachTap() throws {
        try withDisk { store in
            let writer = Journal(store: store)
            try writer.createTask("Pack belt")
            let task = try XCTUnwrap(store.load().tasks.first)
            for expected in [true, false] {
                try writer.toggleTask(task.id)
                let copy = try XCTUnwrap(store.load().tasks.first)
                XCTAssertEqual(copy.id, task.id)
                XCTAssertEqual(copy.isCompleted, expected)
                XCTAssertEqual(copy.completedAt != nil, expected)
            }
            try writer.deleteTask(task.id)
            XCTAssertTrue(try store.load().tasks.isEmpty)
        }
    }

    @MainActor
    func testPrefillUsesLatestMatchingSessionThenCurrentSet() throws {
        try withDisk { store in
            let writer = Journal(store: store)
            for loads in [[30.0], [80.0, 82.5]] {
                let sessionID = try writer.start(nil).id
                try writer.addLift(named: "Bench press", unit: .kg, to: sessionID)
                let liftID = try XCTUnwrap(writer.activeWorkout?.selected?.id)
                for (index, weight) in loads.enumerated() {
                    try writer.updateDraft(liftID, in: sessionID) {
                        $0.draftKilograms = weight
                        $0.draftReps = 8 - index
                    }
                    try writer.log(liftID, in: sessionID)
                }
                try writer.finish(sessionID)
            }
            let unrelatedID = try writer.start(nil).id
            try writer.addLift(named: "Curl", unit: .kg, to: unrelatedID)
            try writer.log(try XCTUnwrap(writer.activeWorkout?.selected?.id), in: unrelatedID)
            try writer.finish(unrelatedID)

            let currentID = try writer.start(nil).id
            try writer.addLift(named: "BENCH PRESS", unit: .lb, to: currentID)
            let first = try XCTUnwrap(writer.activeWorkout?.selected)
            XCTAssertEqual(first.unit.display(first.draftKilograms), 176.37)
            XCTAssertEqual(first.draftReps, 8)
            try writer.log(first.id, in: currentID)
            let second = try XCTUnwrap(writer.activeWorkout?.selected)
            XCTAssertEqual(second.draftKilograms, 82.5, accuracy: 0.0001)
            XCTAssertEqual(second.draftReps, 7)
            try writer.updateDraft(first.id, in: currentID) {
                $0.draftKilograms = LoadUnit.lb.kilograms(190)
                $0.draftReps = 5
            }
            try writer.log(first.id, in: currentID)
            let third = try XCTUnwrap(writer.activeWorkout?.selected)
            XCTAssertEqual(third.unit.display(third.draftKilograms), 190)
            XCTAssertEqual(third.draftReps, 5)

            try writer.addLift(named: "Row", unit: .lb, to: currentID)
            let row = try XCTUnwrap(writer.activeWorkout?.selected)
            XCTAssertEqual(row.unit.display(row.draftKilograms), 45)
            XCTAssertEqual(row.draftReps, 8)
        }
    }

    @MainActor
    func testRoutineOrderAndSelectedExerciseSurviveTemplateDeletion() throws {
        try withDisk { store in
            let writer = Journal(store: store)
            try writer.createRoutine("Upper")
            let id = try XCTUnwrap(writer.snapshot.routines.first?.id)
            try writer.updateRoutine(id) {
                $0.exercises = [RoutineExercise(name: "Row", order: 1, unit: .kg),
                                RoutineExercise(name: "Press", order: 0, unit: .lb)]
            }
            let session = try writer.start(writer.snapshot.routines.first)
            let rowID = try XCTUnwrap(session.ordered.last?.id)
            try writer.selectLift(rowID, in: session.id)
            try writer.deleteRoutine(id)
            let reader = Journal(store: store)
            let restored = try XCTUnwrap(reader.activeWorkout)
            XCTAssertEqual(restored.ordered.map(\.name), ["Press", "Row"])
            XCTAssertEqual(restored.ordered.map(\.unit), [.lb, .kg])
            XCTAssertEqual(restored.selected?.id, rowID)
            XCTAssertTrue(reader.snapshot.routines.isEmpty)
        }
    }

    @MainActor
    func testFailedCommitKeepsPublishedSnapshotAndPreviousFile() throws {
        try withDisk { store in
            let writer = Journal(store: store)
            let sessionID = try writer.start(nil).id
            try writer.addLift(named: "Bench press", unit: .kg, to: sessionID)
            let liftID = try XCTUnwrap(writer.activeWorkout?.selected?.id)
            try writer.log(liftID, in: sessionID)
            let saved = writer.snapshot
            let bytes = try Data(contentsOf: store.url)
            XCTAssertThrowsError(try writer.updateDraft(liftID, in: sessionID) { $0.draftKilograms = .infinity })
            XCTAssertEqual(writer.snapshot, saved)
            XCTAssertEqual(try Data(contentsOf: store.url), bytes)

            let backup = store.url.appendingPathExtension("backup")
            try FileManager.default.moveItem(at: store.url, to: backup)
            try FileManager.default.createDirectory(at: store.url, withIntermediateDirectories: false)
            XCTAssertThrowsError(try writer.log(liftID, in: sessionID))
            XCTAssertEqual(writer.snapshot, saved)
            XCTAssertEqual(try Data(contentsOf: backup), bytes)
        }
    }

    @MainActor
    func testCorruptStoreSurfacesErrorAndStaysIntact() throws {
        try withDisk { store in
            let corrupt = Data("invalid json".utf8)
            try corrupt.write(to: store.url)
            let writer = Journal(store: store)
            XCTAssertFalse(writer.isOpen)
            XCTAssertNotNil(writer.openingError)
            XCTAssertThrowsError(try writer.start(nil))
            XCTAssertEqual(try Data(contentsOf: store.url), corrupt)
        }
    }

    func testConversionAndDisplayPrecision() {
        XCTAssertEqual(LoadUnit.lb.kilograms(1), 0.45359237, accuracy: 1e-10)
        XCTAssertEqual(LoadUnit.lb.display(20), 44.09)
        XCTAssertEqual(LoadUnit.kg.display(LoadUnit.lb.kilograms(45)), 20.41)
        for unit in LoadUnit.allCases {
            for value in [0.0, 2.5, 45.0, 82.75, 123.45] {
                XCTAssertEqual(unit.display(unit.kilograms(value)), value, accuracy: 0.000001)
            }
        }
    }

    @MainActor
    func testThirtyDayCalendarAndDateBoundWorkouts() throws {
        let days = TrainingDay.days
        let keys = days.map(TrainingDay.key)
        XCTAssertEqual(keys.count, 30)
        XCTAssertEqual(Set(keys).count, 30)
        XCTAssertEqual(keys.first, "2026-11-25")
        XCTAssertEqual(keys.last, "2026-12-24")
        for (first, second) in zip(days, days.dropFirst()) {
            XCTAssertEqual(TrainingDay.calendar.dateComponents([.day], from: first, to: second).day, 1)
        }
        try withDisk { store in
            let journal = Journal(store: store)
            let quick = try journal.start(nil, on: days[0])
            let push = try journal.createWorkout(named: " Push Day A ", on: days[29])
            try journal.selectDay(days[29])
            let recovered = Journal(store: store)
            XCTAssertEqual(recovered.selectedDay, days[29])
            XCTAssertEqual(recovered.sessions(on: days[29]).map(\.routineName), ["Push Day A"])
            XCTAssertEqual(recovered.sessions(on: days[29]).first?.id, push.id)
            XCTAssertEqual(recovered.sessions(on: days[0]).first?.id, quick.id)
            XCTAssertTrue(recovered.sessions(on: days[1]).isEmpty)
            XCTAssertEqual(recovered.activeWorkout?.id, quick.id)
        }
    }

    @MainActor
    func testCustomExercisesCommitTwoIndependentTargetsAndPerformedState() throws {
        try withDisk { store in
            let journal = Journal(store: store)
            let id = try journal.createWorkout(named: "Upper", on: TrainingDay.days[5]).id
            for name in ["Row", "Press"] { try journal.addLift(named: name, unit: .kg, to: id) }
            let saved = try XCTUnwrap(store.load().sessions.first)
            XCTAssertEqual(saved.ordered.map(\.name), ["Row", "Press"])
            for lift in saved.ordered {
                XCTAssertEqual(saved.entries(for: lift).map(\.setNumber), [1, 2])
            }
            XCTAssertTrue(saved.completedSets.isEmpty)
            let row = saved.ordered[0]
            let targets = saved.entries(for: row)
            try journal.edit(targets[0].id, in: id, kilograms: 32.5, reps: 9, unit: .kg)
            try journal.edit(targets[1].id, in: id, kilograms: 35, reps: 6, unit: .kg)
            try journal.togglePerformed(targets[1].id, in: id)
            let copy = try XCTUnwrap(Journal(store: store).workout(id))
            XCTAssertEqual(copy.entries(for: row).map(\.weight), [32.5, 35])
            XCTAssertEqual(copy.entries(for: row).map(\.reps), [9, 6])
            XCTAssertEqual(copy.completedSets.map(\.id), [targets[1].id])
            try journal.log(row.id, in: id)
            try journal.remove(targets[0].id, from: id)
            try journal.finish(id)
            XCTAssertEqual(journal.lastSets(named: "Row").map(\.id), [targets[1].id])
            XCTAssertEqual(journal.history.first?.entries(for: row).map(\.setNumber), [1, 2])
        }
    }

    @MainActor
    func testMealsTotalsDayGoalsAndDeletionRecoverFromDisk() throws {
        try withDisk { store in
            let journal = Journal(store: store)
            let day = TrainingDay.days[6], other = TrainingDay.days[7]
            let meal = Meal(name: "Chicken & Rice Bowl",
                            nutrients: Nutrients(calories: 510, protein: 41, carbs: 55, fats: 14))
            let goals = Nutrients(calories: 2100, protein: 130, carbs: 240, fats: 68)
            try journal.saveMeal(meal)
            try journal.saveGoals(goals, on: day)
            try journal.logMeal(meal, on: day)
            try journal.logMeal(meal, on: day)
            try journal.logMeal(meal, on: other)
            let reader = Journal(store: store)
            XCTAssertEqual(reader.snapshot.meals, [meal])
            let first = reader.nutrition(on: day)
            XCTAssertEqual(first.goals, goals)
            XCTAssertEqual(first.consumed, Nutrients(calories: 1020, protein: 82, carbs: 110, fats: 28))
            XCTAssertEqual(first.entries.count, 2)
            XCTAssertNotEqual(first.entries[0].id, first.entries[1].id)
            XCTAssertEqual(TrainingDay.key(first.entries[0].loggedAt), TrainingDay.key(day))
            XCTAssertEqual(reader.nutrition(on: other).goals, .defaultGoals)
            try reader.deleteFood(first.entries[0].id, on: day)
            let reopened = Journal(store: store)
            XCTAssertEqual(reopened.nutrition(on: day).consumed, meal.nutrients)
            XCTAssertEqual(reopened.nutrition(on: other).consumed, meal.nutrients)
            XCTAssertEqual(reopened.snapshot.meals, [meal])
        }
    }

    @MainActor
    func testPreUpgradeJournalOpensAndSurvivesNewWrites() throws {
        try withDisk { store in
            let writer = Journal(store: store)
            let session = try writer.start(nil)
            try writer.addLift(named: "Row", unit: .kg, to: session.id)
            try writer.log(try XCTUnwrap(writer.activeWorkout?.selectedLiftID), in: session.id)
            try writer.createTask("Pack shoes")
            var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: store.url)) as? [String: Any])
            var sessions = try XCTUnwrap(legacy["sessions"] as? [[String: Any]])
            sessions[0].removeValue(forKey: "assignedDay")
            legacy["sessions"] = sessions
            legacy.removeValue(forKey: "meals")
            legacy.removeValue(forKey: "nutrition")
            try JSONSerialization.data(withJSONObject: legacy).write(to: store.url)
            let reader = Journal(store: store)
            XCTAssertTrue(reader.isOpen)
            XCTAssertEqual(reader.activeWorkout?.dayKey, TrainingDay.key(session.startedAt))
            XCTAssertEqual(reader.activeWorkout?.completedSets.count, 1)
            try reader.selectDay(TrainingDay.days[0])
            XCTAssertEqual(try store.load().tasks.map(\.title), ["Pack shoes"])
        }
    }
}
