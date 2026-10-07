import AppKit
import ApplicationServices
import Carbon
import WindowGeometry

struct Shortcut {
    let key: UInt32
    let label: String
    let placement: Placement
    let display: Int?
}

let shortcuts: [Shortcut] = [
    Shortcut(key: UInt32(kVK_ANSI_H), label: "⇧⌘H   Left half", placement: .left, display: nil),
    Shortcut(key: UInt32(kVK_ANSI_J), label: "⇧⌘J   Bottom half", placement: .bottom, display: nil),
    Shortcut(key: UInt32(kVK_ANSI_K), label: "⇧⌘K   Top half", placement: .top, display: nil),
    Shortcut(key: UInt32(kVK_ANSI_L), label: "⇧⌘L   Right half", placement: .right, display: nil),
    Shortcut(key: UInt32(kVK_ANSI_1), label: "⇧⌘1   Fill display 1", placement: .fill, display: 0),
    Shortcut(key: UInt32(kVK_ANSI_2), label: "⇧⌘2   Fill display 2", placement: .fill, display: 1)
]

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeys: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var registrationFailures: [String] = []
    private var lastResult = "Ready"
    private let signature: OSType = 0x4D4F4F56 // MOOV

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Moove")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        registerShortcuts()
        record("Started. Accessibility trusted: \(AXIsProcessTrusted()). Registered shortcuts: \(hotkeys.count)/\(shortcuts.count).")
        for failure in registrationFailures { record(failure) }
        rebuildMenu()
        if !AXIsProcessTrusted() { requestPermission() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeys.forEach { UnregisterEventHotKey($0) }
        if let handler { RemoveEventHandler(handler) }
    }

    func menuWillOpen(_ menu: NSMenu) { rebuildMenu() }

    // NSScreen.screens[0] is the menu-bar/primary display, unlike NSScreen.main,
    // which can change with focus. Remaining displays are ordered spatially.
    private var screens: [NSScreen] {
        let all = NSScreen.screens
        guard let primary = all.first else { return [] }
        return [primary] + all.dropFirst().sorted {
            if $0.frame.minX != $1.frame.minX { return $0.frame.minX < $1.frame.minX }
            return $0.frame.maxY > $1.frame.maxY
        }
    }

    private func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()
        addLabel("Moove")
        addLabel(AXIsProcessTrusted() ? "Accessibility: enabled" : "Accessibility: permission needed")
        addLabel(lastResult)
        for failure in registrationFailures { addLabel(failure) }
        menu.addItem(.separator())
        for shortcut in shortcuts { addLabel(shortcut.label) }
        addLabel("Repeat a side: 50% → 75% → 25%")
        menu.addItem(.separator())
        for (index, screen) in screens.enumerated() {
            addLabel("Display \(index + 1): \(screen.localizedName)\(index == 0 ? " (primary)" : "")")
        }
        menu.addItem(.separator())
        let permission = menu.addItem(withTitle: "Grant Accessibility Permission…", action: #selector(requestPermission), keyEquivalent: "")
        permission.target = self
        let quit = menu.addItem(withTitle: "Quit Moove", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
    }

    private func addLabel(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        statusItem.menu?.addItem(item)
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    @objc private func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func registerShortcuts() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard result == noErr else { return result }
            let app = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            guard id.signature == app.signature, id.id > 0, Int(id.id) <= shortcuts.count else {
                return OSStatus(eventNotHandledErr)
            }
            app.perform(shortcuts[Int(id.id) - 1])
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard result == noErr else {
            registrationFailures.append("Hotkey handler failed: \(result)")
            return
        }
        for (index, shortcut) in shortcuts.enumerated() {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: signature, id: UInt32(index + 1))
            let status = RegisterEventHotKey(shortcut.key, UInt32(cmdKey | shiftKey), id, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { hotkeys.append(ref) }
            else { registrationFailures.append("Unavailable: \(shortcut.label) (\(status))") }
        }
    }

    private func record(_ message: String) {
        // No window titles, app names, or typed content are written to this log.
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
        let file = directory.appendingPathComponent("Moove.log")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        if !FileManager.default.fileExists(atPath: file.path) {
            FileManager.default.createFile(atPath: file.path, contents: nil)
        }
        guard let data = line.data(using: .utf8), let handle = try? FileHandle(forWritingTo: file) else { return }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch { /* Diagnostics must not prevent window control. */ }
    }

    private func fail(_ message: String) {
        record(message)
        lastResult = message
        statusItem.button?.toolTip = message
        NSSound.beep()
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private func perform(_ shortcut: Shortcut) {
        record("Received shortcut: \(shortcut.label). Accessibility trusted: \(AXIsProcessTrusted()).")
        guard AXIsProcessTrusted() else { fail("Grant Accessibility permission from the Moove menu."); return }
        guard let app = NSWorkspace.shared.frontmostApplication else { fail("No active app."); return }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(axApp, 1)
        guard let value = attribute(axApp, kAXFocusedWindowAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() else {
            fail("This app has no accessible focused window."); return
        }
        let window = value as! AXUIElement
        if let fullscreen = attribute(window, "AXFullScreen") as? Bool, fullscreen {
            fail("Exit macOS fullscreen before moving this window."); return
        }
        guard let position = attribute(window, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(window, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else {
            fail("Cannot read this window's frame."); return
        }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else {
            fail("Cannot read this window's geometry."); return
        }
        let displays = screens
        guard let primary = displays.first else { fail("No displays available."); return }
        let frames = displays.map { WindowGeometry.accessibilityFrame($0.frame, primaryTop: primary.frame.maxY) }
        guard let index = shortcut.display ?? WindowGeometry.currentDisplay(for: CGRect(origin: point, size: dimensions), displays: frames), displays.indices.contains(index) else {
            fail("Display \((shortcut.display ?? 0) + 1) is not connected."); return
        }
        let usable = WindowGeometry.accessibilityFrame(displays[index].visibleFrame, primaryTop: primary.frame.maxY)
        let target = WindowGeometry.nextTarget(shortcut.placement, in: usable, current: CGRect(origin: point, size: dimensions))
        var positionSettable: DarwinBoolean = false
        var sizeSettable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &positionSettable) == .success,
              AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &sizeSettable) == .success,
              positionSettable.boolValue, sizeSettable.boolValue else {
            fail("This window does not support moving and resizing."); return
        }
        var origin = target.origin
        var newSize = target.size
        let positionValue = AXValueCreate(.cgPoint, &origin)!
        let sizeValue = AXValueCreate(.cgSize, &newSize)!
        // Shrink first, then move, then resize again: apps may clamp size to the
        // old display during a transfer to a larger or smaller display.
        let initialSize = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        let moved = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        let resized = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        let positioned = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        guard moved == .success, resized == .success, positioned == .success else {
            fail("Window change failed (size \(initialSize.rawValue)/\(resized.rawValue), position \(moved.rawValue)/\(positioned.rawValue))."); return
        }
        guard let actualPosition = attribute(window, kAXPositionAttribute), CFGetTypeID(actualPosition) == AXValueGetTypeID(),
              let actualSize = attribute(window, kAXSizeAttribute), CFGetTypeID(actualSize) == AXValueGetTypeID() else {
            fail("Requested window change; unable to verify resulting frame."); return
        }
        var finalPoint = CGPoint.zero
        var finalSize = CGSize.zero
        guard AXValueGetValue(actualPosition as! AXValue, .cgPoint, &finalPoint),
              AXValueGetValue(actualSize as! AXValue, .cgSize, &finalSize) else {
            fail("Requested window change; unable to verify resulting frame."); return
        }
        if abs(finalPoint.x - origin.x) > 3 || abs(finalPoint.y - origin.y) > 3 ||
           abs(finalSize.width - newSize.width) > 3 || abs(finalSize.height - newSize.height) > 3 {
            fail("The app adjusted the requested frame (for example, a minimum size or resize grid)."); return
        }
        record("Window frame verified on display \(index + 1).")
        lastResult = "Moved \(app.localizedName ?? "window") to display \(index + 1)"
        statusItem.button?.toolTip = lastResult
    }
}

if CommandLine.arguments.contains("--diagnostics") {
    print("Accessibility trusted for this Moove build: \(AXIsProcessTrusted())")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
