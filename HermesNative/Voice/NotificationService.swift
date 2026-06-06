import Foundation
import UserNotifications

/// Local notification permissions + posting (PRD §13). Remote push needs server
/// APNs infrastructure (not part of the client) — noted as a later addition.
@MainActor
@Observable
final class NotificationService {
    var authorized = false

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorized = settings.authorizationStatus == .authorized
    }

    func requestAuthorization() async {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        authorized = granted
    }

    /// Post a local notification (e.g. a finished cron job surfaced while in-app).
    func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
