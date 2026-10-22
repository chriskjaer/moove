import Carbon
import Foundation
import WindowGeometry

public struct ShortcutModifiers: OptionSet, Equatable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let command = Self(rawValue: UInt32(cmdKey))
    public static let control = Self(rawValue: UInt32(controlKey))
    public static let option = Self(rawValue: UInt32(optionKey))
    public static let shift = Self(rawValue: UInt32(shiftKey))
    public static let standard: Self = [.command, .control]
    public static let choices: [(name: String, value: Self)] = [
        ("Command ⌘", .command), ("Control ⌃", .control),
        ("Option ⌥", .option), ("Shift ⇧", .shift)
    ]

    // A bare key or Shift alone would steal ordinary typing globally.
    public var isValid: Bool {
        let supported: Self = [.command, .control, .option, .shift]
        return rawValue & ~supported.rawValue == 0 && !intersection([.command, .control, .option]).isEmpty
    }

    public var symbols: String {
        [(Self.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
            .filter { contains($0.0) }.map { $0.1 }.joined()
    }
}

public struct Shortcut {
    public let key: UInt32
    public let character: String
    public let title: String
    public let placement: Placement
    public let display: Int?

    public func label(modifiers: ShortcutModifiers) -> String {
        "\(modifiers.symbols)\(character)   \(title)"
    }

    public static let all: [Shortcut] = [
        Shortcut(key: UInt32(kVK_ANSI_H), character: "H", title: "Left half", placement: .left, display: nil),
        Shortcut(key: UInt32(kVK_ANSI_J), character: "J", title: "Bottom half", placement: .bottom, display: nil),
        Shortcut(key: UInt32(kVK_ANSI_K), character: "K", title: "Top half", placement: .top, display: nil),
        Shortcut(key: UInt32(kVK_ANSI_L), character: "L", title: "Right half", placement: .right, display: nil),
        Shortcut(key: UInt32(kVK_ANSI_1), character: "1", title: "Fill display 1", placement: .fill, display: 0),
        Shortcut(key: UInt32(kVK_ANSI_2), character: "2", title: "Fill display 2", placement: .fill, display: 1)
    ]
}

public enum ShortcutSettings {
    private static let key = "shortcutModifiers"

    public static func load(from defaults: UserDefaults = .standard) -> ShortcutModifiers {
        guard let number = defaults.object(forKey: key) as? NSNumber,
              let rawValue = UInt32(exactly: number.int64Value) else { return .standard }
        let modifiers = ShortcutModifiers(rawValue: rawValue)
        return modifiers.isValid ? modifiers : .standard
    }

    public static func save(_ modifiers: ShortcutModifiers, to defaults: UserDefaults = .standard) {
        guard modifiers.isValid else { return }
        defaults.set(Int(modifiers.rawValue), forKey: key)
    }
}
