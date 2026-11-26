import SwiftUI

struct DayStrip: View {
    @EnvironmentObject private var journal: Journal
    let select: (Date) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(TrainingDay.days, id: \.self) { day in
                        pill(for: day).id(day)
                    }
                }
            }
            .accessibilityIdentifier("training-days")
            .onAppear { proxy.scrollTo(journal.selectedDay, anchor: .center) }
            .onChange(of: journal.selectedDay) { day in
                withAnimation { proxy.scrollTo(day, anchor: .center) }
            }
        }
    }

    private func pill(for day: Date) -> some View {
        let selected = day == journal.selectedDay
        let workout = journal.sessions(on: day).contains { !$0.completedSets.isEmpty || !$0.isActive }
        let food = !journal.nutrition(on: day).entries.isEmpty
        return Button { select(day) } label: {
            VStack(spacing: 3) {
                Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.caption2.weight(.semibold))
                Text(day.formatted(.dateTime.day())).font(.headline.monospacedDigit())
                HStack(spacing: 4) {
                    Circle().fill(workout ? (selected ? Color.black : Style.mint) : .clear)
                    Circle().fill(food ? (selected ? Color.indigo : Style.blue) : .clear)
                }.frame(width: 14, height: 5)
            }.frame(minWidth: 44, minHeight: 64)
                .foregroundStyle(selected ? Color.black : Color.white)
                .background(selected ? Style.mint : Style.card, in: Capsule())
        }.buttonStyle(.plain)
            .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
            .accessibilityIdentifier("day-\(TrainingDay.key(day))")
            .accessibilityValue([workout ? "Workout logged" : nil, food ? "Food logged" : nil]
                .compactMap { $0 }.joined(separator: ", "))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
