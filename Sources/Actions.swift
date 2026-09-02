import Cocoa
import CoreGraphics

// Source used for synthesizing the keystrokes that button actions trigger.
private let keySource = CGEventSource(stateID: .combinedSessionState)

/// Post a key-down + key-up to the system (used by button remaps).
private func postKey(_ keyCode: CGKeyCode, _ flags: CGEventFlags) {
    guard let down = CGEvent(keyboardEventSource: keySource, virtualKey: keyCode, keyDown: true),
          let up = CGEvent(keyboardEventSource: keySource, virtualKey: keyCode, keyDown: false) else { return }
    down.flags = flags
    up.flags = flags
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
}

/// What a remapped mouse button does. These map to the macOS default
/// keyboard shortcuts, so the corresponding shortcut must be enabled in
/// System Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ Mission Control.
enum ButtonAction: String, Codable, CaseIterable {
    case none
    case missionControl
    case appExpose
    case spaceLeft
    case spaceRight
    case back
    case forward
    case launchpad

    var title: String {
        switch self {
        case .none:           return "Off (passthrough)"
        case .missionControl: return "Mission Control"
        case .appExpose:      return "App Exposé"
        case .spaceLeft:      return "Move Left a Space"
        case .spaceRight:     return "Move Right a Space"
        case .back:           return "Back  (⌘[)"
        case .forward:        return "Forward  (⌘])"
        case .launchpad:      return "Launchpad"
        }
    }

    func perform() {
        switch self {
        case .none:           break
        // Mission Control via synthetic Ctrl+Up is unreliable (the WindowServer
        // checks real modifier state), so launch the app — always works.
        case .missionControl:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mission Control.app"))
        case .launchpad:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Launchpad.app"))
        // These have no standalone app; they use the default macOS shortcuts,
        // which must be enabled in Settings ▸ Keyboard ▸ Keyboard Shortcuts.
        case .appExpose:      postKey(125, .maskControl)   // Ctrl + Down
        case .spaceLeft:      postKey(123, .maskControl)   // Ctrl + Left
        case .spaceRight:     postKey(124, .maskControl)   // Ctrl + Right
        case .back:           postKey(33,  .maskCommand)   // Cmd + [
        case .forward:        postKey(30,  .maskCommand)   // Cmd + ]
        }
    }
}
