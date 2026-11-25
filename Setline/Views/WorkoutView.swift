import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject private var journal: Journal
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    let sessionID: UUID
    @State private var adding = false
    @State private var finishing = false
    @State private var editing: LoggedSet?
    @State private var failure: String?

    var body: some View {
        if let session = journal.workout(sessionID) {
            content(session)
        }
    }

    private func content(_ session: WorkoutSession) -> some View {
        GeometryReader { geometry in
            let inline = typeSize.isAccessibilitySize || geometry.size.height < 400
            List {
                if let lift = session.selected {
                    let lastSets = journal.lastSets(named: lift.name)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lift.name).font(.title2.bold())
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                        Text("Last time").font(.caption.bold()).foregroundStyle(Style.mint)
                            .accessibilityIdentifier("last-session-reference")
                        if lastSets.isEmpty {
                            Text("First session with this exercise").font(.subheadline).foregroundStyle(Style.muted)
                        } else {
                            ScrollView(.horizontal) {
                                HStack(spacing: 8) {
                                    ForEach(lastSets) { previous in
                                        Button {
                                            change {
                                                try journal.updateDraft(lift.id, in: sessionID) {
                                                    $0.draftKilograms = previous.kilograms
                                                    $0.draftReps = previous.reps
                                                }
                                            }
                                        } label: {
                                            Text(previous.summary).font(.subheadline.monospacedDigit())
                                                .padding(.horizontal, 12).frame(minHeight: 44)
                                                .background(Style.card, in: Capsule())
                                        }.buttonStyle(.plain)
                                            .accessibilityIdentifier("last-set-\(previous.setNumber)")
                                            .accessibilityHint("Use for the next set")
                                    }
                                }
                            }.scrollIndicators(.hidden)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).workoutRow()
                }
                SpotifyBar().workoutRow()
                if let lift = session.selected {
                    let entries = session.entries(for: lift)
                    HStack {
                        SectionTitle(text: "Logged sets")
                        if let last = entries.last {
                            Button {
                                change { try journal.remove(last.id, from: sessionID) }
                            } label: {
                                Label("Undo", systemImage: "arrow.uturn.backward").font(.subheadline)
                                    .frame(minHeight: 44)
                            }.buttonStyle(.plain).accessibilityLabel("Undo Last Set")
                        }
                    }.workoutRow()
                    if entries.isEmpty {
                        Text("No sets yet").font(.subheadline).foregroundStyle(Style.muted).workoutRow()
                    }
                    ForEach(entries) { entry in
                        Button { editing = entry } label: {
                            HStack(spacing: 10) {
                                SetLine(entry: entry)
                                Image(systemName: "pencil").font(.caption).foregroundStyle(Style.muted)
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityHint("Edit set")
                            .accessibilityLabel("Set \(entry.setNumber), \(entry.summary)")
                            .accessibilityIdentifier("logged-set-\(entry.setNumber)")
                            .padding(.horizontal, 14).background(Style.card, in: RoundedRectangle(cornerRadius: 12))
                            .workoutRow().swipeActions {
                                Button("Delete", role: .destructive) {
                                    change { try journal.remove(entry.id, from: sessionID) }
                                }
                            }
                    }
                } else {
                    EmptyState("Choose your first exercise", systemImage: "dumbbell",
                                           description: "Your sets will appear here as you log them.").workoutRow()
                }
                if inline { console(for: session).workoutRow() }
            }
            .listSurface()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !inline { console(for: session).padding(.horizontal, 16).padding(.vertical, 6).background(.black) }
            }
        }
        .navigationTitle(session.routineName).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                IconControl(title: "Back to Today", icon: "chevron.down") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Finish") { finishing = true }
                    .frame(minHeight: 44)
                    .accessibilityLabel("Finish Workout")
                    .accessibilityIdentifier("finish-workout")
            }
        }
        .confirmationDialog("Finish this workout?", isPresented: $finishing, titleVisibility: .visible) {
            Button("Finish Workout") { change { try journal.finish(sessionID); dismiss() } }
            Button("Keep logging", role: .cancel) {}
        }
        .onAppear { Haptics.prepare() }
        .sheet(isPresented: $adding) { QuickLiftSheet(sessionID: sessionID) }
        .sheet(item: $editing) { entry in
            if let lift = session.lifts.first(where: { $0.id == entry.liftID }) {
                EditSetSheet(entry: entry, lift: lift, sessionID: sessionID)
            }
        }
        .reporting($failure)
    }

    private func console(for session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let lift = session.selected {
                let currentDraft = {
                    journal.workout(sessionID)?.lifts.first { $0.id == lift.id } ?? lift
                }
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(session.ordered) { item in
                                Button {
                                    change { try journal.selectLift(item.id, in: sessionID) }
                                } label: {
                                    Text(item.name).font(.subheadline.weight(.semibold)).padding(.horizontal, 12)
                                        .frame(minHeight: 44)
                                        .foregroundStyle(item.id == lift.id ? Style.mint : Style.muted)
                                        .background(Style.card, in: Capsule())
                                        .overlay { Capsule().strokeBorder(item.id == lift.id ? Style.mint : Style.line) }
                                }.buttonStyle(.plain).id(item.id)
                                    .accessibilityAddTraits(item.id == lift.id ? .isSelected : [])
                            }
                            IconControl(title: "Add exercise", icon: "plus") { adding = true }
                        }
                    }.scrollIndicators(.hidden)
                        .onAppear { proxy.scrollTo(lift.id, anchor: .center) }
                        .onChange(of: lift.id) { id in proxy.scrollTo(id, anchor: .center) }
                }
                HStack {
                    Text("Set \(session.entries(for: lift).count + 1)").font(.title2.bold()).monospacedDigit()
                    Spacer()
                    UnitSwitch(selection: Binding(get: { currentDraft().unit }, set: { unit in
                        change { try journal.updateDraft(lift.id, in: sessionID) { $0.unit = unit } }
                    }))
                }
                SetControls(unit: lift.unit, increment: lift.increment,
                            kilograms: Binding(get: { currentDraft().draftKilograms }, set: { value in
                                change { try journal.updateDraft(lift.id, in: sessionID) { $0.draftKilograms = value } }
                            }),
                            reps: Binding(get: { currentDraft().draftReps }, set: { value in
                                change { try journal.updateDraft(lift.id, in: sessionID) { $0.draftReps = value } }
                            }))
                PrimaryButton(title: "Log Set", icon: "plus") {
                    do {
                        try withAnimation(Style.motion) { try journal.log(lift.id, in: sessionID) }
                        Haptics.success()
                    } catch { failure = error.localizedDescription }
                }
            } else {
                PrimaryButton(title: "Choose exercise", icon: "plus") { adding = true }
            }
        }
    }

    private func change(_ action: () throws -> Void) {
        do {
            try withAnimation(Style.motion, action)
            Haptics.tap()
        } catch { failure = error.localizedDescription }
    }
}

private struct QuickLiftSheet: View {
    @EnvironmentObject private var journal: Journal
    @Environment(\.dismiss) private var dismiss
    let sessionID: UUID
    @State private var unit = LoadUnit.kg
    @State private var failure: String?
    private let common = ["Back squat", "Bench press", "Deadlift", "Overhead press", "Dumbbell row",
                          "Pull-up", "Lat pulldown", "Leg press", "Biceps curl", "Triceps extension"]

    private var choices: [String] {
        let lifts = journal.workout(sessionID)?.lifts ?? []
        var used = Set(lifts.map { $0.name.liftKey })
        let saved = journal.snapshot.routines.flatMap(\.exercises).map(\.exerciseName).sorted()
        return (saved + common).filter { used.insert($0.liftKey).inserted }
    }

    var body: some View {
        NavigationStack {
            List {
                HStack { Text("Weight unit"); Spacer(); UnitSwitch(selection: $unit) }.workoutRow()
                ForEach(choices, id: \.self) { name in
                    Button {
                        do {
                            try journal.addLift(named: name, unit: unit, to: sessionID)
                            dismiss()
                        } catch { failure = error.localizedDescription }
                    } label: {
                        HStack { Text(name); Spacer(); Image(systemName: "plus") }
                            .frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel(name).workoutRow()
                }
                if choices.isEmpty { Text("All available exercises are in this workout.").workoutRow() }
            }.listSurface().navigationTitle("Choose exercise").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .reporting($failure)
        }.presentationDetents([.medium, .large])
    }
}
