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
            let overlapsResolvedPoint = overlapsInterior(of: collisionRect, point: resolved)
            let crossesWall = crossesHorizontalBoundary(of: collisionRect, from: start, to: proposed)

            guard overlapsResolvedPoint || crossesWall else {
                continue
            }

            if proposed.x > start.x {
                resolved.x = min(resolved.x, collisionRect.minX)
            } else if proposed.x < start.x {
                resolved.x = max(resolved.x, collisionRect.maxX)
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
            let overlapsResolvedPoint = overlapsInterior(of: collisionRect, point: resolved)
            let crossesWall = crossesVerticalBoundary(of: collisionRect, from: start, to: proposed)

            guard overlapsResolvedPoint || crossesWall else {
                continue
            }

            if proposed.y > start.y {
                resolved.y = min(resolved.y, collisionRect.minY)
            } else if proposed.y < start.y {
                resolved.y = max(resolved.y, collisionRect.maxY)
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

    private func crossesHorizontalBoundary(of rect: CGRect, from start: CGPoint, to proposed: CGPoint) -> Bool {
        guard start.y > rect.minY && start.y < rect.maxY else {
            return false
        }

        if proposed.x > start.x {
            return start.x <= rect.minX && proposed.x > rect.minX
        }

        if proposed.x < start.x {
            return start.x >= rect.maxX && proposed.x < rect.maxX
        }

        return false
    }

    private func crossesVerticalBoundary(of rect: CGRect, from start: CGPoint, to proposed: CGPoint) -> Bool {
        guard start.x > rect.minX && start.x < rect.maxX else {
            return false
        }

        if proposed.y > start.y {
            return start.y <= rect.minY && proposed.y > rect.minY
        }

        if proposed.y < start.y {
            return start.y >= rect.maxY && proposed.y < rect.maxY
        }

        return false
    }
}
