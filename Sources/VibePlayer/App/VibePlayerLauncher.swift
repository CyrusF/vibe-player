import AppKit
import SwiftUI
import VibePlayerCore

@main
struct VibePlayerLauncher: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = VibePlayerRuntime.store

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
private enum VibePlayerRuntime {
    static let store = AppStore.live()
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(store: VibePlayerRuntime.store)
        DispatchQueue.main.async {
            MainWindowController.shared.show(store: VibePlayerRuntime.store)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainWindowController.shared.show(store: VibePlayerRuntime.store)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        VibePlayerRuntime.store.stopDetection()
    }
}
