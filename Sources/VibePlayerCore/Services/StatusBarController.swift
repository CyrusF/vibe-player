import AppKit
import Combine

@MainActor
public final class StatusBarController: NSObject, NSMenuDelegate {
    private let store: AppStore
    private let statusItem: NSStatusItem
    private var cancellable: AnyCancellable?

    public init(store: AppStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
        cancellable = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshIcon()
            }
        }
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        refreshIcon()
    }

    private func refreshIcon() {
        guard let button = statusItem.button else { return }
        button.image = statusBarImage()
    }

    private func statusBarImage() -> NSImage? {
        let image: NSImage?
        if let url = Bundle.main.url(forResource: "StatusBarTemplate", withExtension: "png") {
            image = NSImage(contentsOf: url)
        } else {
            image = NSImage(systemSymbolName: "play.rectangle", accessibilityDescription: "Vibe Player")
        }
        image?.isTemplate = true
        image?.size = NSSize(width: 21, height: 21)
        return image
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        showContextMenu()
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(item(title: store.text(.openVibePlayer), action: #selector(openMainWindow(_:))))
        menu.addItem(.separator())

        let status = NSMenuItem(title: store.statusTitle(store.status), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        let detail = NSMenuItem(title: store.statusDetail, action: nil, keyEquivalent: "")
        detail.isEnabled = false
        menu.addItem(detail)

        menu.addItem(.separator())
        menu.addItem(item(
            title: store.isDetectionEnabled ? store.text(.pauseDetection) : store.text(.startDetection),
            action: #selector(toggleDetection(_:))
        ))
        menu.addItem(captureTargetMenu())
        menu.addItem(item(title: store.text(.previewGlow), action: #selector(previewGlow(_:))))
        menu.addItem(item(title: store.text(.showDisplayMarkers), action: #selector(showDisplayMarkers(_:))))

        menu.addItem(.separator())
        menu.addItem(sensitivityMenu())

        let fallback = item(title: store.text(.mediaKeyFallback), action: #selector(toggleMediaKeyFallback(_:)))
        fallback.state = store.mediaKeyFallbackEnabled ? .on : .off
        menu.addItem(fallback)
        menu.addItem(languageMenu())

        menu.addItem(.separator())
        menu.addItem(item(title: store.text(.quit), action: #selector(quit(_:)), keyEquivalent: "q"))
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    public func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    private func item(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func captureTargetMenu() -> NSMenuItem {
        let root = NSMenuItem(title: store.text(.captureTarget), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for browser in BrowserKind.allCases {
            let child = item(title: browser.displayName, action: #selector(captureTarget(_:)))
            child.representedObject = browser.rawValue
            submenu.addItem(child)
        }
        root.submenu = submenu
        return root
    }

    private func sensitivityMenu() -> NSMenuItem {
        let root = NSMenuItem(title: store.text(.sensitivity), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for sensitivity in Sensitivity.allCases {
            let child = item(title: store.sensitivityTitle(sensitivity), action: #selector(selectSensitivity(_:)))
            child.representedObject = sensitivity.rawValue
            child.state = store.sensitivity == sensitivity ? .on : .off
            submenu.addItem(child)
        }
        root.submenu = submenu
        return root
    }

    private func languageMenu() -> NSMenuItem {
        let root = NSMenuItem(title: store.text(.language), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for language in AppLanguage.allCases {
            let child = item(title: language.nativeName, action: #selector(selectLanguage(_:)))
            child.representedObject = language.rawValue
            child.state = store.language == language ? .on : .off
            submenu.addItem(child)
        }
        root.submenu = submenu
        return root
    }

    @objc private func toggleDetection(_ sender: NSMenuItem) {
        store.isDetectionEnabled ? store.stopDetection() : store.startDetection()
    }

    @objc private func openMainWindow(_ sender: NSMenuItem) {
        MainWindowController.shared.show(store: store)
    }

    @objc private func showDisplayMarkers(_ sender: NSMenuItem) {
        store.showDisplayMarkers()
    }

    @objc private func previewGlow(_ sender: NSMenuItem) {
        store.previewGlow()
    }

    @objc private func captureTarget(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let browser = BrowserKind(rawValue: raw) else {
            return
        }
        store.captureTarget(in: browser)
    }

    @objc private func selectSensitivity(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let sensitivity = Sensitivity(rawValue: raw) else {
            return
        }
        store.sensitivity = sensitivity
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let language = AppLanguage(rawValue: raw) else {
            return
        }
        store.setLanguage(language)
    }

    @objc private func toggleMediaKeyFallback(_ sender: NSMenuItem) {
        store.mediaKeyFallbackEnabled.toggle()
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
}
