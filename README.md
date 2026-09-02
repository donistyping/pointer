# Pointer

A tiny macOS menu-bar app that fixes the parts of your mouse macOS won't:

- **Reverse scroll direction** — for the mouse wheel only, leaving the trackpad / Magic Mouse alone.
- **Smooth scrolling** — eased, animated wheel scrolling.
- **Button remapping** — middle / side / **scroll-wheel-click** buttons trigger Mission Control, Spaces, Back/Forward, or Launchpad.

Menu-bar only (no Dock icon). One `CGEventTap`, no dependencies, no Xcode project — just the Command Line Tools.

## Install (build from source — recommended)

Requirements: macOS 13+ and Apple's Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/donistyping/pointer.git
cd pointer
./build.sh install
```

That compiles a universal (Apple Silicon + Intel) `Pointer.app`, copies it to `/Applications`, sets it to start at login, and launches it. The first build on a machine also creates a local signing certificate automatically, so the Accessibility grant survives future rebuilds. Then grant Accessibility (below) and you're done.

Plain `./build.sh` just builds the app in place without installing.

## Install (prebuilt)

Grab the zip from [Releases](https://github.com/donistyping/pointer/releases), unzip, and drag `Pointer.app` into `/Applications`.

Pointer isn't notarized (no Apple Developer account behind it), so macOS balks on first open: **right-click ▸ Open** on macOS 13–14, or on macOS 15+ go to *System Settings ▸ Privacy & Security* and click **Open Anyway**. Building from source avoids that dance entirely, which is why it's the recommended path.

## First run

Grant **Accessibility** access when asked:
*System Settings ▸ Privacy & Security ▸ Accessibility ▸* enable **Pointer**. It activates within ~2 seconds (it polls) — no relaunch needed. An event tap can read every scroll and click, which is why macOS gates it behind this permission.

## Settings

Click the 🖱 menu-bar icon ▸ **Settings**: toggle reverse/smooth, set scroll **Speed** and **Glide**, map the middle / side / wheel-click buttons, and toggle **Start at Login**. "Detect a Button…" binds whatever number your mouse reports.

Config lives at `~/Library/Application Support/Pointer/config.json`.

## Start at login

A LaunchAgent at `~/Library/LaunchAgents/com.local.pointer.plist` runs `open /Applications/Pointer.app` at every login. (Apple's `SMAppService` is unreliable for a self-signed app outside the App Store, so Pointer uses the classic, bulletproof LaunchAgent instead.) The in-app "Start at Login" toggle writes/removes this plist.

## Why it "just works" after rebuilds

Pointer is signed with a **stable self-signed identity**, so its Accessibility grant is bound to the certificate rather than the exact binary hash. You grant permission once and it survives rebuilds *and* moving the app.

## Notes / limitations

- Reverse and smooth scrolling affect the **mouse wheel only**, never the trackpad — that's the whole point.
- **Mission Control** and **Launchpad** launch their apps directly (always work). **Spaces** and **App Exposé** use the default macOS keyboard shortcuts, so keep those enabled in *Keyboard ▸ Keyboard Shortcuts ▸ Mission Control*.
- Regenerate the icon: `swift iconmaker.swift out.iconset && iconutil -c icns out.iconset -o Resources/AppIcon.icns`, then rebuild.
