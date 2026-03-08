import CoreGraphics

struct RoomBounds: Equatable {
    let rect: CGRect
    let blockedRects: [CGRect]

    init(rect: CGRect, blockedRects: [CGRect] = []) {
        self.rect = rect
        self.blockedRects = blockedRects
    }

    func clamped(_ position: CGPoint, radius: CGFloat) -> CGPoint {
        CGPoint(
            x: min(max(position.x, rect.minX + radius), rect.maxX - radius),
            y: min(max(position.y, rect.minY + radius), rect.maxY - radius)
        )
    }

    func resolvedPosition(from start: CGPoint, to proposed: CGPoint, radius: CGFloat) -> CGPoint {
        let clampedDestination = clamped(proposed, radius: radius)
        let horizontalDestination = resolveHorizontalMovement(
            from: start,
            to: CGPoint(x: clampedDestination.x, y: start.y),
            radius: radius
        )

        return resolveVerticalMovement(
            from: horizontalDestination,
            to: CGPoint(x: horizontalDestination.x, y: clampedDestination.y),
            radius: radius
        )
    }

    private func resolveHorizontalMovement(from start: CGPoint, to proposed: CGPoint, radius: CGFloat) -> CGPoint {
        var resolved = proposed

        for blockedRect in blockedRects {
            let collisionRect = blockedRect.insetBy(dx: -radius, dy: -radius)
            guard overlapsInterior(of: collisionRect, point: resolved) else {
                continue
            }

            if proposed.x > start.x {
                resolved.x = collisionRect.minX
            } else if proposed.x < start.x {
                resolved.x = collisionRect.maxX
            } else if abs(start.x - collisionRect.minX) < abs(start.x - collisionRect.maxX) {
                resolved.x = collisionRect.minX
            } else {
                resolved.x = collisionRect.maxX
            }
        }

        return resolved
    }

    private func resolveVerticalMovement(from start: CGPoint, to proposed: CGPoint, radius: CGFloat) -> CGPoint {
        var resolved = proposed

        for blockedRect in blockedRects {
            let collisionRect = blockedRect.insetBy(dx: -radius, dy: -radius)
            guard overlapsInterior(of: collisionRect, point: resolved) else {
                continue
            }

            if proposed.y > start.y {
                resolved.y = collisionRect.minY
            } else if proposed.y < start.y {
                resolved.y = collisionRect.maxY
            } else if abs(start.y - collisionRect.minY) < abs(start.y - collisionRect.maxY) {
                resolved.y = collisionRect.minY
            } else {
                resolved.y = collisionRect.maxY
            }
        }

        return resolved
    }

    private func overlapsInterior(of rect: CGRect, point: CGPoint) -> Bool {
        point.x > rect.minX &&
        point.x < rect.maxX &&
        point.y > rect.minY &&
        point.y < rect.maxY
    }
}
