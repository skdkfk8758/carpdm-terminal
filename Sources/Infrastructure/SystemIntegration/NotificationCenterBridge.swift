import CarpdmCore
import Foundation
import UserNotifications

public enum NotificationSchedulerFactory {
    public static func makeDefault() -> NotificationScheduling {
        // `swift run` launches from a build directory, not an app bundle.
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return NoopNotificationScheduler()
        }
        return UserNotificationScheduler()
    }
}

public final class UserNotificationScheduler: NotificationScheduling {
    public init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

public struct NoopNotificationScheduler: NotificationScheduling {
    public init() {}
    public func send(title: String, body: String) {}
}
