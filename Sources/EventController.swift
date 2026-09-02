import Cocoa
import CoreGraphics

// C-compatible tap callback. Must be a free function (captures nothing); the
// EventController is passed through userInfo.
private func tapCallback(proxy: CGEventTapProxy,
                         type: CGEventType,
                         event: CGEvent,
                         userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<EventController>.fromOpaque(userInfo).takeUnretainedValue()
    return controller.handle(type: type, event: event)
}

/// Owns the CGEventTap and implements the three behaviors:
/// reverse scroll, smooth scroll, and button remapping.
final class EventController {
    /// Tag stamped on our own synthetic scroll events so we never re-process them.
    static let magic: Int64 = 0x4D46  // "MF"

    let settings: Settings
    private let smooth: SmoothScroller
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// When set, the next mouse-button press is captured (its number handed to
    /// this closure) instead of being acted on. Used by the "Detect" button.
    var pendingLearn: ((Int) -> Void)?

    init(settings: Settings) {
        self.settings = settings
        self.smooth = SmoothScroller(source: CGEventSource(stateID: .hidSystemState))
    }

    var isRunning: Bool { tap != nil }

    /// Create + enable the tap. Returns false if the OS denied it (no
    /// Accessibility permission) — caller should prompt and retry.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask =
            (CGEventMask(1) << CGEventType.scrollWheel.rawValue) |
            (CGEventMask(1) << CGEventType.otherMouseDown.rawValue) |
            (CGEventMask(1) << CGEventType.otherMouseUp.rawValue)

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.tap = port
        self.runLoopSource = src
        return true
    }

    // MARK: - Dispatch

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        case .scrollWheel:
            return handleScroll(event)
        case .otherMouseDown, .otherMouseUp:
            return handleButton(type: type, event: event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    // MARK: - Scrolling

    private func handleScroll(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        // Our own synthetic events, and trackpad / Magic Mouse (continuous)
        // events, pass straight through untouched. This is what keeps the
        // reversal "mouse only" and prevents feedback loops.
        if event.getIntegerValueField(.eventSourceUserData) == EventController.magic {
            return Unmanaged.passUnretained(event)
        }
        let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        if continuous {
            return Unmanaged.passUnretained(event)
        }

        let sign: Double = settings.reverseScroll ? -1 : 1

        if settings.smoothScroll {
            // Prefer the accelerated fixed-point delta; fall back to line delta.
            let f1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
            let f2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
            let d1 = f1 != 0 ? f1 : Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
            let d2 = f2 != 0 ? f2 : Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
            smooth.smoothing = settings.smoothness
            smooth.add(dx: sign * d2 * settings.scrollSpeed,
                       dy: sign * d1 * settings.scrollSpeed)
            return nil  // swallow original; SmoothScroller emits the motion
        }

        if settings.reverseScroll {
            negate(event, .scrollWheelEventDeltaAxis1)
            negate(event, .scrollWheelEventDeltaAxis2)
            negate(event, .scrollWheelEventPointDeltaAxis1)
            negate(event, .scrollWheelEventPointDeltaAxis2)
            negateDouble(event, .scrollWheelEventFixedPtDeltaAxis1)
            negateDouble(event, .scrollWheelEventFixedPtDeltaAxis2)
        }
        return Unmanaged.passUnretained(event)
    }

    private func negate(_ e: CGEvent, _ field: CGEventField) {
        e.setIntegerValueField(field, value: -e.getIntegerValueField(field))
    }
    private func negateDouble(_ e: CGEvent, _ field: CGEventField) {
        e.setDoubleValueField(field, value: -e.getDoubleValueField(field))
    }

    // MARK: - Buttons

    private func handleButton(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))

        // Detect mode: capture this button number and swallow the click.
        if let learn = pendingLearn {
            if type == .otherMouseDown {
                pendingLearn = nil
                DispatchQueue.main.async { learn(button) }
            }
            return nil
        }

        let action = settings.action(forButton: button)
        guard action != .none else { return Unmanaged.passUnretained(event) }
        // Mapped: trigger on the down edge, and swallow both down and up so the
        // app underneath doesn't also see the raw button.
        if type == .otherMouseDown { action.perform() }
        return nil
    }
}
