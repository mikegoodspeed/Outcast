import CoreGraphics

enum DirectionKey: CaseIterable, Hashable {
    case up
    case down
    case left
    case right
}

final class InputController {
    private enum InputSource {
        case keyboard
        case joystick
    }

    private var pressedKeys: Set<DirectionKey> = []
    private var keyboardVector: CGVector = .zero
    private var joystickVector: CGVector = .zero
    private var keyboardEventIndex = 0
    private var joystickEventIndex = 0
    private var eventCounter = 0

    func setKey(_ key: DirectionKey, isPressed: Bool) {
        if isPressed {
            pressedKeys.insert(key)
        } else {
            pressedKeys.remove(key)
        }

        keyboardVector = Self.vector(for: pressedKeys)
        if keyboardVector != .zero {
            keyboardEventIndex = nextEventIndex()
        }
    }

    func setJoystickVector(_ vector: CGVector) {
        joystickVector = vector.clampedToUnit
        if joystickVector != .zero {
            joystickEventIndex = nextEventIndex()
        }
    }

    func currentMovementVector() -> CGVector {
        let activeKeyboard = keyboardVector != .zero
        let activeJoystick = joystickVector != .zero

        switch (activeKeyboard, activeJoystick) {
        case (false, false):
            return .zero
        case (true, false):
            return keyboardVector
        case (false, true):
            return joystickVector
        case (true, true):
            return keyboardEventIndex >= joystickEventIndex ? keyboardVector : joystickVector
        }
    }

    func reset() {
        pressedKeys.removeAll()
        keyboardVector = .zero
        joystickVector = .zero
        keyboardEventIndex = 0
        joystickEventIndex = 0
        eventCounter = 0
    }

    private func nextEventIndex() -> Int {
        eventCounter += 1
        return eventCounter
    }

    private static func vector(for keys: Set<DirectionKey>) -> CGVector {
        let horizontal = (keys.contains(.right) ? 1.0 : 0.0) - (keys.contains(.left) ? 1.0 : 0.0)
        let vertical = (keys.contains(.up) ? 1.0 : 0.0) - (keys.contains(.down) ? 1.0 : 0.0)
        return CGVector(dx: horizontal, dy: vertical).normalized
    }
}

