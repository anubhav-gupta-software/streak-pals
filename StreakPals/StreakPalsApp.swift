import SwiftUI
import UserNotifications

@main
struct StreakPalsApp: App {
    @State private var store = AppStore()
    @State private var notifications = NotificationCenterBridge()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .onAppear {
                    notifications.onOpenHabit = { id in
                        store.pendingCheckIn = HabitIDBox(id: id)
                    }
                    UNUserNotificationCenter.current().delegate = notifications
                }
        }
    }
}

final class NotificationCenterBridge: NSObject, UNUserNotificationCenterDelegate {
    var onOpenHabit: (UUID) -> Void = { _ in }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let raw = response.notification.request.content.userInfo["habitID"] as? String,
           let id = UUID(uuidString: raw) {
            onOpenHabit(id)
        }
        completionHandler()
    }
}
