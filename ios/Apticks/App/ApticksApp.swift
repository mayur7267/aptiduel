import AppCore
import SwiftUI
import UserNotifications

@main
struct ApticksApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var container = AppContainer.make()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .preferredColorScheme(.dark)
                .tint(.accentColor)
                .onAppear {
                    // A tapped Daily reminder opens the Daily tab, unless a
                    // duel is on screen.
                    delegate.openDaily = { [router = container.router] in
                        if router.flow == nil { router.tab = .daily }
                    }
                }
        }
    }
}

// Hears taps on the Daily reminders (AppCore/ReminderState.swift). It's set
// as the notification delegate at launch, so a tap that opens the app isn't
// missed; that one waits until the app's screens are ready.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var openDaily: (() -> Void)? {
        didSet {
            if waiting, let openDaily {
                waiting = false
                openDaily()
            }
        }
    }

    private var waiting = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.notification.request.identifier.hasPrefix(ReminderPlan.prefix) else { return }
        if let openDaily { openDaily() } else { waiting = true }
    }

    // While the app is open the Daily is a tap away: no banner.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []
    }
}
