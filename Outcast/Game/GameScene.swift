import CoreGraphics
import SceneKit
import UIKit

final class GameScene: NSObject, SCNSceneRendererDelegate {
    private struct BedSequenceState {
        let startPoint: CGPoint
        let approachPoint: CGPoint
        let sleepPoint: CGPoint
        var startTime: TimeInterval?
    }

    var movementInputProvider: () -> CGVector = { .zero }
    var onBedSequenceFinished: (() -> Void)?
    let scene = SCNScene()
    var isPlayerNearBedForInteraction: Bool {
        GameConstants.spawnHouseLayout.canInteractWithBed(
            at: worldFocusPoint,
            reach: GameConstants.bedInteractionReach
        )
    }
    var isBedSequenceActive: Bool {
        bedSequence != nil
    }
    var daylightCycleProgress: CGFloat {
        CGFloat(daylightElapsed / GameConstants.daylightCycleDuration)
    }

    private let playerNode = PlayerNode(radius: GameConstants.playerRadius)
    private let worldNode = SCNNode()
    private let movementSystem = MovementSystem()
    private let cameraNode = SCNNode()
    private let focusTargetNode = SCNNode()
    private let ambientLightNode = SCNNode()
    private let directionalLightNode = SCNNode()
    private let fillLightNode = SCNNode()
    private let worldLayout = GameConstants.worldLayout

    private var spawnHouseNode: HouseNode?
    private var isFrontDoorOpen = false
    private var worldFocusPoint = CGPoint.zero
    private var roomBounds = RoomBounds(rect: .zero)
    private var lastUpdateTime: TimeInterval?
    private var daylightElapsed: TimeInterval = 0
    private var sleepReturnPoint: CGPoint?
    private var lastFacingVector = CGVector(dx: 0, dy: -1)
    private var viewportSize: CGSize
    private var bedSequence: BedSequenceState?

    init(size: CGSize) {
        self.viewportSize = size
        super.init()
        configureScene()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateViewportSize(_ size: CGSize) {
        viewportSize = size
    }

    @discardableResult
    func beginBedSequence() -> Bool {
        guard !isBedSequenceActive, isPlayerNearBedForInteraction else {
            return false
        }

        bedSequence = BedSequenceState(
            startPoint: worldFocusPoint,
            approachPoint: GameConstants.spawnHouseLayout.bedApproachPoint(playerRadius: GameConstants.playerRadius),
            sleepPoint: GameConstants.spawnHouseLayout.bedSleepPoint,
            startTime: nil
        )
        sleepReturnPoint = worldFocusPoint
        playerNode.setMovementState(.idle)
        return true
    }

    func wakeFromBed() {
        guard let sleepReturnPoint else {
            return
        }

        bedSequence = nil
        worldFocusPoint = roomBounds.clamped(sleepReturnPoint, radius: GameConstants.playerRadius)
        self.sleepReturnPoint = nil
        isFrontDoorOpen = false
        spawnHouseNode?.setFrontDoorOpen(false, swingDirection: .outward)
        spawnHouseNode?.setBedBlanketState(coverage: 1, occupant: 0)
        playerNode.setMovementState(.idle)
        playerNode.setSleepPose(lieProgress: 0, coverProgress: 0)
        playerNode.setFacing(vector: lastFacingVector, animated: false)
        resetDaylightCycle()
        refreshRoomBounds()
        updatePlayerGrounding()
        updateWorldOffset()
        updateHousePresentation()
    }

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }

        if updateBedSequence(at: currentTime) {
            return
        }

        guard let lastUpdateTime else {
            return
        }

        let deltaTime = min(max(currentTime - lastUpdateTime, 0), 1.0 / 30.0)
        let movementVector = movementInputProvider().clampedToUnit
        advanceDaylight(by: deltaTime)
        let intensity = movementVector.magnitude
        let animationState: PlayerNode.MovementState

        if intensity == 0 {
            animationState = .idle
        } else if intensity < GameConstants.walkInputThreshold {
            animationState = .walking
        } else {
            animationState = .running
        }

        let travelSpeed = GameConstants.walkSpeed + ((GameConstants.runSpeed - GameConstants.walkSpeed) * intensity)
        let proposedPoint = CGPoint(
            x: worldFocusPoint.x + (movementVector.dx * travelSpeed * deltaTime),
            y: worldFocusPoint.y + (movementVector.dy * travelSpeed * deltaTime)
        )
        updateDoorStates(current: worldFocusPoint, proposed: proposedPoint)
        refreshRoomBounds()

        worldFocusPoint = movementSystem.move(
            from: worldFocusPoint,
            inputVector: movementVector,
            deltaTime: deltaTime,
            speed: travelSpeed,
            radius: GameConstants.playerRadius,
            within: roomBounds
        )

        if movementVector != .zero {
            lastFacingVector = movementVector.normalized
        }
        playerNode.setMovementState(animationState)
        playerNode.setFacing(vector: movementVector)
        updatePlayerGrounding()
        updateWorldOffset()
        updateHousePresentation()
    }

    private func configureScene() {
        scene.background.contents = UIColor.black
        scene.rootNode.addChildNode(worldNode)
        scene.rootNode.addChildNode(playerNode)
        scene.rootNode.addChildNode(focusTargetNode)
        playerNode.position = SCNVector3Zero

        configureCamera()
        configureLights()
        configureWorld()
    }

    private func configureCamera() {
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 48
        cameraNode.camera?.wantsHDR = true
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 220
        cameraNode.position = SCNVector3(
            0,
            Float(GameConstants.cameraHeight),
            Float(GameConstants.cameraDistance)
        )
        cameraNode.eulerAngles.x = Float(GameConstants.cameraTilt)
        scene.rootNode.addChildNode(cameraNode)

        let lookAt = SCNLookAtConstraint(target: focusTargetNode)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]
    }

    private func configureLights() {
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        scene.rootNode.addChildNode(ambientLightNode)

        directionalLightNode.light = SCNLight()
        directionalLightNode.light?.type = .directional
        directionalLightNode.light?.castsShadow = true
        directionalLightNode.light?.shadowRadius = 6
        directionalLightNode.light?.shadowSampleCount = 24
        directionalLightNode.light?.shadowMode = .deferred
        directionalLightNode.eulerAngles = SCNVector3(-0.9, 0.75, 0)
        scene.rootNode.addChildNode(directionalLightNode)

        fillLightNode.light = SCNLight()
        fillLightNode.light?.type = .omni
        fillLightNode.position = SCNVector3(0, 7, 5)
        scene.rootNode.addChildNode(fillLightNode)

        resetDaylightCycle()
    }

    private func configureWorld() {
        isFrontDoorOpen = false
        roomBounds = RoomBounds(rect: worldLayout.movementRect, blockedRects: currentBlockedRects())
        worldNode.childNodes.forEach { $0.removeFromParentNode() }
        spawnHouseNode = nil

        addGround(in: worldLayout.groundRect)
        addFloorDetails(in: worldLayout.mainPlayableRect)
        addRoad()
        addSpawnHouse()
        addTreeBands()

        if worldFocusPoint == .zero {
            worldFocusPoint = CGPoint(
                x: worldLayout.mainPlayableRect.midX,
                y: worldLayout.mainPlayableRect.midY
            )
        } else {
            worldFocusPoint = roomBounds.clamped(worldFocusPoint, radius: GameConstants.playerRadius)
        }

        updatePlayerGrounding()
        updateWorldOffset()
        updateHousePresentation()
        spawnHouseNode?.setBedBlanketState(coverage: 1, occupant: 0)
        playerNode.setSleepPose(lieProgress: 0, coverProgress: 0)
    }

    private func addGround(in worldRect: CGRect) {
        let ground = SCNNode(
            geometry: SCNBox(
                width: worldRect.width,
                height: GameConstants.groundThickness,
                length: worldRect.height,
                chamferRadius: GameConstants.roomCornerRadius
            )
        )
        ground.name = "worldGround"
        ground.geometry?.firstMaterial = material(
            diffuse: UIColor(red: 0.09, green: 0.12, blue: 0.14, alpha: 1.0),
            roughness: 0.96
        )
        ground.geometry?.firstMaterial?.normal.contents = UIColor(red: 0.12, green: 0.14, blue: 0.15, alpha: 1.0)
        ground.position = SCNVector3(
            Float(worldRect.midX),
            Float(-GameConstants.groundThickness / 2),
            Float(-worldRect.midY)
        )
        ground.castsShadow = false
        worldNode.addChildNode(ground)
    }

    private func addSpawnHouse() {
        let house = HouseNode(layout: GameConstants.spawnHouseLayout, wallHeight: GameConstants.houseWallHeight)
        house.position = position3D(for: GameConstants.spawnHouseLayout.center)
        worldNode.addChildNode(house)
        spawnHouseNode = house
    }

    private func addRoad() {
        let roadRect = worldLayout.roadSurfaceRect

        let road = SCNNode(
            geometry: SCNBox(
                width: roadRect.width,
                height: 0.04,
                length: roadRect.height,
                chamferRadius: 0.58
            )
        )
        road.name = "northRoad"
        road.geometry?.firstMaterial = material(
            diffuse: UIColor(red: 0.26, green: 0.22, blue: 0.18, alpha: 1.0),
            roughness: 0.96
        )
        road.position = position3D(
            for: CGPoint(x: roadRect.midX, y: roadRect.midY),
            elevation: 0.021
        )
        worldNode.addChildNode(road)

        for offset in [-0.78, 0.78] {
            let rut = SCNNode(
                geometry: SCNBox(
                    width: 0.56,
                    height: 0.01,
                    length: roadRect.height * 0.95,
                    chamferRadius: 0.18
                )
            )
            rut.geometry?.firstMaterial = material(
                diffuse: UIColor(red: 0.18, green: 0.15, blue: 0.12, alpha: 1.0),
                roughness: 0.98
            )
            rut.position = position3D(
                for: CGPoint(x: roadRect.midX + CGFloat(offset), y: roadRect.midY),
                elevation: 0.046
            )
            worldNode.addChildNode(rut)
        }
    }

    private func addTreeBands() {
        let worldRect = worldLayout.worldRect
        let mainPlayableRect = worldLayout.mainPlayableRect
        let corridorRect = worldLayout.roadCorridorRect
        let roadClearing = worldLayout.roadTreeClearanceRect

        addHorizontalTreeBand(
            startX: worldRect.minX + (GameConstants.treeSpacing / 2),
            endX: worldRect.maxX - (GameConstants.treeSpacing / 2),
            frontY: mainPlayableRect.maxY + (GameConstants.frontTreeSize * 0.3),
            depthDirection: 1,
            variationOffset: 0,
            clearings: [roadClearing]
        )
        addHorizontalTreeBand(
            startX: worldRect.minX + (GameConstants.treeSpacing / 2),
            endX: worldRect.maxX - (GameConstants.treeSpacing / 2),
            frontY: mainPlayableRect.minY - (GameConstants.frontTreeSize * 0.3),
            depthDirection: -1,
            variationOffset: 1_000
        )
        addVerticalTreeBand(
            startY: worldRect.minY + (GameConstants.treeSpacing / 2),
            endY: worldRect.maxY - (GameConstants.treeSpacing / 2),
            frontX: mainPlayableRect.minX - (GameConstants.frontTreeSize * 0.3),
            depthDirection: -1,
            variationOffset: 2_000
        )
        addVerticalTreeBand(
            startY: worldRect.minY + (GameConstants.treeSpacing / 2),
            endY: worldRect.maxY - (GameConstants.treeSpacing / 2),
            frontX: mainPlayableRect.maxX + (GameConstants.frontTreeSize * 0.3),
            depthDirection: 1,
            variationOffset: 3_000
        )
        addVerticalTreeBand(
            startY: corridorRect.minY + (GameConstants.treeSpacing / 2),
            endY: worldLayout.movementRect.maxY - (GameConstants.treeSpacing / 2),
            frontX: corridorRect.minX - (GameConstants.frontTreeSize * 0.65),
            depthDirection: -1,
            variationOffset: 4_000
        )
        addVerticalTreeBand(
            startY: corridorRect.minY + (GameConstants.treeSpacing / 2),
            endY: worldLayout.movementRect.maxY - (GameConstants.treeSpacing / 2),
            frontX: corridorRect.maxX + (GameConstants.frontTreeSize * 0.65),
            depthDirection: 1,
            variationOffset: 5_000
        )
        addHorizontalTreeBand(
            startX: worldRect.minX + (GameConstants.treeSpacing / 2),
            endX: worldRect.maxX - (GameConstants.treeSpacing / 2),
            frontY: worldLayout.movementRect.maxY - (GameConstants.treeRowOffset * 0.95),
            depthDirection: 1,
            variationOffset: 6_000,
            clearings: [roadClearing]
        )
    }

    private func addHorizontalTreeBand(
        startX: CGFloat,
        endX: CGFloat,
        frontY: CGFloat,
        depthDirection: CGFloat,
        variationOffset: Int,
        clearings: [CGRect] = []
    ) {
        let midRowY = frontY + (GameConstants.treeRowOffset * depthDirection)
        let backRowY = midRowY + ((GameConstants.treeRowOffset * 0.9) * depthDirection)
        let farRowY = backRowY + ((GameConstants.treeRowOffset * 0.85) * depthDirection)
        let deepestRowY = farRowY + ((GameConstants.treeRowOffset * 0.8) * depthDirection)

        var x = startX
        var treeIndex = 0
        while x <= endX {
            let index = treeIndex + variationOffset
            let frontPoint = CGPoint(x: x, y: frontY)
            if !clearings.contains(where: { $0.contains(frontPoint) }) {
                let frontTree = TreeNode(
                    size: GameConstants.frontTreeSize,
                    isBackgroundRow: false,
                    variation: variation(for: index, salt: 11)
                )
                frontTree.position = position3D(for: frontPoint)
                worldNode.addChildNode(frontTree)
            }

            let middlePoint = CGPoint(
                x: x + (GameConstants.treeSpacing * (0.36 + (variation(for: index, salt: 7) * 0.22))),
                y: midRowY
            )
            if !clearings.contains(where: { $0.contains(middlePoint) }) {
                let middleTree = TreeNode(
                    size: GameConstants.backTreeSize,
                    isBackgroundRow: true,
                    variation: variation(for: index, salt: 29)
                )
                middleTree.position = position3D(for: middlePoint)
                worldNode.addChildNode(middleTree)
            }

            let backPoint = CGPoint(
                x: x - (GameConstants.treeSpacing * (0.14 + (variation(for: index, salt: 17) * 0.24))),
                y: backRowY
            )
            if !clearings.contains(where: { $0.contains(backPoint) }) {
                let backTree = TreeNode(
                    size: GameConstants.backTreeSize * 0.96,
                    isBackgroundRow: true,
                    variation: variation(for: index, salt: 53)
                )
                backTree.position = position3D(for: backPoint)
                worldNode.addChildNode(backTree)
            }

            let farPoint = CGPoint(
                x: x + (GameConstants.treeSpacing * (0.18 + (variation(for: index, salt: 41) * 0.28))),
                y: farRowY
            )
            if !clearings.contains(where: { $0.contains(farPoint) }) {
                let farTree = TreeNode(
                    size: GameConstants.backTreeSize * 0.9,
                    isBackgroundRow: true,
                    variation: variation(for: index, salt: 71)
                )
                farTree.position = position3D(for: farPoint)
                worldNode.addChildNode(farTree)
            }

            let deepestPoint = CGPoint(
                x: x - (GameConstants.treeSpacing * (0.1 + (variation(for: index, salt: 61) * 0.3))),
                y: deepestRowY
            )
            if !clearings.contains(where: { $0.contains(deepestPoint) }) {
                let deepestTree = TreeNode(
                    size: GameConstants.backTreeSize * 0.84,
                    isBackgroundRow: true,
                    variation: variation(for: index, salt: 89)
                )
                deepestTree.position = position3D(for: deepestPoint)
                worldNode.addChildNode(deepestTree)
            }

            treeIndex += 1
            x += GameConstants.treeSpacing
        }
    }

    private func addVerticalTreeBand(
        startY: CGFloat,
        endY: CGFloat,
        frontX: CGFloat,
        depthDirection: CGFloat,
        variationOffset: Int,
        clearings: [CGRect] = []
    ) {
        let midRowX = frontX + (GameConstants.treeRowOffset * depthDirection)
        let backRowX = midRowX + ((GameConstants.treeRowOffset * 0.9) * depthDirection)
        let farRowX = backRowX + ((GameConstants.treeRowOffset * 0.85) * depthDirection)
        let deepestRowX = farRowX + ((GameConstants.treeRowOffset * 0.8) * depthDirection)

        var y = startY
        var treeIndex = 0
        while y <= endY {
            let index = treeIndex + variationOffset
            let frontPoint = CGPoint(x: frontX, y: y)
            if !clearings.contains(where: { $0.contains(frontPoint) }) {
                let frontTree = TreeNode(
                    size: GameConstants.frontTreeSize,
                    isBackgroundRow: false,
                    variation: variation(for: index, salt: 101)
                )
                frontTree.position = position3D(for: frontPoint)
                worldNode.addChildNode(frontTree)
            }

            let middlePoint = CGPoint(
                x: midRowX,
                y: y + (GameConstants.treeSpacing * (0.34 + (variation(for: index, salt: 107) * 0.22)))
            )
            if !clearings.contains(where: { $0.contains(middlePoint) }) {
                let middleTree = TreeNode(
                    size: GameConstants.backTreeSize,
                    isBackgroundRow: true,
                    variation: variation(for: index, salt: 131)
                )
                middleTree.position = position3D(for: middlePoint)
                worldNode.addChildNode(middleTree)
            }

            let backPoint = CGPoint(
                x: backRowX,
                y: y - (GameConstants.treeSpacing * (0.16 + (variation(for: index, salt: 117) * 0.24)))
            )
            if !clearings.contains(where: { $0.contains(backPoint) }) {
                let backTree = TreeNode(
                    size: GameConstants.backTreeSize * 0.96,
                    isBackgroundRow: true,
                    variation: variation(for: index, salt: 157)
                )
                backTree.position = position3D(for: backPoint)
                worldNode.addChildNode(backTree)
            }

            let farPoint = CGPoint(
                x: farRowX,
                y: y + (GameConstants.treeSpacing * (0.2 + (variation(for: index, salt: 141) * 0.26)))
            )
            if !clearings.contains(where: { $0.contains(farPoint) }) {
                let farTree = TreeNode(
                    size: GameConstants.backTreeSize * 0.9,
                    isBackgroundRow: true,
                    variation: variation(for: index, salt: 179)
                )
                farTree.position = position3D(for: farPoint)
                worldNode.addChildNode(farTree)
            }

            let deepestPoint = CGPoint(
                x: deepestRowX,
                y: y - (GameConstants.treeSpacing * (0.1 + (variation(for: index, salt: 161) * 0.28)))
            )
            if !clearings.contains(where: { $0.contains(deepestPoint) }) {
                let deepestTree = TreeNode(
                    size: GameConstants.backTreeSize * 0.84,
                    isBackgroundRow: true,
                    variation: variation(for: index, salt: 199)
                )
                deepestTree.position = position3D(for: deepestPoint)
                worldNode.addChildNode(deepestTree)
            }

            treeIndex += 1
            y += GameConstants.treeSpacing
        }
    }

    private func addFloorDetails(in playableRect: CGRect) {
        let roadClearanceRect = worldLayout.roadSurfaceRect.insetBy(dx: -0.35, dy: 0)

        for index in 0..<24 {
            let xRatio = 0.08 + (variation(for: index, salt: 3) * 0.84)
            let yRatio = 0.08 + (variation(for: index, salt: 5) * 0.84)
            let radius = 0.5 + (variation(for: index, salt: 13) * 1.4)
            let point = CGPoint(
                x: playableRect.minX + (playableRect.width * xRatio),
                y: playableRect.minY + (playableRect.height * yRatio)
            )

            guard !roadClearanceRect.contains(point) else {
                continue
            }

            let patch = SCNNode(geometry: SCNCylinder(radius: radius, height: 0.03))
            patch.geometry?.firstMaterial = material(
                diffuse: UIColor(
                    red: 0.1 + (variation(for: index, salt: 23) * 0.04),
                    green: 0.12 + (variation(for: index, salt: 31) * 0.05),
                    blue: 0.11 + (variation(for: index, salt: 47) * 0.03),
                    alpha: 1.0
                ),
                roughness: 0.98
            )
            patch.position = position3D(for: point, elevation: 0.02)
            worldNode.addChildNode(patch)
        }
    }

    private func updateWorldOffset() {
        worldNode.position = SCNVector3(Float(-worldFocusPoint.x), 0, Float(worldFocusPoint.y))
        focusTargetNode.position = SCNVector3(0, 2.15 + playerNode.position.y, 0)
    }

    private func advanceDaylight(by deltaTime: TimeInterval) {
        daylightElapsed += deltaTime
        if daylightElapsed >= GameConstants.daylightCycleDuration {
            daylightElapsed = daylightElapsed.truncatingRemainder(dividingBy: GameConstants.daylightCycleDuration)
        }
        applyDaylight()
    }

    private func resetDaylightCycle() {
        daylightElapsed = 0
        applyDaylight()
    }

    private func applyDaylight() {
        let progress = daylightCycleProgress
        let fadeProgress = progress * progress * (3 - (2 * progress))

        ambientLightNode.light?.color = blendedColor(
            from: UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1.0),
            to: UIColor.black,
            progress: fadeProgress
        )
        ambientLightNode.light?.intensity = 1_600 * (1 - fadeProgress)

        directionalLightNode.light?.color = blendedColor(
            from: UIColor(red: 1.0, green: 0.97, blue: 0.9, alpha: 1.0),
            to: UIColor.black,
            progress: fadeProgress
        )
        directionalLightNode.light?.intensity = 1_450 * (1 - fadeProgress)

        fillLightNode.light?.color = blendedColor(
            from: UIColor(red: 0.72, green: 0.84, blue: 1.0, alpha: 1.0),
            to: UIColor.black,
            progress: fadeProgress
        )
        fillLightNode.light?.intensity = 920 * (1 - fadeProgress)

        scene.background.contents = blendedColor(
            from: UIColor(red: 0.63, green: 0.84, blue: 1.0, alpha: 1.0),
            to: UIColor.black,
            progress: fadeProgress
        )
    }

    private func updateBedSequence(at currentTime: TimeInterval) -> Bool {
        guard var bedSequence else {
            return false
        }

        if bedSequence.startTime == nil {
            bedSequence.startTime = currentTime
        }

        let elapsed = currentTime - (bedSequence.startTime ?? currentTime)
        let approachProgress = smoothstep(elapsed, start: 0, end: 0.55)
        let climbProgress = smoothstep(elapsed, start: 0.78, end: 1.82)
        let blanketDownProgress = smoothstep(elapsed, start: 0.08, end: 0.8)
        let coverProgress = smoothstep(elapsed, start: 1.84, end: 2.68)
        let lieProgress = smoothstep(elapsed, start: 1.02, end: 2.06)

        let pathStart = interpolatedPoint(from: bedSequence.startPoint, to: bedSequence.approachPoint, progress: approachProgress)
        worldFocusPoint = interpolatedPoint(from: pathStart, to: bedSequence.sleepPoint, progress: climbProgress)

        if lieProgress < 0.75 {
            let facingTarget = climbProgress < 0.3 ? bedSequence.approachPoint : bedSequence.sleepPoint
            playerNode.setFacing(vector: vector(from: worldFocusPoint, to: facingTarget), animated: false)
        }

        let blanketCoverage: CGFloat = elapsed < 1.84
            ? (1 - blanketDownProgress)
            : coverProgress

        spawnHouseNode?.setBedBlanketState(coverage: blanketCoverage, occupant: lieProgress)
        playerNode.setMovementState(.idle)
        playerNode.setSleepPose(lieProgress: lieProgress, coverProgress: coverProgress)
        updatePlayerGrounding()
        updateWorldOffset()
        updateHousePresentation()

        if elapsed >= 3.02 {
            self.bedSequence = nil
            onBedSequenceFinished?()
        } else {
            self.bedSequence = bedSequence
        }

        return true
    }

    private func updateHousePresentation() {
        spawnHouseNode?.setRoofHidden(GameConstants.spawnHouseLayout.containsInterior(worldFocusPoint))
    }

    private func updatePlayerGrounding() {
        playerNode.setGroundElevation(currentGroundElevation())
    }

    private func currentGroundElevation() -> CGFloat {
        guard GameConstants.spawnHouseLayout.containsInterior(worldFocusPoint) else {
            return 0
        }

        let foundationHeight = GameConstants.houseWallHeight * 0.12
        let floorHeight = GameConstants.houseWallHeight * 0.06
        return foundationHeight + floorHeight
    }

    private func refreshRoomBounds() {
        roomBounds = RoomBounds(rect: worldLayout.movementRect, blockedRects: currentBlockedRects())
    }

    private func currentBlockedRects() -> [CGRect] {
        GameConstants.spawnHouseLayout.blockedRects(frontDoorOpen: isFrontDoorOpen) + worldLayout.blockedRects
    }

    private func updateDoorStates(current: CGPoint, proposed: CGPoint) {
        let frontDoorShouldOpen = shouldOpenDoor(
            openingRect: GameConstants.spawnHouseLayout.frontDoorOpeningRect,
            current: current,
            proposed: proposed
        )
        let frontDoorSwingDirection: HouseNode.DoorSwingDirection = {
            let currentInside = GameConstants.spawnHouseLayout.containsInterior(current)
            let proposedInside = GameConstants.spawnHouseLayout.containsInterior(proposed)

            if currentInside && !proposedInside {
                return .outward
            }
            if !currentInside && proposedInside {
                return .inward
            }
            return proposed.y >= current.y ? .inward : .outward
        }()

        isFrontDoorOpen = frontDoorShouldOpen
        spawnHouseNode?.setFrontDoorOpen(frontDoorShouldOpen, swingDirection: frontDoorSwingDirection)
    }

    private func shouldOpenDoor(openingRect: CGRect, current: CGPoint, proposed: CGPoint) -> Bool {
        let interactionRect = openingRect.insetBy(
            dx: -GameConstants.doorInteractionReach,
            dy: -GameConstants.doorInteractionReach
        )
        if interactionRect.contains(current) || interactionRect.contains(proposed) {
            return true
        }

        let travelRect = CGRect(
            x: min(current.x, proposed.x),
            y: min(current.y, proposed.y),
            width: max(abs(proposed.x - current.x), 0.001),
            height: max(abs(proposed.y - current.y), 0.001)
        )
        return interactionRect.intersects(travelRect)
    }

    private func position3D(for point: CGPoint, elevation: CGFloat = 0) -> SCNVector3 {
        SCNVector3(Float(point.x), Float(elevation), Float(-point.y))
    }

    private func variation(for index: Int, salt: Int) -> CGFloat {
        let value = sin(Double((index + 1) * 37 + (salt * 19))) * 43758.5453
        return CGFloat(value - floor(value))
    }

    private func smoothstep(_ value: TimeInterval, start: TimeInterval, end: TimeInterval) -> CGFloat {
        guard end > start else {
            return value >= end ? 1 : 0
        }

        let raw = max(0, min((value - start) / (end - start), 1))
        let clamped = CGFloat(raw)
        return clamped * clamped * (3 - (2 * clamped))
    }

    private func interpolatedPoint(from start: CGPoint, to end: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + ((end.x - start.x) * progress),
            y: start.y + ((end.y - start.y) * progress)
        )
    }

    private func vector(from start: CGPoint, to end: CGPoint) -> CGVector {
        CGVector(dx: end.x - start.x, dy: end.y - start.y).normalized
    }

    private func blendedColor(from start: UIColor, to end: UIColor, progress: CGFloat) -> UIColor {
        var startRed: CGFloat = 0
        var startGreen: CGFloat = 0
        var startBlue: CGFloat = 0
        var startAlpha: CGFloat = 0
        var endRed: CGFloat = 0
        var endGreen: CGFloat = 0
        var endBlue: CGFloat = 0
        var endAlpha: CGFloat = 0

        start.getRed(&startRed, green: &startGreen, blue: &startBlue, alpha: &startAlpha)
        end.getRed(&endRed, green: &endGreen, blue: &endBlue, alpha: &endAlpha)

        return UIColor(
            red: startRed + ((endRed - startRed) * progress),
            green: startGreen + ((endGreen - startGreen) * progress),
            blue: startBlue + ((endBlue - startBlue) * progress),
            alpha: startAlpha + ((endAlpha - startAlpha) * progress)
        )
    }

    private func material(diffuse: UIColor, roughness: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = diffuse
        material.metalness.contents = 0.0
        material.roughness.contents = roughness
        material.lightingModel = .physicallyBased
        return material
    }
}
