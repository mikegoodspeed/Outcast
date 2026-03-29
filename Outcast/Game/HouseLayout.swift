import CoreGraphics

struct HouseLayout: Equatable {
    let outerRect: CGRect
    let exteriorWallThickness: CGFloat
    let frontDoorWidth: CGFloat

    init(
        outerRect: CGRect,
        exteriorWallThickness: CGFloat,
        frontDoorWidth: CGFloat
    ) {
        self.outerRect = outerRect
        self.exteriorWallThickness = exteriorWallThickness
        self.frontDoorWidth = frontDoorWidth
    }

    var center: CGPoint {
        CGPoint(x: outerRect.midX, y: outerRect.midY)
    }

    var interiorRect: CGRect {
        outerRect.insetBy(dx: exteriorWallThickness, dy: exteriorWallThickness)
    }

    var frontDoorOpeningRect: CGRect {
        CGRect(
            x: center.x - (frontDoorWidth / 2),
            y: outerRect.minY - (exteriorWallThickness / 2),
            width: frontDoorWidth,
            height: exteriorWallThickness
        )
    }

    var southWallSegments: [CGRect] {
        [
            CGRect(
                x: outerRect.minX,
                y: outerRect.minY - (exteriorWallThickness / 2),
                width: frontDoorOpeningRect.minX - outerRect.minX,
                height: exteriorWallThickness
            ),
            CGRect(
                x: frontDoorOpeningRect.maxX,
                y: outerRect.minY - (exteriorWallThickness / 2),
                width: outerRect.maxX - frontDoorOpeningRect.maxX,
                height: exteriorWallThickness
            )
        ].filter { $0.width > 0 }
    }

    var exteriorWallRects: [CGRect] {
        southWallSegments + [
            CGRect(
                x: outerRect.minX,
                y: outerRect.maxY - (exteriorWallThickness / 2),
                width: outerRect.width,
                height: exteriorWallThickness
            ),
            CGRect(
                x: outerRect.minX - (exteriorWallThickness / 2),
                y: outerRect.minY,
                width: exteriorWallThickness,
                height: outerRect.height
            ),
            CGRect(
                x: outerRect.maxX - (exteriorWallThickness / 2),
                y: outerRect.minY,
                width: exteriorWallThickness,
                height: outerRect.height
            )
        ]
    }

    var interiorWallRects: [CGRect] { [] }

    var blockedRects: [CGRect] {
        exteriorWallRects + interiorWallRects + [bedRect]
    }

    var closedDoorRects: [CGRect] {
        [frontDoorOpeningRect]
    }

    func blockedRects(frontDoorOpen: Bool) -> [CGRect] {
        var rects = blockedRects
        if !frontDoorOpen {
            rects.append(frontDoorOpeningRect)
        }
        return rects
    }

    func containsInterior(_ point: CGPoint) -> Bool {
        interiorRect.contains(point)
    }

    func canInteractWithBed(at point: CGPoint, reach: CGFloat) -> Bool {
        bedInteractionRect(reach: reach).contains(point) && !bedRect.contains(point)
    }

    var bedRect: CGRect {
        let bedWidth = interiorRect.width * 0.28
        let bedLength = interiorRect.height * 0.65
        let cornerInset = exteriorWallThickness * 0.85

        return CGRect(
            x: interiorRect.minX + cornerInset,
            y: interiorRect.maxY - cornerInset - bedLength,
            width: bedWidth,
            height: bedLength
        )
    }

    func bedInteractionRect(reach: CGFloat) -> CGRect {
        bedRect.insetBy(dx: -reach, dy: -reach)
    }

    func bedApproachPoint(playerRadius: CGFloat) -> CGPoint {
        CGPoint(
            x: bedRect.maxX + playerRadius + 0.22,
            y: bedRect.minY + (bedRect.height * 0.4)
        )
    }

    var bedSleepPoint: CGPoint {
        CGPoint(
            x: bedRect.midX,
            y: bedRect.minY + (bedRect.height * 0.45)
        )
    }
}
