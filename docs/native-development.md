# Native macOS development checklist

Moove is a standalone Swift menu-bar app built with Apple's Command Line Tools. This guide keeps build success separate from actual runtime behavior, because macOS permissions, application identity, running processes, and cached bundle metadata can each fail independently.

## Build, package, then verify

Run from the project root:

```sh
swift run GeometryChecks
swift run ShortcutChecks
./build.sh
codesign --verify --strict dist/Moove.app
plutil -lint dist/Moove.app/Contents/Info.plist
```

`swift build` compiles the executable; `build.sh` also generates the icon, copies bundle resources and metadata, signs the assembled bundle, updates its modification time, and registers it with Launch Services. Source edits alone do not update a running app. Incremental Swift builds may correctly reuse an unchanged executable while icon resources are regenerated.

This checkout supports checks without XCTest through `GeometryChecks` and `ShortcutChecks`. Shortcut checks cover modifier configuration, saved preferences, labels and action mappings. Actual re-registration, conflict reporting and release of previous hotkeys must also be checked in the running app by changing **Shortcut Modifiers**, exercising old/new combinations, and restarting to verify persistence. Do not promise `swift test` works with Command Line Tools alone: XCTest was unavailable in the local toolchain. Geometry checks cover owned placement logic, not global hotkeys, Accessibility authorization, or third-party window behavior.

## Run one exact bundle

Choose either `dist/Moove.app` during development or an installed copy under `~/Applications`. Grant permission to that same bundle. Do not unknowingly alternate between them.

Before replacing or reopening the app, identify the process:

```sh
pgrep -fl 'Moove.app/Contents/MacOS/Moove'
# Replace <pid> with the confirmed Moove process ID.
ps -p <pid> -o lstart=,command=
lsof -a -p <pid> -d txt -Fn
```

Quit through the menu, or terminate only the verified Moove PID. Rebuild, then launch the chosen bundle with `open`. Compare its executable modification time with process start time when investigating an old-version report. A successful `open` call does not prove the UI or shortcuts work, and opening an already-running app does not replace that process.

## Treat permissions as runtime state

The System Settings toggle is not sufficient evidence of permission for the current build. Read the running app's `AXIsProcessTrusted()` result from the menu or `~/Library/Logs/Moove.log`.

A terminal invocation of `Moove --diagnostics` may have different permission attribution than the app launched through `open`. The GUI process's own result is the relevant one for window control.

Inspect signing identity with:

```sh
codesign -d -r- dist/Moove.app
```

Default ad-hoc signatures use a designated requirement containing the executable hash. Rebuilding changes that hash, which can leave an enabled Accessibility entry that does not authorize the new build. Moove's personal local build uses an explicit identifier-based requirement instead. This keeps the requirement text stable; it is not proof that macOS will retain authorization across every update, and it is not an authenticated developer identity. Use an appropriate developer signing identity for distribution rather than generalizing this local workaround.

If the running app reports permission needed despite an enabled Settings entry:

1. Quit Moove.
2. Remove its old Accessibility entry.
3. Add the exact bundle you intend to launch and enable it.
4. Reopen and check the app's own trust result.

Do not reset all Accessibility permissions or modify the TCC database to repair one app.

## Diagnose at the failing boundary

Use `~/Library/Logs/Moove.log` to distinguish these cases:

- **No trusted startup:** resolve app identity/permission first.
- **Fewer than six registered shortcuts:** inspect registration failures and conflicting global shortcuts.
- **Trusted startup and registrations, but no received shortcut:** investigate event delivery, key layout, and focus instead of changing geometry.
- **Received shortcut with an AX error:** inspect the focused window's supported attributes and setter results.
- **Frame adjusted:** the app may enforce minimum sizes or resize increments. Successful setters do not prove the requested frame was applied; read it back.

The log deliberately excludes window titles, app names, and typed content. Do not broaden logging to capture user content just to debug shortcut delivery.

## Window placement is an integration contract

Keep layout calculations in logical points. Convert AppKit's bottom-left coordinates to Accessibility's top-left coordinates using the primary display's top edge, not the focused display. Use `visibleFrame` to preserve menu-bar and Dock space.

Test negative origins, displays above and below the primary, greatest-overlap selection, nearest-display recovery, and every anchored size cycle. Repeat these on actual differently scaled displays before claiming end-to-end coverage. Apps can adjust requested geometry; Moove's 3-point cycle matching may reset to 50% when an app clamps outside that tolerance.

## Verify icon resolution separately from packaging

An icon requires both the resource and its plist reference:

- `Contents/Resources/Moove.icns`
- `CFBundleIconFile` in `Contents/Info.plist`

Finder can continue showing old metadata after resources change within an existing bundle directory. `build.sh` touches the bundle and refreshes its Launch Services registration to request a reload. Do not assume recompilation alone refreshes Finder.

For a source-of-truth check, retrieve the icon for the exact bundle using `NSWorkspace.shared.icon(forFile:)` and inspect it. That proves system resolution, not that an already-open Finder window refreshed; check Finder separately. Prefer closing/reopening the folder over clearing global icon caches or restarting Finder without permission.

Moove's `.icns` is a static icon with standard size representations. A glass-like raster image is not an adaptive Liquid Glass icon; that requires Apple's separate Icon Composer workflow. Keep the menu-bar symbol monochrome for system appearance compatibility.

## Handoff evidence

Report separately:

- build, bundle metadata, and signature checks;
- automated geometry checks;
- runtime trust and shortcut registration;
- actual shortcut receipt and observed window placement;
- system icon resolution and visible Finder rendering.

Only call a behavior verified when it was exercised at the relevant boundary. User confirmation of a successful shortcut is useful runtime evidence, but does not establish every direction, size, display arrangement, or update scenario.
