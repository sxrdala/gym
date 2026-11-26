import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var journal: Journal
    @AppStorage("hideFinishedWorkouts") private var hideFinished = false
    @State private var workout: WorkoutSession?
    @State private var naming = false
    @State private var created: WorkoutSession?
    @State private var deleting: WorkoutSession?
    @State private var newTask = false
    @State private var failure: String?

    var body: some View {
        List {
            DayStrip { day in change { try journal.selectDay(day) } }.panelRow()
            HStack {
                SectionTitle(text: journal.selectedDay.formatted(.dateTime.month(.abbreviated).day()))
                Button { withAnimation(Style.motion) { hideFinished.toggle() }; Haptics.tap() } label: {
                    Label(hideFinished ? "Show finished" : "Hide finished", systemImage: hideFinished ? "eye" : "eye.slash")
                        .font(.caption.weight(.medium)).fixedSize().frame(minHeight: 44)
                }
            }.panelRow()
            ForEach(journal.sessions(on: journal.selectedDay).filter { !hideFinished || $0.isActive }) { session in
                sessionRow(session)
            }
            PrimaryButton(title: "New workout", icon: "plus") { naming = true }.panelRow()
            Button("Quick workout") {
                change { workout = try journal.createWorkout(named: "Quick workout", on: journal.selectedDay) }
            }.panelRow()

            if !outsideCalendar.isEmpty {
                SectionTitle(text: "Other dates").panelRow()
                ForEach(outsideCalendar) { session in sessionRow(session) }
            }
            HStack {
                SectionTitle(text: "Daily tasks")
                IconControl(title: "Add task", icon: "plus") { newTask = true }
            }.panelRow()
            ForEach(journal.snapshot.tasks) { task in
                Button { change { try journal.toggleTask(task.id) } } label: {
                    Label(task.title, systemImage: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .strikethrough(task.isCompleted).frame(minHeight: 44)
                }.panelRow().swipeActions {
                    Button("Delete", role: .destructive) { change { try journal.deleteTask(task.id) } }
                }
            }
        }.listSurface().navigationTitle("Workout").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $naming, onDismiss: {
                if let created { workout = created; self.created = nil }
            }) {
                NameSheet("New workout", prompt: "Workout name") { name in
                    created = try journal.createWorkout(named: name, on: journal.selectedDay)
                }
            }
            .sheet(isPresented: $newTask) { NameSheet("New task", prompt: "Task name", save: journal.createTask) }
            .fullScreenCover(item: $workout) { session in
                NavigationStack { WorkoutView(sessionID: session.id) }
            }
            .confirmationDialog("Delete workout?", isPresented: Binding(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } }
            ), titleVisibility: .visible, presenting: deleting) { session in
                Button("Delete", role: .destructive) { change { try journal.deleteFinished(session.id) } }
                Button("Cancel", role: .cancel) {}
            } message: { Text($0.routineName) }
            .reporting($failure)
    }

    private var outsideCalendar: [WorkoutSession] {
        let keys = Set(TrainingDay.days.map(TrainingDay.key))
        return journal.snapshot.sessions.filter { !keys.contains($0.dayKey) && (!hideFinished || $0.isActive) }
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                change { try journal.openInCardEditor(session.id); workout = session }
            } label: {
                HStack {
                    Image(systemName: session.isActive ? "dumbbell.fill" : "checkmark.circle.fill").foregroundStyle(Style.mint)
                    VStack(alignment: .leading) {
                        Text(session.routineName).font(.headline)
                        Text("\(session.dayKey) · \(session.completedSets.count) done").font(.caption).foregroundStyle(Style.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("workout-\(session.routineName)")
            if !session.isActive {
                HStack {
                    Button("Duplicate to Today") { change { try journal.duplicateToToday(session.id) } }
                    Spacer()
                    IconControl(title: "Delete workout", icon: "trash") { deleting = session }.foregroundStyle(.red)
                }.font(.subheadline).buttonStyle(.borderless)
            }
        }.monospacedDigit().panel().panelRow()
    }

    private func change(_ action: () throws -> Void) {
        do { try withAnimation(Style.motion, action); Haptics.tap() } catch { failure = error.localizedDescription }
    }
}
