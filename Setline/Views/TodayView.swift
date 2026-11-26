import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var journal: Journal
    private var active: WorkoutSession? { journal.activeWorkout }
    private var routines: [Routine] { journal.snapshot.routines.sorted { $0.sortOrder < $1.sortOrder } }
    private var tasks: [DailyTask] { journal.snapshot.tasks.sorted { $0.createdAt < $1.createdAt } }
    @State private var workout: WorkoutSession?
    @State private var namingWorkout = false
    @State private var createdWorkout: WorkoutSession?
    @State private var selector = false
    @State private var newTask = false
    @State private var setup = false
    @State private var failure: String?

    var body: some View {
        List {
            DayStrip { day in
                do { try journal.selectDay(day) } catch { failure = error.localizedDescription }
            }.panelRow()
            dayCard.panel().panelRow()

            if let active {
                Button { workout = active } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Resume Active Workout", systemImage: "play.fill").font(.headline)
                        Text("\(active.routineName) · \(active.dayKey)").font(.subheadline).foregroundStyle(Style.muted)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }.accessibilityLabel("Resume Active Workout").panel().panelRow()
            } else {
                Button { selector = true } label: {
                    Label("Choose workout", systemImage: "list.bullet").frame(minHeight: 44)
                }.panelRow()
            }

            HStack {
                SectionTitle(text: "Daily tasks")
                IconControl(title: "Add task", icon: "plus") { newTask = true }
            }.padding(.top, 12).panelRow()

            if tasks.isEmpty {
                Button { newTask = true } label: {
                    Label("Add your first task", systemImage: "circle.dashed")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .foregroundStyle(Style.muted)
                }.buttonStyle(.plain).panel().panelRow()
            }
            ForEach(tasks) { task in
                Button {
                    do {
                        try withAnimation(Style.motion) { try journal.toggleTask(task.id) }
                        Haptics.tap()
                    } catch { failure = error.localizedDescription }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title2).foregroundStyle(task.isCompleted ? Style.mint : Style.muted)
                        Text(task.title).strikethrough(task.isCompleted)
                            .foregroundStyle(task.isCompleted ? Style.muted : .white)
                        Spacer()
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityValue(task.isCompleted ? "Completed" : "Incomplete")
                    .panel().panelRow().swipeActions {
                        Button("Delete", role: .destructive) {
                            do { try journal.deleteTask(task.id) }
                            catch { failure = error.localizedDescription }
                        }
                    }
            }
        }
        .listSurface().navigationTitle("GymBlox").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                IconControl(title: "Spotify Setup", icon: "headphones") { setup = true }
            }
        }
        .onAppear { Haptics.prepare() }
        .sheet(isPresented: $namingWorkout, onDismiss: {
            if let createdWorkout { workout = createdWorkout; self.createdWorkout = nil }
        }) {
            NameSheet("Create Custom Workout", prompt: "Workout name") { name in
                createdWorkout = try journal.createWorkout(named: name, on: journal.selectedDay)
            }
        }
        .sheet(isPresented: $newTask) {
            NameSheet("New task", prompt: "Task title", save: journal.createTask)
        }
        .sheet(isPresented: $setup) { SpotifySetup() }
        .confirmationDialog("Start Workout", isPresented: $selector, titleVisibility: .visible) {
            ForEach(routines) { routine in Button(routine.name) { start(routine) } }
            Button("Empty quick workout") { start(nil) }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(item: $workout) { session in
            NavigationStack {
                if session.isCustom { CustomWorkoutView(sessionID: session.id) }
                else { WorkoutView(sessionID: session.id) }
            }
        }
        .reporting($failure)
    }

    private var dayCard: some View {
        let day = journal.selectedDay
        let sessions = journal.sessions(on: day)
        let intake = journal.nutrition(on: day)
        return VStack(alignment: .leading, spacing: 12) {
            Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.title2.bold()).monospacedDigit()
            Label("\(intake.consumed.calories) / \(intake.goals.calories) kcal", systemImage: "fork.knife")
                .font(.subheadline.monospacedDigit()).foregroundStyle(Style.blue)
            if sessions.isEmpty {
                Text("No workout scheduled").font(.subheadline).foregroundStyle(Style.muted)
            }
            ForEach(sessions) { session in
                if session.isActive {
                    Button { workout = session } label: { sessionLabel(session) }.buttonStyle(.plain)
                } else {
                    NavigationLink { HistoryDetail(session: session) } label: { sessionLabel(session) }
                        .buttonStyle(.plain)
                }
            }
            PrimaryButton(title: "Create Custom Workout", icon: "plus") { namingWorkout = true }
        }
    }

    private func sessionLabel(_ session: WorkoutSession) -> some View {
        HStack {
            Image(systemName: session.isActive ? "dumbbell" : "checkmark.circle.fill").foregroundStyle(Style.mint)
            VStack(alignment: .leading) {
                Text(session.routineName).font(.headline)
                Text("\(session.isActive ? "Open" : "Finished") · \(session.completedSets.count) sets logged")
                    .font(.caption).foregroundStyle(Style.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption)
        }.frame(minHeight: 44).contentShape(Rectangle())
    }

    private func start(_ routine: Routine?) {
        do { workout = try journal.start(routine, on: journal.selectedDay) }
        catch { failure = error.localizedDescription }
    }
}
