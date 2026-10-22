# Moove

Move windows around without reaching for the mouse.

A small macOS menu-bar app with H/J/K/L shortcuts for placing windows and 1/2 for moving them between displays. Written in Swift. No third-party dependencies.

<p align="center"><img src="Assets/Icon.png" width="160" alt="Moove app icon"></p>

## Build and install

Requires macOS 13+ and Apple's Command Line Tools. If you don't have them, run `xcode-select --install`. You don't need full Xcode.

```sh
git clone https://github.com/chriskjaer/moove.git
cd moove
./build.sh
mkdir -p ~/Applications
cp -R dist/Moove.app ~/Applications/
open ~/Applications/Moove.app
```

Allow Moove in **System Settings → Privacy & Security → Accessibility** when prompted. It needs this to move other apps' windows. Input Monitoring isn't needed.

When updating, quit Moove before replacing the app. Run the installed bundle rather than `swift run Moove`, so the permission belongs to the app you're actually using. Local builds are ad-hoc signed, not notarized.

## Usage

Focus a window, then use **Cmd+Ctrl** with:

- **H**: left half
- **J**: bottom half
- **K**: top half
- **L**: right half
- **1**: fill display 1
- **2**: fill display 2

Press the same direction again to cycle through **50% → 75% → 25% → 50%**. Change direction and it starts at half again. Moove looks at the window's actual size, so switching windows doesn't bring a stale counter along.

Display shortcuts fill the usable area, leaving room for the menu bar and Dock. Not fullscreen. No extra Space.

Display 1 is your primary/menu-bar display. The others are numbered left to right, then top to bottom. Open the Moove menu to see the numbers and display names. With only one display, the shortcut for display 2 beeps and leaves the window alone.

### Different modifiers?

Open **Shortcut Modifiers** in the Moove menu and pick any combination of Command, Control, Option and Shift. It applies to all six shortcuts straight away and is remembered next time you open Moove. Want the old bindings? Select Command and Shift, then deselect Control.

At least Command, Control or Option must stay selected. Otherwise Moove would steal normal typing. Quit keeps its usual Cmd+Q binding in the menu.

The letter and number bindings use the physical H/J/K/L/1/2 keys on an ANSI keyboard. They take priority over app-local shortcuts while Moove runs. If another global shortcut has claimed a combination, Moove shows the conflict in its menu. Pick different modifiers or quit the other app. A conflicting choice stays saved until you change it.

## A few things to know

Some apps enforce minimum sizes or resize in steps. Moove reports this in the menu rather than pretending the window landed exactly where requested. It leaves native fullscreen windows and windows that can't be moved or resized alone. A window spanning displays uses the one it overlaps most.

Only the focused window is changed. No network requests, system extensions or launch-at-login setup. Quit Moove to release its shortcuts. To uninstall, quit and delete the app.

If Accessibility is enabled in Settings but Moove still asks for permission, quit it, remove the old Moove entry and add the exact installed app again. Then reopen it. More on signing and permissions in the [development notes](docs/native-development.md).

## Development

```sh
swift run GeometryChecks
swift run ShortcutChecks
./build.sh
codesign --verify --strict dist/Moove.app
```

The checks cover window geometry, size cycling, modifier settings and shortcut mappings without XCTest. You'll still need to try real windows to check global shortcuts, Accessibility and multi-display behavior. The [development notes](docs/native-development.md) cover that workflow.

Moove logs startup, shortcut registration and window-control results to `~/Library/Logs/Moove.log`. No window titles or typed content.

The app icon was generated with Nano Banana Pro. Source artwork is in `Assets/`; `scripts/make-icon.swift` builds the macOS icon during packaging.

## License

MIT, including the icon artwork. See [LICENSE](LICENSE).
