import UIKit

@MainActor
enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .light)
    private static let notification = UINotificationFeedbackGenerator()

    static func prepare() {
        impact.prepare()
        notification.prepare()
    }

    static func tap() {
        impact.prepare()
        impact.impactOccurred()
        impact.prepare()
    }

    static func success() {
        notification.prepare()
        notification.notificationOccurred(.success)
        notification.prepare()
    }
}
