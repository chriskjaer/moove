import Foundation
import CoreGraphics

public enum Placement {
    case left, right, top, bottom, fill
}

public enum WindowGeometry {
    // AX uses top-left coordinates; AppKit uses bottom-left coordinates.
    // Both are in points, not backing pixels, including mixed-scale displays.
    public static func accessibilityFrame(_ frame: CGRect, primaryTop: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryTop - frame.maxY, width: frame.width, height: frame.height)
    }

    public static func nextTarget(_ placement: Placement, in frame: CGRect, current: CGRect) -> CGRect {
        guard placement != .fill else { return frame }
        let fractions: [CGFloat] = [0.5, 0.75, 0.25]
        for (index, fraction) in fractions.enumerated() {
            let candidate = target(placement, in: frame, fraction: fraction)
            if abs(current.minX - candidate.minX) <= 3, abs(current.minY - candidate.minY) <= 3,
               abs(current.width - candidate.width) <= 3, abs(current.height - candidate.height) <= 3 {
                return target(placement, in: frame, fraction: fractions[(index + 1) % fractions.count])
            }
        }
        return target(placement, in: frame)
    }

    public static func target(_ placement: Placement, in frame: CGRect, fraction: CGFloat = 0.5) -> CGRect {
        switch placement {
        case .left:
            return CGRect(x: frame.minX, y: frame.minY, width: frame.width * fraction, height: frame.height)
        case .right:
            return CGRect(x: frame.maxX - frame.width * fraction, y: frame.minY, width: frame.width * fraction, height: frame.height)
        case .top:
            return CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height * fraction)
        case .bottom:
            return CGRect(x: frame.minX, y: frame.maxY - frame.height * fraction, width: frame.width, height: frame.height * fraction)
        case .fill:
            return frame
        }
    }

    public static func currentDisplay(for window: CGRect, displays: [CGRect]) -> Int? {
        guard !displays.isEmpty else { return nil }
        let areas = displays.map { frame -> CGFloat in
            let overlap = window.intersection(frame)
            return overlap.isNull ? 0 : overlap.width * overlap.height
        }
        if let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 { return best }
        // Recover windows stranded by an unplugged display using the closest center.
        return displays.indices.min { a, b in
            let da = pow(displays[a].midX - window.midX, 2) + pow(displays[a].midY - window.midY, 2)
            let db = pow(displays[b].midX - window.midX, 2) + pow(displays[b].midY - window.midY, 2)
            return da < db
        }
    }
}
