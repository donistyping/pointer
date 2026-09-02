import Foundation

/// "Start at login" via a per-user LaunchAgent. This is reliable for a
/// self-signed app in any location — unlike SMAppService, which quietly fails
/// for apps that aren't notarized / living in /Applications.
///
/// The plist's presence in ~/Library/LaunchAgents is the source of truth;
/// launchd loads it automatically at every login.
enum LoginItem {
    static let label = "com.local.pointer"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func setEnabled(_ enabled: Bool) {
        enabled ? enable() : disable()
    }

    private static func enable() {
        let appPath = Bundle.main.bundlePath
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/open</string>
                <string>\(appPath)</string>
            </array>
            <key>RunAtLoad</key><true/>
            <key>ProcessType</key><string>Interactive</string>
        </dict>
        </plist>
        """
        try? FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? plist.write(to: plistURL, atomically: true, encoding: .utf8)
        launchctl(["bootout", "gui/\(getuid())/\(label)"])   // clear any stale copy
        launchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    private static func disable() {
        launchctl(["bootout", "gui/\(getuid())/\(label)"])
        try? FileManager.default.removeItem(at: plistURL)
    }

    private static func launchctl(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        try? p.run()
        p.waitUntilExit()
    }
}
