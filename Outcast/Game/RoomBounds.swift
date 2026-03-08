import CoreGraphics

struct RoomBounds: Equatable {
    let rect: CGRect

    func clamped(_ position: CGPoint, radius: CGFloat) -> CGPoint {
        CGPoint(
            x: min(max(position.x, rect.minX + radius), rect.maxX - radius),
            y: min(max(position.y, rect.minY + radius), rect.maxY - radius)
        )
    }
}

