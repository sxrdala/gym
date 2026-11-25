import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject private var journal: Journal
    private var routines: [Routine] { journal.snapshot.routines.sorted { $0.sortOrder < $1.sortOrder } }
    @State private var adding = false
    @State private var failure: String?

    var body: some View {
        List {
            if routines.isEmpty {
                EmptyState("No routines yet", systemImage: "square.stack.3d.up",
                                       description: "Group your exercises in the order you train.")
                    .panelRow()
            }
            ForEach(routines) { routine in
                NavigationLink { RoutineDetail(routineID: routine.id) } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(routine.name).font(.headline)
                        Text("\(routine.exercises.count) exercises").font(.subheadline).foregroundStyle(Style.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading).panel()
                }.panelRow().swipeActions {
                    Button("Delete", role: .destructive) {
                        do { try journal.deleteRoutine(routine.id) }
                        catch { failure = error.localizedDescription }
                    }
                }
            }
        }
        .listSurface().navigationTitle("Routines")
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Create routine", icon: "plus") { adding = true }
                .padding(18).background(.black)
        }
        .sheet(isPresented: $adding) {
            NameSheet("Create routine", prompt: "Routine name", save: journal.createRoutine)
        }.reporting($failure)
    }
}

private struct RoutineDetail: View {
    @EnvironmentObject private var journal: Journal
    let routineID: UUID
    @State private var rename = false
    @State private var adding = false
    @State private var failure: String?

    var body: some View {
        if let routine = journal.snapshot.routines.first(where: { $0.id == routineID }) {
            detail(routine)
        }
    }

    private func detail(_ routine: Routine) -> some View {
        List {
            if routine.exercises.isEmpty {
                EmptyState("Add an exercise", systemImage: "dumbbell",
                                       description: "Choose the name and weight unit for each lift.")
                    .panelRow()
            }
            ForEach(routine.ordered) { exercise in
                HStack(spacing: 14) {
                    Text((exercise.sortOrder + 1).formatted(.number.precision(.integerLength(2))))
                        .font(.subheadline.monospacedDigit()).foregroundStyle(Style.muted)
                    Text(exercise.exerciseName).font(.headline)
                    Spacer()
                    Menu {
                        ForEach(LoadUnit.allCases) { unit in
                            Button(unit.rawValue) {
                                do {
                                    try journal.updateRoutine(routineID) { draft in
                                        guard let index = draft.exercises.firstIndex(where: { $0.id == exercise.id })
                                        else { throw JournalError.missing }
                                        draft.exercises[index].preferredUnit = unit
                                        draft.exercises[index].defaultIncrement = unit.increment
                                    }
                                } catch { failure = error.localizedDescription }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(exercise.preferredUnit.rawValue)
                            Image(systemName: "chevron.down").font(.caption)
                        }.frame(minWidth: 44, minHeight: 44)
                    }.accessibilityLabel("Weight unit for \(exercise.exerciseName)")
                }.panel().panelRow()
            }
            .onMove { from, to in
                do {
                    try journal.updateRoutine(routineID) { draft in
                        var order = draft.ordered
                        order.move(fromOffsets: from, toOffset: to)
                        draft.exercises = renumber(order)
                    }
                } catch { failure = error.localizedDescription }
            }
            .onDelete { offsets in
                do {
                    try journal.updateRoutine(routineID) { draft in
                        var order = draft.ordered
                        order.remove(atOffsets: offsets)
                        draft.exercises = renumber(order)
                    }
                } catch { failure = error.localizedDescription }
            }
        }
        .listSurface().navigationTitle(routine.name)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                IconControl(title: "Rename routine", icon: "pencil") { rename = true }
                EditButton()
            }
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Add exercise", icon: "plus") { adding = true }
                .padding(18).background(.black)
        }
        .sheet(isPresented: $rename) {
            NameSheet("Rename routine", prompt: "Routine name", initial: routine.name) { name in
                try journal.updateRoutine(routineID) { $0.name = name }
            }
        }
        .sheet(isPresented: $adding) { NewExercise(routineID: routineID) }
        .reporting($failure)
    }

    private func renumber(_ order: [RoutineExercise]) -> [RoutineExercise] {
        var exercises = order
        for index in exercises.indices { exercises[index].sortOrder = index }
        return exercises
    }
}

private struct NewExercise: View {
    @EnvironmentObject private var journal: Journal
    @Environment(\.dismiss) private var dismiss
    let routineID: UUID
    @State private var name = ""
    @State private var unit = LoadUnit.kg
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                TextField("Exercise name", text: $name).submitLabel(.done).onSubmit(add).panel()
                UnitSwitch(selection: $unit)
                PrimaryButton(title: "Add exercise", icon: "plus", action: add)
                    .disabled(name.trimmed.isEmpty).opacity(name.trimmed.isEmpty ? 0.45 : 1)
                Spacer()
            }.padding(18).navigationTitle("New exercise").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .reporting($failure)
        }.presentationDetents([.medium, .large])
    }

    private func add() {
        guard !name.trimmed.isEmpty else { return }
        do {
            try journal.updateRoutine(routineID) { routine in
                guard !routine.exercises.contains(where: { $0.exerciseName.liftKey == name.liftKey })
                else { throw JournalError.duplicate }
                routine.exercises.append(RoutineExercise(name: name.trimmed, order: routine.exercises.count, unit: unit))
            }
            dismiss()
        } catch { failure = error.localizedDescription }
    }
}
