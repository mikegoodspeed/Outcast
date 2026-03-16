import Foundation
import CoreGraphics

struct WorldLayout: Equatable {
    let worldRect: CGRect
    let groundRect: CGRect
    let mainPlayableRect: CGRect
    let movementRect: CGRect
    let roadCorridorRect: CGRect
    let roadSurfaceRect: CGRect
    let roadTreeClearanceRect: CGRect
    let blockedRects: [CGRect]

    init(
        worldRect: CGRect,
        barrierInset: CGFloat,
        roadCorridorWidth: CGFloat,
        roadCorridorRightInset: CGFloat,
        roadExitInset: CGFloat,
        roadSurfaceWidth: CGFloat,
        roadLeadIn: CGFloat,
        roadLookahead: CGFloat,
        groundNorthOverscan: CGFloat,
        treeClearanceX: CGFloat,
        treeClearanceY: CGFloat
    ) {
        self.worldRect = worldRect
        mainPlayableRect = worldRect.insetBy(dx: barrierInset, dy: barrierInset)

        let corridorMaxX = mainPlayableRect.maxX - roadCorridorRightInset
        let corridorMinX = corridorMaxX - roadCorridorWidth
        let corridorMaxY = worldRect.maxY - roadExitInset

        roadCorridorRect = CGRect(
            x: corridorMinX,
            y: mainPlayableRect.maxY,
            width: roadCorridorWidth,
            height: corridorMaxY - mainPlayableRect.maxY
        )
        movementRect = CGRect(
            x: mainPlayableRect.minX,
            y: mainPlayableRect.minY,
            width: mainPlayableRect.width,
            height: corridorMaxY - mainPlayableRect.minY
        )
        roadSurfaceRect = CGRect(
            x: roadCorridorRect.midX - (roadSurfaceWidth / 2),
            y: mainPlayableRect.maxY - roadLeadIn,
            width: roadSurfaceWidth,
            height: (movementRect.maxY - (mainPlayableRect.maxY - roadLeadIn)) + roadLookahead
        )
        groundRect = worldRect.union(
            CGRect(
                x: worldRect.minX,
                y: worldRect.minY,
                width: worldRect.width,
                height: (roadSurfaceRect.maxY - worldRect.minY) + groundNorthOverscan
            )
        )
        roadTreeClearanceRect = roadSurfaceRect.insetBy(dx: -treeClearanceX, dy: -treeClearanceY)

        let upperBandHeight = movementRect.maxY - mainPlayableRect.maxY
        blockedRects = [
            CGRect(
                x: movementRect.minX,
                y: mainPlayableRect.maxY,
                width: roadCorridorRect.minX - movementRect.minX,
                height: upperBandHeight
            ),
            CGRect(
                x: roadCorridorRect.maxX,
                y: mainPlayableRect.maxY,
                width: movementRect.maxX - roadCorridorRect.maxX,
                height: upperBandHeight
            )
        ].filter { $0.width > 0 && $0.height > 0 }
    }
}

enum GameConstants {
    static let playerRadius: CGFloat = 0.48
    static let walkInputThreshold: CGFloat = 0.7
    static let walkSpeed: CGFloat = 5.2
    static let runSpeed: CGFloat = 9.0
    static let worldWidth: CGFloat = 91.2
    static let worldHeight: CGFloat = 76.8
    static let worldRect = CGRect(
        x: -(worldWidth / 2),
        y: -(worldHeight / 2),
        width: worldWidth,
        height: worldHeight
    )
    static let roomInteriorMargin: CGFloat = 4.2
    static let roomCornerRadius: CGFloat = 0.6
    static let treeBarrierDepth: CGFloat = 14
    static let frontTreeSize: CGFloat = 1.8
    static let backTreeSize: CGFloat = 1.55
    static let treeSpacing: CGFloat = 2.04
    static let treeRowOffset: CGFloat = 1.92
    static let worldBarrierInset: CGFloat = roomInteriorMargin + treeBarrierDepth
    static let worldLayout = WorldLayout(
        worldRect: worldRect,
        barrierInset: worldBarrierInset,
        roadCorridorWidth: 6.8,
        roadCorridorRightInset: 2.8,
        roadExitInset: 2.4,
        roadSurfaceWidth: 5.8,
        roadLeadIn: 7.4,
        roadLookahead: 10.8,
        groundNorthOverscan: 16.0,
        treeClearanceX: 0.9,
        treeClearanceY: 1.35
    )
    static let houseWidth: CGFloat = 6.8
    static let houseDepth: CGFloat = 5.6
    static let houseWallHeight: CGFloat = 3.9
    static let houseDoorY: CGFloat = 4.4
    static let houseExteriorWallThickness: CGFloat = 0.34
    static let houseFrontDoorWidth: CGFloat = 2.1
    static let doorInteractionReach: CGFloat = 0.9
    static let bedInteractionReach: CGFloat = 0.95
    static let spawnHouseCenter = CGPoint(
        x: 0,
        y: houseDoorY + (houseDepth / 2)
    )
    static let spawnHouseRect = CGRect(
        x: -(houseWidth / 2),
        y: houseDoorY,
        width: houseWidth,
        height: houseDepth
    )
    static let spawnHouseLayout = HouseLayout(
        outerRect: spawnHouseRect,
        exteriorWallThickness: houseExteriorWallThickness,
        frontDoorWidth: houseFrontDoorWidth
    )
    static let groundThickness: CGFloat = 0.24
    static let cameraHeight: CGFloat = 10.4
    static let cameraDistance: CGFloat = 6.8
    static let cameraTilt: CGFloat = -0.66
    static let joystickSize = CGSize(width: 144, height: 144)
    static let joystickMargin: CGFloat = 24
    static let actionButtonSize = CGSize(width: 58, height: 58)
    static let actionButtonOffset = CGPoint(x: 68, y: 88)
    static let interactionPromptCornerRadius: CGFloat = 18
    static let interactionPromptBottomInset: CGFloat = 28
    static let interactionPromptHorizontalInset: CGFloat = 20
    static let interactionPromptMinHeight: CGFloat = 78
    static let interactionPromptButtonSize: CGFloat = 42
    static let daylightCycleDuration: TimeInterval = 15 * 60
    static let sleepFadeDuration: TimeInterval = 0.55
    static let sleepBlackoutDuration: TimeInterval = 2.0
}
