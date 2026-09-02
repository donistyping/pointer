import Foundation

/// User configuration. A reference type so the menu bar UI and the event tap
/// share one live instance (toggling a menu item is seen by the tap at once).
/// Persisted as JSON at ~/Library/Application Support/MouseFix/config.json.
final class Settings: Codable {
    var reverseScroll: Bool = true
    var smoothScroll: Bool = true
    var scrollSpeed: Double = 40        // pixels per wheel unit
    var smoothness: Double = 0.18       // per-frame easing factor (lower = longer, floatier glide)
    var buttons: [String: ButtonAction] = ["2": .missionControl, "3": .spaceLeft, "4": .spaceRight]
    var didInitLoginItem: Bool = false  // so we only auto-enable start-at-login once

    enum CodingKeys: String, CodingKey {
        case reverseScroll, smoothScroll, scrollSpeed, smoothness, buttons, didInitLoginItem
    }

    init() {}

    // Tolerant decoding: missing keys fall back to defaults so old/partial
    // config files keep working across versions.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reverseScroll = (try? c.decode(Bool.self,   forKey: .reverseScroll)) ?? true
        smoothScroll  = (try? c.decode(Bool.self,   forKey: .smoothScroll))  ?? true
        scrollSpeed   = (try? c.decode(Double.self, forKey: .scrollSpeed))   ?? 40
        smoothness    = (try? c.decode(Double.self, forKey: .smoothness))    ?? 0.18
        buttons       = (try? c.decode([String: ButtonAction].self, forKey: .buttons))
            ?? ["2": .missionControl, "3": .spaceLeft, "4": .spaceRight]
        didInitLoginItem = (try? c.decode(Bool.self, forKey: .didInitLoginItem)) ?? false
    }

    func action(forButton n: Int) -> ButtonAction { buttons[String(n)] ?? .none }
    func setAction(_ a: ButtonAction, forButton n: Int) { buttons[String(n)] = a }

    static var configURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Pointer/config.json")
    }

    static func load() -> Settings {
        guard let data = try? Data(contentsOf: configURL),
              let s = try? JSONDecoder().decode(Settings.self, from: data) else {
            let s = Settings(); s.save(); return s
        }
        return s
    }

    func save() {
        let url = Settings.configURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(self) { try? data.write(to: url) }
    }
}
