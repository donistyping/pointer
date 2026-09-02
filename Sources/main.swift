import Cocoa

// Pointer — a tiny menu-bar app that fixes the parts of your mouse macOS won't:
// reverse scroll (mouse wheel only), smooth scrolling, and remapping the
// middle / side / wheel-click buttons.
//
// Everything is driven by a single CGEventTap (see EventController.swift).

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// .accessory => no Dock icon, no menu; lives only in the menu bar.
app.setActivationPolicy(.accessory)
app.run()
