import Cocoa
import CoreGraphics

/// Turns discrete wheel ticks into an eased stream of pixel-scroll events.
///
/// Each tick adds distance to a "remaining" accumulator; a ~120Hz timer drains
/// it with exponential ease-out, posting small continuous (pixel) scroll events
/// each frame. Rapid ticks accumulate, which is what gives the fast-flick feel.
///
/// Runs entirely on the main run loop — the same loop the event tap callback
/// runs on — so no locking is needed for the shared accumulators.
final class SmoothScroller {
    private var remainingY: Double = 0
    private var remainingX: Double = 0
    private var timer: Timer?
    private let source: CGEventSource?

    /// Per-frame easing factor (0..1). Lower = longer, floatier glide.
    var smoothing: Double = 0.18

    init(source: CGEventSource?) { self.source = source }

    /// Queue additional scroll distance (in pixels). Positive dy scrolls the
    /// same direction the OS would for this wheel event.
    func add(dx: Double, dy: Double) {
        remainingX = clampDistance(remainingX + dx)
        remainingY = clampDistance(remainingY + dy)
        if timer == nil { startTimer() }
    }

    private func startTimer() {
        let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in self?.tick() }
        // .common so it keeps firing during menu tracking / window resizing.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let stepX = consume(&remainingX)
        let stepY = consume(&remainingY)
        if stepX != 0 || stepY != 0 { post(dx: stepX, dy: stepY) }
        if remainingX == 0 && remainingY == 0 {
            timer?.invalidate()
            timer = nil
        }
    }

    /// Take one eased step out of `remaining`, guaranteeing at least 1px of
    /// progress so the animation always terminates.
    private func consume(_ remaining: inout Double) -> Double {
        if remaining == 0 { return 0 }
        if abs(remaining) <= 1 {                 // finish off the last pixel
            let step = remaining; remaining = 0; return step
        }
        var step = remaining * smoothing
        if abs(step) < 1 { step = remaining > 0 ? 1 : -1 }
        remaining -= step
        return step
    }

    private func post(dx: Double, dy: Double) {
        guard let ev = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: clampInt32(dy),     // vertical
            wheel2: clampInt32(dx),     // horizontal
            wheel3: 0
        ) else { return }
        // Mark continuous + tag as ours so the tap passes it straight through
        // instead of trying to re-process / reverse it (belt and suspenders).
        ev.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        ev.setIntegerValueField(.eventSourceUserData, value: EventController.magic)
        ev.post(tap: .cgSessionEventTap)
    }

    private func clampDistance(_ v: Double) -> Double { min(max(v, -6000), 6000) }
    private func clampInt32(_ v: Double) -> Int32 { Int32(min(max(v.rounded(), -100000), 100000)) }
}
