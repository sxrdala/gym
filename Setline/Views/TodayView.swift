import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var journal: Journal
    private var active: WorkoutSession? { journal.activeWorkout }
    private var routines: [Routine] { journal.snapshot.routines.sorted { $0.sortOrder < $1.sortOrder } }
    private var tasks: [DailyTask] { journal.snapshot.tasks.sorted { $0.createdAt < $1.createdAt } }
    @State private var workout: WorkoutSession?
    @State private var selector = false
    @State private var newTask = false
    @State private var setup = false
    @State private var failure: String?

    var body: some View {
        List {
            HStack {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline.weight(.medium)).foregroundStyle(Style.muted)
                Spacer()
                IconControl(title: "Spotify Setup", icon: "headphones") { setup = true }
            }.panelRow()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("Workout", systemImage: "dumbbell").font(.subheadline.weight(.semibold))
                            .foregroundStyle(Style.mint)
                        Text(active?.routineName ?? "Start workout")
                            .font(.title.bold()).fixedSize(horizontal: false, vertical: true)
                        Text(workoutDetail).font(.subheadline).foregroundStyle(Style.muted)
                    }
                    Spacer(minLength: 2)
                    Plates().frame(width: 98, height: 90)
                }
                PrimaryButton(title: active == nil ? "Choose workout" : "Resume Active Workout",
                              icon: "arrow.right") {
                    if let session = active { workout = session } else { selector = true }
                }
            }.panel().panelRow()

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
        .listSurface().navigationTitle("Today").onAppear { Haptics.prepare() }
        .sheet(isPresented: $newTask) {
            NameSheet("New task", prompt: "Task title", save: journal.createTask)
        }
        .sheet(isPresented: $setup) { SpotifySetup() }
        .confirmationDialog("Start Workout", isPresented: $selector, titleVisibility: .visible) {
            ForEach(routines) { routine in Button(routine.name) { start(routine) } }
            Button("Empty quick workout") { start(nil) }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(item: $workout) { session in NavigationStack { WorkoutView(sessionID: session.id) } }
        .reporting($failure)
    }

    private var workoutDetail: String {
        if let active = active {
            return "\(active.sets.count) sets logged · In progress"
        }
        return routines.isEmpty ? "Empty quick workout" : "\(routines.count) saved \(routines.count == 1 ? "routine" : "routines")"
    }

    private func start(_ routine: Routine?) {
        do { workout = try journal.start(routine) }
        catch { failure = error.localizedDescription }
    }
}
