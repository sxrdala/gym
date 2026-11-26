import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var journal: Journal
    private var workouts: [WorkoutSession] { journal.history }

    var body: some View {
        List {
            if workouts.isEmpty {
                EmptyState("No finished workouts", systemImage: "clock.arrow.circlepath",
                                       description: "Finish a session to see your sets here.").panelRow()
            }
            ForEach(workouts) { workout in
                NavigationLink { HistoryDetail(session: workout) } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(workout.assignedDay ?? workout.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline).foregroundStyle(Style.muted)
                        Text(workout.routineName).font(.title3.bold())
                        HStack(spacing: 16) {
                            Label(duration(of: workout), systemImage: "timer")
                            Label("\(workout.completedSets.count) sets", systemImage: "dumbbell")
                        }.font(.subheadline.monospacedDigit()).foregroundStyle(Style.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading).panel()
                }.panelRow()
            }
        }.listSurface().navigationTitle("History")
    }

    private func duration(of workout: WorkoutSession) -> String {
        let seconds = max(0, Int((workout.completedAt ?? workout.startedAt).timeIntervalSince(workout.startedAt)))
        return Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}

struct HistoryDetail: View {
    let session: WorkoutSession
    var body: some View {
        List {
            Text(session.assignedDay ?? session.startedAt.formatted(date: .long, time: .shortened))
                .font(.subheadline).foregroundStyle(Style.muted).panelRow()
            if session.sets.isEmpty {
                EmptyState("No sets logged", systemImage: "dumbbell").panelRow()
            }
            ForEach(session.ordered) { lift in
                let entries = session.entries(for: lift)
                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(text: lift.name)
                        ForEach(entries) { entry in
                            Divider()
                            SetLine(entry: entry)
                            if entry.isTarget == true {
                                Text("Uncompleted target").font(.caption).foregroundStyle(Style.muted)
                            }
                        }
                    }.panel().panelRow()
                }
            }
        }.listSurface().navigationTitle(session.routineName)
    }
}

struct SetLine: View {
    let entry: LoggedSet
    var body: some View {
        HStack {
            Text("Set \(entry.setNumber)").foregroundStyle(Style.muted)
            Spacer()
            Text(entry.summary).fontWeight(.semibold)
        }.monospacedDigit()
    }
}
