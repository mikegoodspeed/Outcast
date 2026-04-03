import Foundation
import CoreGraphics

struct WorldLayout: Equatable {
    let worldRect: CGRect
    let groundRect: CGRect
    let mainPlayableRect: CGRect
    let movementRect: CGRect
    let roadCorridorRect: CGRect
    let roadSurfaceRect: CGRect
    let northRoadReturnPoint: CGPoint
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
        northRoadReturnPoint = CGPoint(
            x: roadCorridorRect.midX,
            y: roadCorridorRect.maxY - 3.2
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

struct CrossroadsLayout: Equatable {
    let worldRect: CGRect
    let movementRect: CGRect
    let spawnPoint: CGPoint
    let westTransitionPoint: CGPoint
    let eastTransitionPoint: CGPoint
    let verticalRoadRect: CGRect
    let horizontalRoadRect: CGRect
    let trafficLaneYs: [CGFloat]
    let trafficWrapRange: ClosedRange<CGFloat>

    init(
        worldRect: CGRect,
        barrierInset: CGFloat,
        verticalRoadWidth: CGFloat,
        horizontalRoadHeight: CGFloat,
        approachLead: CGFloat,
        intersectionOffset: CGFloat,
        trafficWrapInset: CGFloat
    ) {
        self.worldRect = worldRect
        movementRect = worldRect.insetBy(dx: barrierInset, dy: barrierInset)

        let roadCenterY = movementRect.minY + intersectionOffset
        horizontalRoadRect = CGRect(
            x: worldRect.minX - 6,
            y: roadCenterY - (horizontalRoadHeight / 2),
            width: worldRect.width + 12,
            height: horizontalRoadHeight
        )
        let approachRoadMinY = movementRect.minY - 3.4
        let approachRoadMaxY = horizontalRoadRect.minY
        verticalRoadRect = CGRect(
            x: -(verticalRoadWidth / 2),
            y: approachRoadMinY,
            width: verticalRoadWidth,
            height: approachRoadMaxY - approachRoadMinY
        )
        spawnPoint = CGPoint(
            x: verticalRoadRect.midX,
            y: movementRect.minY + approachLead
        )
        westTransitionPoint = CGPoint(
            x: movementRect.minX + approachLead,
            y: horizontalRoadRect.midY
        )
        eastTransitionPoint = CGPoint(
            x: movementRect.maxX - approachLead,
            y: horizontalRoadRect.midY
        )
        let laneOffset = horizontalRoadHeight * 0.25
        trafficLaneYs = [
            horizontalRoadRect.midY - laneOffset,
            horizontalRoadRect.midY + laneOffset
        ]
        trafficWrapRange = (worldRect.minX - trafficWrapInset)...(worldRect.maxX + trafficWrapInset)
    }
}

struct ShellBuildingLayout: Equatable {
    let outerRect: CGRect
    let wallThickness: CGFloat
    let frontDoorWidth: CGFloat

    var center: CGPoint {
        CGPoint(x: outerRect.midX, y: outerRect.midY)
    }

    var interiorRect: CGRect {
        outerRect.insetBy(dx: wallThickness, dy: wallThickness)
    }

    var frontDoorRect: CGRect {
        CGRect(
            x: center.x - (frontDoorWidth / 2),
            y: outerRect.minY - (wallThickness / 2),
            width: frontDoorWidth,
            height: wallThickness
        )
    }

    var southWallSegments: [CGRect] {
        [
            CGRect(
                x: outerRect.minX,
                y: outerRect.minY - (wallThickness / 2),
                width: frontDoorRect.minX - outerRect.minX,
                height: wallThickness
            ),
            CGRect(
                x: frontDoorRect.maxX,
                y: outerRect.minY - (wallThickness / 2),
                width: outerRect.maxX - frontDoorRect.maxX,
                height: wallThickness
            )
        ].filter { $0.width > 0 }
    }

    var wallRects: [CGRect] {
        southWallSegments + [
            CGRect(
                x: outerRect.minX,
                y: outerRect.maxY - (wallThickness / 2),
                width: outerRect.width,
                height: wallThickness
            ),
            CGRect(
                x: outerRect.minX - (wallThickness / 2),
                y: outerRect.minY,
                width: wallThickness,
                height: outerRect.height
            ),
            CGRect(
                x: outerRect.maxX - (wallThickness / 2),
                y: outerRect.minY,
                width: wallThickness,
                height: outerRect.height
            )
        ]
    }

    var blockedRects: [CGRect] {
        wallRects + [frontDoorRect]
    }

    func blockedRects(frontDoorOpen: Bool) -> [CGRect] {
        if frontDoorOpen {
            return wallRects
        }
        return blockedRects
    }

    func containsInterior(_ point: CGPoint) -> Bool {
        interiorRect.contains(point)
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
    static let crossroadsLayout = CrossroadsLayout(
        worldRect: worldRect,
        barrierInset: worldBarrierInset,
        verticalRoadWidth: 6.8,
        horizontalRoadHeight: 10.8,
        approachLead: 4.8,
        intersectionOffset: 16.8,
        trafficWrapInset: 12.0
    )
    static let traffic3WorldWidth: CGFloat = (worldWidth * 3) + 24.0
    static let traffic3WorldRect = CGRect(
        x: -(traffic3WorldWidth / 2),
        y: -(worldHeight / 2),
        width: traffic3WorldWidth,
        height: worldHeight
    )
    static let traffic3Layout = CrossroadsLayout(
        worldRect: traffic3WorldRect,
        barrierInset: worldBarrierInset,
        verticalRoadWidth: 6.8,
        horizontalRoadHeight: 10.8,
        approachLead: 4.8,
        intersectionOffset: 16.8,
        trafficWrapInset: 12.0
    )
    static let clearNewsBuildingLayout = ShellBuildingLayout(
        outerRect: CGRect(
            x: traffic3Layout.eastTransitionPoint.x - 18.2,
            y: traffic3Layout.horizontalRoadRect.maxY + 4.4,
            width: 20.0,
            height: 13.0
        ),
        wallThickness: 0.48,
        frontDoorWidth: 3.4
    )
    static let clearNewsThirdFloorLayout = ShellBuildingLayout(
        outerRect: clearNewsBuildingLayout.outerRect,
        wallThickness: clearNewsBuildingLayout.wallThickness,
        frontDoorWidth: 0
    )
    static let clearNewsWallHeight: CGFloat = 6.2
    static let clearNewsFloorHeight: CGFloat = 0.08
    static let clearNewsSpawnPoint = CGPoint(
        x: clearNewsBuildingLayout.center.x,
        y: clearNewsBuildingLayout.outerRect.minY + 2.4
    )
    static let clearNewsElevatorLayout: ShellBuildingLayout = {
        let interiorRect = clearNewsBuildingLayout.interiorRect
        let outerRect = CGRect(
            x: interiorRect.maxX - 4.4,
            y: interiorRect.maxY - 3.8,
            width: 4.4,
            height: 3.8
        )
        return ShellBuildingLayout(
            outerRect: outerRect,
            wallThickness: 0.24,
            frontDoorWidth: 2.5
        )
    }()
    static let clearNewsCounterRect: CGRect = {
        let interiorRect = clearNewsBuildingLayout.interiorRect
        let leftGap: CGFloat = 1.35
        let backWalkwayDepth: CGFloat = 1.7
        let counterDepth: CGFloat = 1.15
        let originX = interiorRect.minX + leftGap
        let originY = interiorRect.maxY - backWalkwayDepth - counterDepth
        return CGRect(
            x: originX,
            y: originY,
            width: clearNewsElevatorLayout.outerRect.minX - originX,
            height: counterDepth
        )
    }()
    static let clearNewsClerkRadius: CGFloat = playerRadius * 0.9
    static let clearNewsClerkPoint = CGPoint(
        x: clearNewsCounterRect.midX,
        y: clearNewsCounterRect.maxY + clearNewsClerkRadius + 0.18
    )
    static let clearNewsThirdFloorOfficeDoorWidth: CGFloat = 2.3
    static let clearNewsOfficeLayout = ShellBuildingLayout(
        outerRect: CGRect(
            x: -5.4,
            y: -2.4,
            width: 10.8,
            height: 8.8
        ),
        wallThickness: 0.42,
        frontDoorWidth: clearNewsThirdFloorOfficeDoorWidth
    )
    static let clearNewsThirdFloorOfficeDoorPoint: CGPoint = {
        return CGPoint(
            x: clearNewsThirdFloorLayout.interiorRect.minX + (clearNewsThirdFloorOfficeDoorWidth / 2) + 0.9,
            y: clearNewsThirdFloorLayout.outerRect.maxY - (clearNewsThirdFloorLayout.wallThickness / 2)
        )
    }()
    static let clearNewsThirdFloorOfficeDoorRect: CGRect = {
        return CGRect(
            x: clearNewsThirdFloorOfficeDoorPoint.x - (clearNewsThirdFloorOfficeDoorWidth / 2),
            y: clearNewsThirdFloorOfficeDoorPoint.y - (clearNewsThirdFloorLayout.wallThickness / 2),
            width: clearNewsThirdFloorOfficeDoorWidth,
            height: clearNewsThirdFloorLayout.wallThickness
        )
    }()
    static let clearNewsOfficeSpawnPoint = CGPoint(
        x: clearNewsOfficeLayout.center.x,
        y: clearNewsOfficeLayout.interiorRect.minY + 1.28
    )
    static let clearNewsThirdFloorOfficeExitPoint = CGPoint(
        x: clearNewsThirdFloorOfficeDoorRect.midX,
        y: clearNewsThirdFloorLayout.interiorRect.maxY - 1.15
    )
    static let clearNewsThirdFloorPrinterPoint: CGPoint = {
        let interiorRect = clearNewsThirdFloorLayout.interiorRect
        return CGPoint(
            x: interiorRect.minX + 1.55,
            y: interiorRect.minY + 1.3
        )
    }()
    static let clearNewsThirdFloorPrinterRect = CGRect(
        x: clearNewsThirdFloorPrinterPoint.x - 0.56,
        y: clearNewsThirdFloorPrinterPoint.y - 0.42,
        width: 1.12,
        height: 0.84
    )
    static let clearNewsOfficeDeskRect = CGRect(
        x: clearNewsOfficeLayout.center.x - 1.7,
        y: clearNewsOfficeLayout.interiorRect.maxY - 1.85,
        width: 3.4,
        height: 1.18
    )
    static let clearNewsOfficeChairPoint = CGPoint(
        x: clearNewsOfficeDeskRect.midX,
        y: clearNewsOfficeDeskRect.minY - 0.86
    )
    static let clearNewsOfficeBookshelfRect = CGRect(
        x: clearNewsOfficeLayout.interiorRect.minX + 0.72,
        y: clearNewsOfficeLayout.interiorRect.maxY - 2.5,
        width: 0.72,
        height: 2.0
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
    static let cameraFieldOfView: CGFloat = 48
    static let cameraHeight: CGFloat = 10.4
    static let cameraDistance: CGFloat = 6.8
    static let cameraTilt: CGFloat = -0.66
    static let conversationCameraFieldOfView: CGFloat = 34
    static let conversationCameraHeight: CGFloat = 8.4
    static let conversationCameraDistance: CGFloat = 5.1
    static let joystickSize = CGSize(width: 144, height: 144)
    static let joystickMargin: CGFloat = 24
    static let actionButtonSize = CGSize(width: 58, height: 58)
    static let actionButtonOffset = CGPoint(x: 68, y: 88)
    static let clearNewsElevatorInteractionReach: CGFloat = 1.25
    static let interactionPromptCornerRadius: CGFloat = 18
    static let interactionPromptBottomInset: CGFloat = 28
    static let interactionPromptHorizontalInset: CGFloat = 20
    static let interactionPromptMinHeight: CGFloat = 78
    static let interactionPromptButtonSize: CGFloat = 42
    static let daylightCycleDuration: TimeInterval = 15 * 60
    static let sleepFadeDuration: TimeInterval = 0.55
    static let sleepBlackoutDuration: TimeInterval = 2.0
    static let areaTransitionFadeDuration: TimeInterval = 0.42
    static let clearNewsElevatorFadeDuration: TimeInterval = 0.42
    static let trafficCarBaseSpeed: CGFloat = 8.2
    static let trafficCarMaxWidth: CGFloat = 1.76
    static let trafficPedestrianYieldGap: CGFloat = 0.78
    static let trafficCarFollowingGap: CGFloat = 0.92
    static let parkedCarLength: CGFloat = 3.35
    static let parkedCarWidth: CGFloat = 1.72
    static let parkedCarInteractionReach: CGFloat = 1.35
    static let parkedCarDriveSpeed: CGFloat = 12.4
    static let parkedCarMovementRadius: CGFloat = 0.96
    static func parkedCarPoint(for layout: CrossroadsLayout) -> CGPoint {
        CGPoint(
            x: layout.verticalRoadRect.maxX + (parkedCarWidth / 2) + 0.65,
            y: layout.spawnPoint.y + 0.7
        )
    }
}
