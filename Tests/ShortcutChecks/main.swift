import Carbon
import Foundation
import MooveShortcuts

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

let suite = "Moove.ShortcutChecks.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
check(ShortcutSettings.load(from: defaults) == [.command, .control], "Fresh installs must use Cmd+Ctrl")
check(ShortcutModifiers.standard.rawValue == UInt32(cmdKey | controlKey), "Default must register Carbon Cmd+Ctrl flags")
check(Shortcut.all.map { $0.label(modifiers: .standard) } == [
    "⌃⌘H   Left half", "⌃⌘J   Bottom half", "⌃⌘K   Top half", "⌃⌘L   Right half",
    "⌃⌘1   Fill display 1", "⌃⌘2   Fill display 2"
], "Menu labels must match the default bindings")
check(Shortcut.all.map(\.key) == [kVK_ANSI_H, kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L, kVK_ANSI_1, kVK_ANSI_2].map(UInt32.init), "Physical keys must not change")
check(Shortcut.all.map(\.placement) == [.left, .bottom, .top, .right, .fill, .fill], "Actions must not change")
check(Shortcut.all.map(\.display) == [nil, nil, nil, nil, 0, 1], "Display routing must not change")

// Exercise every supported combination, including the unsafe empty/Shift-only sets.
let choices = ShortcutModifiers.choices.map(\.value)
for bits in 0..<16 {
    var modifiers = ShortcutModifiers()
    for index in choices.indices where bits & (1 << index) != 0 { modifiers.formUnion(choices[index]) }
    let valid = bits & 7 != 0
    check(modifiers.isValid == valid, "Require Command, Control or Option")
    if valid {
        ShortcutSettings.save(modifiers, to: defaults)
        let reloaded = ShortcutSettings.load(from: UserDefaults(suiteName: suite)!)
        check(reloaded == modifiers, "Selected modifiers must survive a settings reload")
        check(Shortcut.all.allSatisfy { $0.label(modifiers: reloaded).hasPrefix(modifiers.symbols) }, "Every label must use the selected modifiers")
    }
}
let legacy: ShortcutModifiers = [.command, .shift]
ShortcutSettings.save(legacy, to: defaults)
check(ShortcutSettings.load(from: defaults) == legacy, "Users can restore Cmd+Shift")
check(Shortcut.all[0].label(modifiers: legacy) == "⇧⌘H   Left half", "Legacy labels must follow the selection")
ShortcutSettings.save(.shift, to: defaults)
check(ShortcutSettings.load(from: defaults) == legacy, "Invalid choices must not overwrite preferences")
for invalid: Any in [0, Int(shiftKey), -1, Int(UInt32.max), "invalid"] {
    defaults.set(invalid, forKey: "shortcutModifiers")
    check(ShortcutSettings.load(from: defaults) == .standard, "Malformed or unsafe preferences must fall back safely")
}
print("Passed shortcut checks (defaults, all modifier combinations, persistence, invalid settings, labels, physical keys and actions).")
