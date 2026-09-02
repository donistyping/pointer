import Cocoa
import ApplicationServices

/// NSMenuItem that runs a closure when clicked.
final class ActionMenuItem: NSMenuItem {
    private var handler: () -> Void
    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        self.target = self
    }
    required init(coder: NSCoder) { fatalError("not used") }
    @objc private func invoke() { handler() }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let settings = Settings.load()
    private lazy var controller = EventController(settings: settings)
    private var settingsWC: SettingsWindowController?
    private var retryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        rebuildMenu()

        // Start at login defaults ON (once).
        if !settings.didInitLoginItem {
            settings.didInitLoginItem = true
            settings.save()
            LoginItem.setEnabled(true)
        }

        // Creating the event tap succeeds only when we're Accessibility-trusted —
        // that IS the real permission test. If denied, prompt and poll.
        if !controller.start() {
            promptForAccessibility()
        }
        rebuildMenu()
    }

    // MARK: - Status item & menu

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        if let img = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "MouseFix") {
            img.isTemplate = true
            button.image = img
        } else {
            button.title = "🖱"
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let active = controller.isRunning

        let header = NSMenuItem(title: active ? "Pointer — active" : "Pointer — needs permission",
                                action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        menu.addItem(ActionMenuItem("Settings…") { [weak self] in self?.openSettings() })
        if !active {
            menu.addItem(ActionMenuItem("Grant Accessibility Access…") { [weak self] in
                self?.promptForAccessibility()
            })
        }
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Quit Pointer") { NSApp.terminate(nil) })

        statusItem.menu = menu
    }

    private func openSettings() {
        if settingsWC == nil {
            settingsWC = SettingsWindowController(settings: settings, controller: controller)
        }
        settingsWC?.show()
    }

    // MARK: - Accessibility permission

    private func promptForAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        startRetryTimer()
    }

    private func startRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            guard self.controller.start() else { return }   // keep retrying until the tap is permitted
            t.invalidate()
            self.retryTimer = nil
            self.rebuildMenu()
            self.settingsWC?.permissionChanged()
        }
    }

    private func showTapFailedAlert() {
        let alert = NSAlert()
        alert.messageText = "Couldn't start the mouse event tap"
        alert.informativeText = "Pointer has Accessibility permission but macOS refused the event tap. Try quitting and relaunching."
        alert.runModal()
    }
}
