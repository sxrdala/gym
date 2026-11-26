import SwiftUI

struct CustomWorkoutView: View {
    @EnvironmentObject private var journal: Journal
    @Environment(\.dismiss) private var dismiss
    let sessionID: UUID
    @State private var adding = false
    @State private var finishing = false
    @State private var failure: String?
    @State private var newestLift: UUID?

    var body: some View {
        if let session = journal.workout(sessionID) {
            ScrollViewReader { proxy in
                List {
                    SpotifyBar().workoutRow()
                    if session.lifts.isEmpty {
                        EmptyState("Add your first exercise", systemImage: "dumbbell",
                                   description: "Each exercise starts with two sets. Tap a checkmark when you finish a set.")
                            .panelRow()
                    }
                    ForEach(session.ordered) { lift in
                        Text(lift.name).font(.title2.bold()).id(lift.id).panelRow()
                        ForEach(session.entries(for: lift)) { set in
                            setEditor(set).panelRow().swipeActions {
                                Button("Delete", role: .destructive) {
                                    change { try journal.remove(set.id, from: sessionID) }
                                }
                            }
                        }
                        Button {
                            change { try journal.log(lift.id, in: sessionID) }
                        } label: {
                            Label("Add Set", systemImage: "plus").frame(minHeight: 44)
                        }.panelRow()
                    }
                }.listSurface()
                    .onChange(of: newestLift) { id in
                        if let id { withAnimation { proxy.scrollTo(id, anchor: .top) } }
                    }
            }
            .navigationTitle(session.routineName).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { finishing = true }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Add exercise", icon: "plus") { adding = true }
                    .padding(.horizontal, 16).padding(.vertical, 6).background(.black)
            }
            .sheet(isPresented: $adding) {
                NameSheet("Add exercise", prompt: "Exercise name") { name in
                    try journal.addLift(named: name, unit: .kg, to: sessionID)
                    newestLift = journal.workout(sessionID)?.selectedLiftID
                }
            }
            .confirmationDialog("Finish this workout?", isPresented: $finishing, titleVisibility: .visible) {
                Button("Finish Workout") { change { try journal.finish(sessionID); dismiss() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(session.completedSets.count) of \(session.sets.count) sets marked complete.")
            }
            .reporting($failure)
        }
    }

    private func setEditor(_ entry: LoggedSet) -> some View {
        let done = entry.isTarget != true
        func current() -> LoggedSet {
            journal.workout(sessionID)?.sets.first { $0.id == entry.id } ?? entry
        }
        return VStack(alignment: .leading, spacing: 3) {
            Button {
                change { try journal.togglePerformed(entry.id, in: sessionID) }
            } label: {
                HStack {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(done ? Style.mint : Style.muted)
                    Text("Set \(entry.setNumber)").font(.headline)
                    Spacer()
                    Text(done ? "Logged" : "Target").font(.caption).foregroundStyle(Style.muted)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityHint("Toggle set completion")
            SetControls(unit: .kg, increment: 2.5,
                        kilograms: Binding(get: { current().kilograms }, set: { value in
                            change { try journal.edit(entry.id, in: sessionID, kilograms: value, reps: current().reps, unit: .kg) }
                        }),
                        reps: Binding(get: { current().reps }, set: { value in
                            change { try journal.edit(entry.id, in: sessionID, kilograms: current().kilograms, reps: value, unit: .kg) }
                        }))
        }
    }

    private func change(_ action: () throws -> Void) {
        do { try action(); Haptics.tap() } catch { failure = error.localizedDescription }
    }
}
