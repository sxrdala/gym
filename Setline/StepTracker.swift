import Combine
import CoreMotion
import Foundation

@MainActor
final class StepTracker: ObservableObject {
    @Published private(set) var status: String?
    private var pedometer = CMPedometer()
    private var generation = UUID()
    private var latestLiveSample = Date.distantPast

    func refresh(journal: Journal, active: Bool, now: Date = .now) {
        generation = UUID()
        pedometer.stopUpdates()
        guard active, journal.isOpen else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") { return }
        #endif
        guard CMPedometer.isStepCountingAvailable() else { status = "Steps unavailable"; return }
        switch CMPedometer.authorizationStatus() {
        case .denied, .restricted: status = "Motion access off"; return
        default: break
        }
        status = nil
        latestLiveSample = .distantPast
        let run = generation
        let calendar = TrainingDay.calendar
        let today = calendar.startOfDay(for: now)
        // Core Motion retains seven rolling days. Only cache complete historical civil days.
        let earliest = now.addingTimeInterval(-7 * 24 * 3600)
        let meter = CMPedometer()
        pedometer = meter
        for day in TrainingDay.days {
            guard let interval = calendar.dateInterval(of: .day, for: day),
                  interval.start >= earliest, interval.start <= now else { continue }
            let live = interval.start == today
            let receive: CMPedometerHandler = { [weak self, weak journal] data, error in
                let count = data?.numberOfSteps.intValue
                let end = data?.endDate
                let message = error?.localizedDescription
                Task { @MainActor in
                    guard let self, let journal, self.generation == run else { return }
                    guard let count, let end else {
                        if let message { self.status = message }
                        return
                    }
                    if live {
                        guard calendar.isDate(end, inSameDayAs: day), end >= self.latestLiveSample else { return }
                        self.latestLiveSample = end
                    }
                    do { try journal.recordSteps(count, on: day) }
                    catch { self.status = error.localizedDescription }
                }
            }
            meter.queryPedometerData(from: interval.start, to: min(interval.end, now), withHandler: receive)
            if live { meter.startUpdates(from: interval.start, withHandler: receive) }
        }
    }
}
