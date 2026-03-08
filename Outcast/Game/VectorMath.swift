import CoreGraphics

extension CGVector {
    var magnitude: CGFloat {
        sqrt((dx * dx) + (dy * dy))
    }

    var normalized: CGVector {
        let length = magnitude
        guard length > 0 else {
            return .zero
        }

        return CGVector(dx: dx / length, dy: dy / length)
    }

    var clampedToUnit: CGVector {
        let length = magnitude
        guard length > 1 else {
            return self
        }

        return normalized
    }
}

