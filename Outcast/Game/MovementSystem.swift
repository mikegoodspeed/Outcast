import CoreGraphics
import Foundation

struct MovementSystem {
    func move(
        from position: CGPoint,
        inputVector: CGVector,
        deltaTime: TimeInterval,
        speed: CGFloat,
        radius: CGFloat,
        within roomBounds: RoomBounds
    ) -> CGPoint {
        let clampedVector = inputVector.clampedToUnit
        let nextPosition = CGPoint(
            x: position.x + (clampedVector.dx * speed * deltaTime),
            y: position.y + (clampedVector.dy * speed * deltaTime)
        )

        return roomBounds.resolvedPosition(from: position, to: nextPosition, radius: radius)
    }
}
