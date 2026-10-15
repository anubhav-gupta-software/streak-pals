import Foundation
import UserNotifications

enum ReminderScheduler {
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func reschedule(snapshot: AppSnapshot) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let existing = requests.map(\.identifier).filter { $0.hasPrefix("habit.") }
            center.removePendingNotificationRequests(withIdentifiers: existing)
            guard snapshot.remindersEnabled, let palID = snapshot.activePalID else { return }
            for habit in snapshot.habits(for: palID) where habit.reminderEnabled {
                let content = UNMutableNotificationContent()
                content.title = habit.title
                content.body = habit.circleID == nil
                    ? "Check in to keep your streak alive."
                    : "Your pals are counting on a check-in today."
                content.sound = .default
                content.userInfo = ["habitID": habit.id.uuidString]
                var components = DateComponents()
                components.hour = habit.reminderHour
                components.minute = habit.reminderMinute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "habit.\(habit.id.uuidString)",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }
}
