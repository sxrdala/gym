import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject private var journal: Journal
    @Environment(\.dismiss) private var dismiss
    let sessionID: UUID
    @State private var adding = false
    @State private var finishing = false
    @State private var collapsed: Set<UUID> = []
    @State private var editing: LoggedSet?
    @State private var failure: String?

    var body: some View {
        if let session = journal.workout(sessionID) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(session.ordered) { lift in
                            card(lift, in: session).id(lift.id)
                        }
                    }.padding(14)
                }.onChange(of: session.selectedLiftID) { id in
                    if let id { withAnimation(Style.motion) { proxy.scrollTo(id, anchor: .top) } }
                }
            }
            .navigationTitle(session.routineName).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                if session.isActive {
                    ToolbarItem(placement: .confirmationAction) { Button("Finish") { finishing = true } }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if session.isActive {
                    PrimaryButton(title: "Add exercise", icon: "plus") { adding = true }
                        .padding(.horizontal, 16).padding(.vertical, 6).background(Color.black)
                }
            }
            .sheet(isPresented: $adding) { ExercisePicker(sessionID: sessionID) }
            .sheet(item: $editing) { entry in
                if let lift = session.lifts.first(where: { $0.id == entry.liftID }) {
                    EditSetSheet(entry: entry, lift: lift, sessionID: sessionID)
                }
            }
            .confirmationDialog("Finish workout?", isPresented: $finishing, titleVisibility: .visible) {
                Button("Finish workout") { change { try journal.finish(sessionID); dismiss() } }
                Button("Cancel", role: .cancel) {}
            }.reporting($failure)
        }
    }

    private func card(_ lift: ExerciseDraft, in session: WorkoutSession) -> some View {
        let entries = session.entries(for: lift)
        let closed = collapsed.contains(lift.id)
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(Style.motion) {
                    if closed { collapsed.remove(lift.id) } else { collapsed.insert(lift.id) }
                }
                Haptics.tap()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(lift.name).font(.headline)
                        if closed {
                            Text(summary(entries, unit: lift.unit)).font(.caption).foregroundStyle(Style.muted)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down").rotationEffect(.degrees(closed ? -90 : 0))
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityValue(closed ? "Collapsed" : "Expanded")
                .accessibilityIdentifier("exercise-\(lift.name)")
            if !closed {
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        Divider()
                        HStack(spacing: 4) {
                            IconControl(title: entry.isTarget == true ? "Mark performed" : "Mark pending",
                                        icon: entry.isTarget == true ? "circle" : "checkmark.circle.fill") {
                                change { try journal.togglePerformed(entry.id, in: sessionID) }
                            }.disabled(!session.isActive)
                            Text("Set \(entry.setNumber)").font(.caption)
                            Spacer()
                            Button(entry.summary) { editing = entry }.disabled(!session.isActive)
                                .frame(minHeight: 44).accessibilityIdentifier("set-\(entry.setNumber)")
                            if session.isActive {
                                Menu {
                                    Button("Edit") { editing = entry }
                                    Button("Delete", role: .destructive) { change { try journal.remove(entry.id, from: sessionID) } }
                                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                                .accessibilityLabel("Set options")
                            }
                        }
                    }
                    if session.isActive {
                        Button { change { try journal.log(lift.id, in: sessionID) } } label: {
                            Label("Add set", systemImage: "plus").frame(minHeight: 44)
                        }
                    }
                }.transition(.opacity.combined(with: .move(edge: .top)))
            }
        }.monospacedDigit().panel().clipped()
    }

    private func summary(_ entries: [LoggedSet], unit: LoadUnit) -> String {
        guard let heaviest = entries.map(\.kilograms).max() else { return "0 sets" }
        let weight = unit.display(heaviest).formatted(.number.precision(.fractionLength(0...2)))
        return "\(entries.count) sets · \(weight) \(unit.rawValue)"
    }

    private func change(_ action: () throws -> Void) {
        do { try withAnimation(Style.motion, action); Haptics.tap() } catch { failure = error.localizedDescription }
    }
}

private struct ExercisePicker: View {
    @EnvironmentObject private var journal: Journal
    @Environment(\.dismiss) private var dismiss
    let sessionID: UUID
    @State private var query = ""
    @State private var failure: String?
    private var used: Set<String> { Set((journal.workout(sessionID)?.lifts ?? []).map { $0.name.liftKey }) }

    var body: some View {
        NavigationStack {
            List {
                TextField("Search or create", text: $query).submitLabel(.done)
                let available = journal.snapshot.presets.filter {
                    !used.contains($0.name.liftKey) && (query.trimmed.isEmpty || $0.name.liftKey.contains(query.liftKey))
                }
                if !query.trimmed.isEmpty && !used.contains(query.liftKey) && !available.contains(where: { $0.name.liftKey == query.liftKey }) {
                    Button { add(query) } label: { Label(query.trimmed, systemImage: "plus") }
                }
                ForEach(available) { preset in Button(preset.name) { add(preset.name) } }
            }.navigationTitle("Add exercise").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .reporting($failure)
        }
    }

    private func add(_ name: String) {
        do {
            try journal.addLift(named: name, unit: journal.snapshot.defaults.unit, to: sessionID)
            Haptics.tap()
            dismiss()
        } catch { failure = error.localizedDescription }
    }
}
