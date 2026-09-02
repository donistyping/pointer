import Cocoa
import ApplicationServices

/// Retains a closure and exposes it as a target/action pair (AppKit controls
/// only hold their target weakly, so these are kept alive in `targets`).
private final class ClosureTarget: NSObject {
    private let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
    @objc func fire(_ sender: Any?) { handler() }
}

/// The real preferences window, built entirely in code (no nib).
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let settings: Settings
    private let controller: EventController
    private var targets: [ClosureTarget] = []

    private let buttonsStack = NSStackView()
    private var detectButton: NSButton!
    private var loginCheckbox: NSButton!
    private var statusLabel: NSTextField!

    init(settings: Settings, controller: EventController) {
        self.settings = settings
        self.controller = controller
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 200),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "Pointer Settings"
        super.init(window: window)
        window.delegate = self
        window.contentView = buildContent()
        relayout()
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    func show() {
        refreshButtons()
        refreshStatus()
        loginCheckbox.state = isLoginEnabled ? .on : .off
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Called when Accessibility is granted while the window is open.
    func permissionChanged() {
        guard window?.isVisible == true else { return }
        refreshStatus()
    }

    // MARK: - Wiring helpers

    private func wire(_ control: NSControl, _ handler: @escaping () -> Void) {
        let t = ClosureTarget(handler)
        control.target = t
        control.action = #selector(ClosureTarget.fire(_:))
        targets.append(t)
    }

    private func header(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text.uppercased())
        l.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        l.textColor = .secondaryLabelColor
        return l
    }

    private func spacer(_ h: CGFloat) -> NSView {
        let v = NSView()
        v.heightAnchor.constraint(equalToConstant: h).isActive = true
        return v
    }

    private func sliderRow(_ title: String, _ slider: NSSlider, _ value: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 54).isActive = true
        let h = NSStackView(views: [label, slider, value])
        h.orientation = .horizontal
        h.spacing = 8
        h.alignment = .centerY
        return h
    }

    // MARK: - Content

    private func buildContent() -> NSView {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false

        // — Scrolling —
        root.addArrangedSubview(header("Scrolling"))

        let reverse = NSButton(checkboxWithTitle: "Reverse scroll direction (mouse wheel only)",
                               target: nil, action: nil)
        reverse.state = settings.reverseScroll ? .on : .off
        wire(reverse) { [weak self] in self?.settings.reverseScroll = (reverse.state == .on); self?.settings.save() }
        root.addArrangedSubview(reverse)

        let smooth = NSButton(checkboxWithTitle: "Smooth scrolling", target: nil, action: nil)
        smooth.state = settings.smoothScroll ? .on : .off
        wire(smooth) { [weak self] in self?.settings.smoothScroll = (smooth.state == .on); self?.settings.save() }
        root.addArrangedSubview(smooth)

        let speedValue = NSTextField(labelWithString: String(Int(settings.scrollSpeed)))
        speedValue.alignment = .right
        speedValue.widthAnchor.constraint(equalToConstant: 38).isActive = true
        let speed = NSSlider(value: settings.scrollSpeed, minValue: 10, maxValue: 120, target: nil, action: nil)
        speed.isContinuous = true
        speed.widthAnchor.constraint(equalToConstant: 210).isActive = true
        wire(speed) { [weak self] in
            guard let self = self else { return }
            self.settings.scrollSpeed = speed.doubleValue; self.settings.save()
            speedValue.stringValue = String(Int(speed.doubleValue))
        }
        root.addArrangedSubview(sliderRow("Speed", speed, speedValue))

        let glideValue = NSTextField(labelWithString: String(Int(smoothingToGlide(settings.smoothness))))
        glideValue.alignment = .right
        glideValue.widthAnchor.constraint(equalToConstant: 38).isActive = true
        let glide = NSSlider(value: smoothingToGlide(settings.smoothness), minValue: 0, maxValue: 100,
                             target: nil, action: nil)
        glide.isContinuous = true
        glide.widthAnchor.constraint(equalToConstant: 210).isActive = true
        wire(glide) { [weak self] in
            guard let self = self else { return }
            self.settings.smoothness = glideToSmoothing(glide.doubleValue); self.settings.save()
            glideValue.stringValue = String(Int(glide.doubleValue))
        }
        root.addArrangedSubview(sliderRow("Glide", glide, glideValue))

        root.addArrangedSubview(spacer(6))

        // — Mouse Buttons —
        root.addArrangedSubview(header("Mouse Buttons"))
        let note = NSTextField(labelWithString: "Assign middle / side / wheel-click buttons. Use Detect for anything else.")
        note.font = NSFont.systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        root.addArrangedSubview(note)

        buttonsStack.orientation = .vertical
        buttonsStack.alignment = .leading
        buttonsStack.spacing = 6
        root.addArrangedSubview(buttonsStack)

        detectButton = NSButton(title: "Detect a Button…", target: nil, action: nil)
        detectButton.bezelStyle = .rounded
        wire(detectButton) { [weak self] in self?.startDetect() }
        root.addArrangedSubview(detectButton)

        root.addArrangedSubview(spacer(6))

        // — General —
        root.addArrangedSubview(header("General"))
        loginCheckbox = NSButton(checkboxWithTitle: "Start MouseFix at login", target: nil, action: nil)
        loginCheckbox.state = isLoginEnabled ? .on : .off
        wire(loginCheckbox) { [weak self] in self?.toggleLogin() }
        root.addArrangedSubview(loginCheckbox)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        let grant = NSButton(title: "Open Accessibility Settings", target: nil, action: nil)
        grant.bezelStyle = .rounded
        wire(grant) {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
        let statusRow = NSStackView(views: [statusLabel, grant])
        statusRow.orientation = .horizontal
        statusRow.spacing = 10
        statusRow.alignment = .centerY
        root.addArrangedSubview(statusRow)

        let container = NSView()
        container.addSubview(root)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 470),
            root.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            root.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            root.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -18),
        ])
        return container
    }

    // MARK: - Button rows

    private func refreshButtons() {
        buttonsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let numbers = settings.buttons.keys.compactMap { Int($0) }.sorted()
        for n in (numbers.isEmpty ? [2, 3, 4] : numbers) {
            buttonsStack.addArrangedSubview(buttonRow(number: n))
        }
        relayout()
    }

    private func buttonRow(number n: Int) -> NSView {
        let name = NSTextField(labelWithString: buttonName(n))
        name.widthAnchor.constraint(equalToConstant: 196).isActive = true

        let popup = NSPopUpButton()
        let actions = ButtonAction.allCases
        actions.forEach { popup.addItem(withTitle: $0.title) }
        if let i = actions.firstIndex(of: settings.action(forButton: n)) { popup.selectItem(at: i) }
        popup.widthAnchor.constraint(equalToConstant: 200).isActive = true
        wire(popup) { [weak self] in
            guard let self = self else { return }
            let i = popup.indexOfSelectedItem
            if i >= 0 && i < actions.count {
                self.settings.setAction(actions[i], forButton: n); self.settings.save()
            }
        }

        let h = NSStackView(views: [name, popup])
        h.orientation = .horizontal
        h.spacing = 10
        h.alignment = .centerY
        return h
    }

    private func buttonName(_ n: Int) -> String {
        switch n {
        case 2: return "Scroll-wheel click (btn 2)"
        case 3: return "Side button — back (btn 3)"
        case 4: return "Side button — fwd (btn 4)"
        default: return "Button \(n)"
        }
    }

    // MARK: - Detect

    private func startDetect() {
        detectButton.title = "Press a mouse button now…"
        detectButton.isEnabled = false
        controller.pendingLearn = { [weak self] number in
            guard let self = self else { return }
            if self.settings.buttons[String(number)] == nil {
                self.settings.setAction(.missionControl, forButton: number)
            }
            self.settings.save()
            self.detectButton.title = "Detect a Button…"
            self.detectButton.isEnabled = true
            self.refreshButtons()
        }
    }

    // MARK: - Status / login

    private func refreshStatus() {
        let active = controller.isRunning
        statusLabel.stringValue = active
            ? "Active ✓ — intercepting your mouse"
            : "Inactive — grant Accessibility; it starts automatically"
        statusLabel.textColor = active ? .secondaryLabelColor : .systemRed
        detectButton.isEnabled = active
    }

    private var isLoginEnabled: Bool { LoginItem.isEnabled }

    private func toggleLogin() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
        loginCheckbox.state = isLoginEnabled ? .on : .off
    }

    // MARK: - Layout / glide mapping

    private func relayout() {
        guard let cv = window?.contentView else { return }
        cv.layoutSubtreeIfNeeded()
        window?.setContentSize(cv.fittingSize)
    }

    // Glide slider runs 0 (snappy) … 100 (floaty); smoothing runs 0.35 … 0.07.
    private func smoothingToGlide(_ s: Double) -> Double {
        let c = min(max(s, 0.07), 0.35)
        return (0.35 - c) / (0.35 - 0.07) * 100
    }
    private func glideToSmoothing(_ g: Double) -> Double {
        let t = min(max(g, 0), 100) / 100
        return 0.35 - t * (0.35 - 0.07)
    }
}
