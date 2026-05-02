import CoreGraphics
import SceneKit
import UIKit

final class GameScene: NSObject, SCNSceneRendererDelegate {
    enum SpawnLocation {
        case home
        case clearNews
    }

    private enum Area {
        case homestead
        case traffic1
        case traffic2
        case traffic3
        case clearNewsThirdFloor
        case clearNewsOffice

        var isTrafficArea: Bool {
            switch self {
            case .homestead:
                return false
            case .traffic1, .traffic2, .traffic3:
                return true
            case .clearNewsThirdFloor, .clearNewsOffice:
                return false
            }
        }
    }

    private enum DoorWallOrientation {
        case north
        case south
    }

    private enum RoadOrientation {
        case horizontal
        case vertical
    }

    private enum CameraFocusMode: Equatable {
        case player
        case clearNewsClerk
    }

    private struct BedSequenceState {
        let startPoint: CGPoint
        let approachPoint: CGPoint
        let sleepPoint: CGPoint
        var startTime: TimeInterval?
    }

    private struct TrafficCarState {
        let node: SCNNode
        let laneY: CGFloat
        let direction: CGFloat
        let speed: CGFloat
        let halfLength: CGFloat
        let halfWidth: CGFloat
        var x: CGFloat
    }

    private struct ParkedCarState {
        let node: SCNNode
        let halfLength: CGFloat
        let halfWidth: CGFloat
        var area: Area
        var point: CGPoint
        var headingVector: CGVector
        var isOccupied: Bool
    }

    var movementInputProvider: () -> CGVector = { .zero }
    var onBedSequenceFinished: (() -> Void)?
    var onNorthRoadExitReached: (() -> Void)?
    var onSouthRoadExitReached: (() -> Void)?
    var onWestRoadExitReached: (() -> Void)?
    var onEastRoadExitReached: (() -> Void)?
    var onClearNewsElevatorSealed: (() -> Void)?
    var onClearNewsOfficeEntered: (() -> Void)?
    let scene = SCNScene()
    var isPlayerNearBedForInteraction: Bool {
        guard currentArea == .homestead else {
            return false
        }

        return GameConstants.spawnHouseLayout.canInteractWithBed(
            at: worldFocusPoint,
            reach: GameConstants.bedInteractionReach
        )
    }
    var isBedSequenceActive: Bool {
        bedSequence != nil
    }
    var isPlayerNearParkedCarForInteraction: Bool {
        guard
            let parkedCarState,
            parkedCarState.area == currentArea,
            !parkedCarState.isOccupied
        else {
            return false
        }

        return parkedCarInteractionRect(for: parkedCarState.point).contains(worldFocusPoint)
    }
    var isDrivingParkedCar: Bool {
        parkedCarState?.isOccupied == true
    }
    var isPlayerNearClearNewsReceptionForInteraction: Bool {
        guard
            currentArea == .traffic3,
            !isDrivingParkedCar,
            !hasMetClearNewsReceptionist
        else {
            return false
        }

        return clearNewsElevatorInteractionRect.contains(worldFocusPoint)
    }
    var isPlayerNearClearNewsElevatorForInteraction: Bool {
        guard
            !isDrivingParkedCar,
            currentArea == .traffic3 || currentArea == .clearNewsThirdFloor
        else {
            return false
        }

        return clearNewsElevatorInteractionRect.contains(worldFocusPoint)
    }
    var isClearNewsClerkCameraFocused: Bool {
        cameraFocusMode == .clearNewsClerk
    }
    var isClearNewsElevatorUnlocked: Bool {
        hasMetClearNewsReceptionist
    }
    var isClearNewsElevatorDoorOpen: Bool {
        isClearNewsElevatorDoorOpenState
    }
    var isPlayerInsideClearNewsElevator: Bool {
        (currentArea == .traffic3 || currentArea == .clearNewsThirdFloor)
            && GameConstants.clearNewsElevatorLayout.containsInterior(worldFocusPoint)
    }
    var currentPlayerName: String? {
        storedPlayerName
    }
    var currentPlayerPosition: CGPoint {
        worldFocusPoint
    }
    var currentClearNewsElevatorFloorNumber: Int? {
        switch currentArea {
        case .traffic3:
            return 1
        case .clearNewsThirdFloor:
            return 3
        case .homestead, .traffic1, .traffic2, .clearNewsOffice:
            return nil
        }
    }
    var currentCameraFieldOfView: CGFloat {
        cameraNode.camera?.fieldOfView ?? GameConstants.cameraFieldOfView
    }
    var daylightCycleProgress: CGFloat {
        CGFloat(daylightElapsed / GameConstants.daylightCycleDuration)
    }
    var currentAreaIdentifier: String {
        switch currentArea {
        case .homestead:
            return "home"
        case .traffic1:
            return "traffic1"
        case .traffic2:
            return "traffic2"
        case .traffic3:
            return "traffic3"
        case .clearNewsThirdFloor:
            return "clearNewsThirdFloor"
        case .clearNewsOffice:
            return "clearNewsOffice"
        }
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
    private var clearNewsRoofNode: SCNNode?
    private var clearNewsDoorPivot: SCNNode?
    private var clearNewsOfficeDoorPivot: SCNNode?
    private var clearNewsElevatorRoofNode: SCNNode?
    private var clearNewsClerkNode: SCNNode?
    private var clearNewsOfficeLampLightNode: SCNNode?
    private var clearNewsElevatorLeftDoorNode: SCNNode?
    private var clearNewsElevatorRightDoorNode: SCNNode?
    private var hasExitedClearNewsLobbyElevator = true
    private var hasExitedClearNewsThirdFloorElevator = false
    private var isFrontDoorOpen = false
    private var clearNewsDoorSwingDirection: HouseNode.DoorSwingDirection = .outward
    private var isClearNewsDoorOpen = false
    private var isClearNewsOfficeDoorOpen = false
    private var clearNewsOfficeDoorOpenElapsed: TimeInterval = 0
    private var clearNewsOfficeDoorSwingDirection: HouseNode.DoorSwingDirection = .outward
    private var clearNewsOfficeDoorWallOrientation: DoorWallOrientation = .north
    private var isClearNewsElevatorDoorOpenState = false
    private var hasMetClearNewsReceptionist = false
    private var storedPlayerName: String?
    private var currentArea: Area = .homestead
    private var areaTransitionPending = false
    private var cameraFocusMode: CameraFocusMode = .player
    private var worldFocusPoint = CGPoint.zero
    private var roomBounds = RoomBounds(rect: .zero)
    private var lastUpdateTime: TimeInterval?
    private var daylightElapsed: TimeInterval = 0
    private var sleepReturnPoint: CGPoint?
    private var lastFacingVector = CGVector(dx: 0, dy: -1)
    private var viewportSize: CGSize
    private var bedSequence: BedSequenceState?
    private var trafficCars: [TrafficCarState] = []
    private var parkedCarState: ParkedCarState?

    private var activeMovementRect: CGRect {
        switch currentArea {
        case .homestead:
            return worldLayout.movementRect
        case .traffic1, .traffic2, .traffic3:
            return activeTrafficLayout.movementRect
        case .clearNewsThirdFloor:
            return GameConstants.clearNewsThirdFloorLayout.interiorRect
        case .clearNewsOffice:
            return GameConstants.clearNewsOfficeLayout.interiorRect
        }
    }

    private var activeTrafficLayout: CrossroadsLayout {
        switch currentArea {
        case .homestead, .traffic1, .traffic2, .clearNewsThirdFloor, .clearNewsOffice:
            return GameConstants.crossroadsLayout
        case .traffic3:
            return GameConstants.traffic3Layout
        }
    }

    private var defaultSpawnPoint: CGPoint {
        switch currentArea {
        case .homestead:
            return .zero
        case .traffic1:
            return GameConstants.crossroadsLayout.spawnPoint
        case .traffic2:
            return GameConstants.crossroadsLayout.eastTransitionPoint
        case .traffic3:
            return GameConstants.traffic3Layout.eastTransitionPoint
        case .clearNewsThirdFloor:
            return GameConstants.clearNewsElevatorLayout.center
        case .clearNewsOffice:
            return GameConstants.clearNewsOfficeSpawnPoint
        }
    }

    private var activeClearNewsBuildingLayout: ShellBuildingLayout {
        switch currentArea {
        case .clearNewsThirdFloor:
            return GameConstants.clearNewsThirdFloorLayout
        case .clearNewsOffice:
            return GameConstants.clearNewsOfficeLayout
        case .homestead, .traffic1, .traffic2, .traffic3:
            return GameConstants.clearNewsBuildingLayout
        }
    }

    private var clearNewsThirdFloorWallRects: [CGRect] {
        let layout = GameConstants.clearNewsThirdFloorLayout
        let officeDoorRect = GameConstants.clearNewsThirdFloorOfficeDoorRect
        let southWallRects = layout.southWallSegments
        let northWallRect = CGRect(
            x: layout.outerRect.minX,
            y: layout.outerRect.maxY - (layout.wallThickness / 2),
            width: layout.outerRect.width,
            height: layout.wallThickness
        )
        let northWallSegments = [
            CGRect(
                x: northWallRect.minX,
                y: northWallRect.minY,
                width: officeDoorRect.minX - northWallRect.minX,
                height: northWallRect.height
            ),
            CGRect(
                x: officeDoorRect.maxX,
                y: northWallRect.minY,
                width: northWallRect.maxX - officeDoorRect.maxX,
                height: northWallRect.height
            )
        ].filter { $0.width > 0 && $0.height > 0 }

        return layout.wallRects.filter { wallRect in
            wallRect != northWallRect && !southWallRects.contains(wallRect)
        } + northWallSegments
    }

    private var clearNewsThirdFloorBlockedRects: [CGRect] {
        clearNewsThirdFloorWallRects
            + (isClearNewsOfficeDoorOpen ? [] : [GameConstants.clearNewsThirdFloorOfficeDoorRect])
            + [GameConstants.clearNewsThirdFloorPrinterRect]
    }

    private var clearNewsThirdFloorOfficeTransitionRect: CGRect {
        let layout = GameConstants.clearNewsThirdFloorLayout
        let doorRect = GameConstants.clearNewsThirdFloorOfficeDoorRect.insetBy(
            dx: GameConstants.playerRadius * 0.55,
            dy: 0
        )
        return CGRect(
            x: doorRect.minX,
            y: layout.interiorRect.maxY - (GameConstants.playerRadius + 0.2),
            width: doorRect.width,
            height: GameConstants.playerRadius + 0.2
        )
    }

    private var clearNewsOfficeExitTransitionRect: CGRect {
        let layout = GameConstants.clearNewsOfficeLayout
        let doorRect = layout.frontDoorRect.insetBy(
            dx: GameConstants.playerRadius * 0.55,
            dy: 0
        )
        return CGRect(
            x: doorRect.minX,
            y: layout.interiorRect.minY,
            width: doorRect.width,
            height: GameConstants.playerRadius + 0.2
        )
    }

    private var clearNewsElevatorExitClearanceRect: CGRect {
        let movementRadius = isDrivingParkedCar ? GameConstants.parkedCarMovementRadius : GameConstants.playerRadius
        return GameConstants.clearNewsElevatorLayout.interiorRect.union(
            GameConstants.clearNewsElevatorLayout.frontDoorRect.insetBy(
                dx: -movementRadius,
                dy: -movementRadius
            )
        )
    }

    private var clearNewsElevatorInteractionRect: CGRect {
        GameConstants.clearNewsElevatorLayout.frontDoorRect.insetBy(
            dx: -GameConstants.clearNewsElevatorInteractionReach,
            dy: -GameConstants.clearNewsElevatorInteractionReach
        )
    }

    private var clearNewsElevatorFullyEnteredRect: CGRect {
        let movementRadius = isDrivingParkedCar ? GameConstants.parkedCarMovementRadius : GameConstants.playerRadius
        let insetRect = GameConstants.clearNewsElevatorLayout.interiorRect.insetBy(
            dx: movementRadius,
            dy: movementRadius
        )
        guard insetRect.width > 0, insetRect.height > 0 else {
            return GameConstants.clearNewsElevatorLayout.interiorRect
        }
        return insetRect
    }

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

    func spawn(at location: SpawnLocation) {
        switch location {
        case .home:
            completeTransition(
                to: .homestead,
                destinationPoint: .zero,
                heading: CGVector(dx: 0, dy: -1)
            )
        case .clearNews:
            hasExitedClearNewsLobbyElevator = true
            completeTransition(
                to: .traffic3,
                destinationPoint: GameConstants.clearNewsSpawnPoint,
                heading: CGVector(dx: 0, dy: 1)
            )
        }
    }

    func setPlayerPosition(_ point: CGPoint, heading: CGVector? = nil) {
        let movementRadius = isDrivingParkedCar ? GameConstants.parkedCarMovementRadius : GameConstants.playerRadius
        worldFocusPoint = roomBounds.clamped(point, radius: movementRadius)

        if let heading {
            lastFacingVector = heading
            playerNode.setFacing(vector: heading, animated: false)
        }

        updatePlayerGrounding()
        updateWorldOffset()
        updateHousePresentation()
    }

    func completeNorthRoadTransition() {
        guard currentArea == .homestead else {
            return
        }

        completeTransition(
            to: .traffic1,
            destinationPoint: GameConstants.crossroadsLayout.spawnPoint,
            heading: CGVector(dx: 0, dy: 1)
        )
    }

    func completeSouthRoadTransition() {
        guard currentArea == .traffic1 else {
            return
        }

        completeTransition(
            to: .homestead,
            destinationPoint: worldLayout.northRoadReturnPoint,
            heading: CGVector(dx: 0, dy: -1)
        )
    }

    func completeWestRoadTransition() {
        let destinationArea: Area
        switch currentArea {
        case .traffic1:
            destinationArea = .traffic2
        case .traffic2:
            destinationArea = .traffic3
        case .homestead, .traffic3, .clearNewsThirdFloor, .clearNewsOffice:
            return
        }

        if destinationArea == .traffic3 {
            hasExitedClearNewsLobbyElevator = true
        }

        completeTransition(
            to: destinationArea,
            destinationPoint: destinationArea == .traffic3
                ? GameConstants.traffic3Layout.eastTransitionPoint
                : GameConstants.crossroadsLayout.eastTransitionPoint,
            heading: CGVector(dx: -1, dy: 0)
        )
    }

    func completeEastRoadTransition() {
        let destinationArea: Area
        switch currentArea {
        case .traffic2:
            destinationArea = .traffic1
        case .traffic3:
            destinationArea = .traffic2
        case .homestead, .traffic1, .clearNewsThirdFloor, .clearNewsOffice:
            return
        }

        completeTransition(
            to: destinationArea,
            destinationPoint: GameConstants.crossroadsLayout.westTransitionPoint,
            heading: CGVector(dx: 1, dy: 0)
        )
    }

    @discardableResult
    func beginBedSequence() -> Bool {
        guard currentArea == .homestead, !isBedSequenceActive, isPlayerNearBedForInteraction else {
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

    @discardableResult
    func beginDrivingParkedCar() -> Bool {
        guard
            var parkedCarState,
            parkedCarState.area == currentArea,
            !parkedCarState.isOccupied,
            isPlayerNearParkedCarForInteraction
        else {
            return false
        }

        parkedCarState.isOccupied = true
        self.parkedCarState = parkedCarState
        refreshRoomBounds()
        worldFocusPoint = roomBounds.clamped(
            parkedCarState.point,
            radius: GameConstants.parkedCarMovementRadius
        )
        playerNode.isHidden = true
        playerNode.setMovementState(.idle)
        updateParkedCarNode()
        updateWorldOffset()
        return true
    }

    @discardableResult
    func endDrivingParkedCar() -> Bool {
        guard
            var parkedCarState,
            parkedCarState.area == currentArea,
            parkedCarState.isOccupied
        else {
            return false
        }

        let exitPoint = parkedCarExitPoint(
            from: parkedCarState.point,
            heading: parkedCarState.headingVector
        )
        parkedCarState.isOccupied = false
        self.parkedCarState = parkedCarState
        refreshRoomBounds()
        worldFocusPoint = exitPoint
        playerNode.isHidden = false
        playerNode.setMovementState(.idle)
        playerNode.setFacing(vector: parkedCarState.headingVector, animated: false)
        updateParkedCarNode()
        updatePlayerGrounding()
        updateWorldOffset()
        return true
    }

    @discardableResult
    func beginClearNewsReceptionConversation() -> Bool {
        guard isPlayerNearClearNewsReceptionForInteraction else {
            return false
        }

        playerNode.setMovementState(.idle)
        setCameraFocusMode(.clearNewsClerk)
        updateWorldOffset()
        return true
    }

    @discardableResult
    func beginClearNewsElevatorInteraction() -> Bool {
        guard isPlayerNearClearNewsElevatorForInteraction else {
            return false
        }
        guard currentArea != .traffic3 || hasMetClearNewsReceptionist else {
            return false
        }

        playerNode.setMovementState(.idle)
        setClearNewsElevatorDoorOpen(true)
        refreshRoomBounds()
        updateWorldOffset()
        return true
    }

    func completeClearNewsReceptionConversation(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        storedPlayerName = trimmedName
        hasMetClearNewsReceptionist = true
        setCameraFocusMode(.player)
        setClearNewsElevatorDoorOpen(true)
        refreshRoomBounds()
        updateWorldOffset()
    }

    func completeClearNewsElevatorLobbyTransition() {
        hasExitedClearNewsLobbyElevator = false
        completeTransition(
            to: .traffic3,
            destinationPoint: GameConstants.clearNewsElevatorLayout.center,
            heading: CGVector(dx: 0, dy: -1)
        )
    }

    func completeClearNewsElevatorThirdFloorTransition() {
        hasExitedClearNewsThirdFloorElevator = false
        completeTransition(
            to: .clearNewsThirdFloor,
            destinationPoint: GameConstants.clearNewsElevatorLayout.center,
            heading: CGVector(dx: 0, dy: -1)
        )
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
        playerNode.isHidden = false
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

        if areaTransitionPending {
            playerNode.setMovementState(.idle)
            updatePlayerGrounding()
            updateWorldOffset()
            updateHousePresentation()
            return
        }

        let movementVector = movementInputProvider().clampedToUnit
        advanceDaylight(by: deltaTime)
        let intensity = movementVector.magnitude
        let animationState: PlayerNode.MovementState

        if isDrivingParkedCar || intensity == 0 {
            animationState = .idle
        } else if intensity < GameConstants.walkInputThreshold {
            animationState = .walking
        } else {
            animationState = .running
        }

        let travelSpeed: CGFloat
        let movementRadius: CGFloat
        if isDrivingParkedCar {
            travelSpeed = GameConstants.parkedCarDriveSpeed * intensity
            movementRadius = GameConstants.parkedCarMovementRadius
        } else {
            travelSpeed = GameConstants.walkSpeed + ((GameConstants.runSpeed - GameConstants.walkSpeed) * intensity)
            movementRadius = GameConstants.playerRadius
        }
        let proposedPoint = CGPoint(
            x: worldFocusPoint.x + (movementVector.dx * travelSpeed * deltaTime),
            y: worldFocusPoint.y + (movementVector.dy * travelSpeed * deltaTime)
        )
        updateDoorStates(current: worldFocusPoint, proposed: proposedPoint)
        if isClearNewsOfficeDoorOpen {
            clearNewsOfficeDoorOpenElapsed += deltaTime
        } else {
            clearNewsOfficeDoorOpenElapsed = 0
        }
        refreshRoomBounds()

        let previousFocusPoint = worldFocusPoint
        worldFocusPoint = movementSystem.move(
            from: worldFocusPoint,
            inputVector: movementVector,
            deltaTime: deltaTime,
            speed: travelSpeed,
            radius: movementRadius,
            within: roomBounds
        )

        let actualMovementVector = vector(from: previousFocusPoint, to: worldFocusPoint)
        if actualMovementVector != .zero {
            lastFacingVector = actualMovementVector
        }
        if isDrivingParkedCar {
            playerNode.setMovementState(.idle)
        } else {
            playerNode.setMovementState(areaTransitionPending ? .idle : animationState)
            playerNode.setFacing(vector: movementVector)
        }
        updateParkedCarStateIfNeeded()
        updateClearNewsElevatorStateIfNeeded()
        updateAreaTransitionIfNeeded()
        updateTraffic(by: deltaTime)
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
        cameraNode.camera?.fieldOfView = GameConstants.cameraFieldOfView
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

    private func completeTransition(to area: Area, destinationPoint: CGPoint, heading: CGVector) {
        currentArea = area
        areaTransitionPending = false
        isFrontDoorOpen = false
        isClearNewsDoorOpen = false
        isClearNewsOfficeDoorOpen = false
        clearNewsOfficeDoorOpenElapsed = 0
        clearNewsDoorSwingDirection = .outward
        clearNewsOfficeDoorSwingDirection = .outward
        clearNewsOfficeDoorWallOrientation = .north
        setCameraFocusMode(.player, animated: false)
        sleepReturnPoint = nil
        bedSequence = nil
        lastFacingVector = heading
        lastUpdateTime = nil

        if var parkedCarState, parkedCarState.isOccupied {
            parkedCarState.area = area
            parkedCarState.point = destinationPoint
            parkedCarState.headingVector = heading
            self.parkedCarState = parkedCarState
            worldFocusPoint = destinationPoint
        } else {
            worldFocusPoint = destinationPoint
        }

        playerNode.setMovementState(.idle)
        playerNode.setSleepPose(lieProgress: 0, coverProgress: 0)
        playerNode.setFacing(vector: lastFacingVector, animated: false)
        playerNode.isHidden = parkedCarState?.isOccupied == true

        configureWorld()

        if area == .clearNewsOffice {
            onClearNewsOfficeEntered?()
        }
    }

    private func configureWorld() {
        isFrontDoorOpen = false
        isClearNewsDoorOpen = false
        isClearNewsOfficeDoorOpen = false
        clearNewsOfficeDoorOpenElapsed = 0
        roomBounds = RoomBounds(rect: activeMovementRect, blockedRects: currentBlockedRects())
        worldNode.childNodes.forEach { $0.removeFromParentNode() }
        spawnHouseNode = nil
        clearNewsRoofNode = nil
        clearNewsDoorPivot = nil
        clearNewsOfficeDoorPivot = nil
        clearNewsElevatorRoofNode = nil
        clearNewsClerkNode = nil
        clearNewsOfficeLampLightNode = nil
        clearNewsElevatorLeftDoorNode = nil
        clearNewsElevatorRightDoorNode = nil
        trafficCars.removeAll()
        isClearNewsElevatorDoorOpenState = switch currentArea {
        case .traffic3:
            !hasExitedClearNewsLobbyElevator
        case .clearNewsThirdFloor:
            !hasExitedClearNewsThirdFloorElevator
        case .homestead, .traffic1, .traffic2, .clearNewsOffice:
            false
        }

        switch currentArea {
        case .homestead:
            addHomesteadWorld()
        case .traffic1:
            addTrafficWorld(includeHomeRoad: true)
        case .traffic2, .traffic3:
            addTrafficWorld(includeHomeRoad: false)
        case .clearNewsThirdFloor:
            addClearNewsThirdFloor()
        case .clearNewsOffice:
            addClearNewsOffice()
        }

        refreshRoomBounds()

        if worldFocusPoint == .zero {
            worldFocusPoint = defaultSpawnPoint
        } else {
            let movementRadius = isDrivingParkedCar ? GameConstants.parkedCarMovementRadius : GameConstants.playerRadius
            worldFocusPoint = roomBounds.clamped(worldFocusPoint, radius: movementRadius)
        }

        playerNode.isHidden = isDrivingParkedCar
        applyCameraFocusMode(animated: false)
        updatePlayerGrounding()
        updateParkedCarNode()
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
        ground.geometry?.firstMaterial = groundMaterial()
        ground.position = SCNVector3(
            Float(worldRect.midX),
            Float(-GameConstants.groundThickness / 2),
            Float(-worldRect.midY)
        )
        ground.castsShadow = false
        worldNode.addChildNode(ground)
    }

    private func addHomesteadWorld() {
        addGround(in: worldLayout.groundRect)
        addFloorDetails(in: worldLayout.mainPlayableRect, excludedRects: [worldLayout.roadSurfaceRect.insetBy(dx: -0.35, dy: 0)])
        addHomesteadRoad()
        addSpawnHouse()
        addHomesteadTreeBands()
        ensureParkedCarForCurrentArea(defaultPoint: worldLayout.northRoadReturnPoint)
    }

    private func addTrafficWorld(includeHomeRoad: Bool) {
        let layout = activeTrafficLayout
        addGround(in: layout.worldRect)
        var excludedRects = [layout.horizontalRoadRect.insetBy(dx: -0.75, dy: -0.45)]
        if includeHomeRoad {
            excludedRects.append(layout.verticalRoadRect.insetBy(dx: -0.55, dy: -0.25))
        }
        if currentArea == .traffic3 {
            excludedRects.append(GameConstants.clearNewsBuildingLayout.outerRect.insetBy(dx: -0.4, dy: -0.4))
        }
        addFloorDetails(in: layout.movementRect, excludedRects: excludedRects)
        addTrafficRoadNetwork(layout: layout, includeHomeRoad: includeHomeRoad)
        if currentArea == .traffic3 {
            addClearNewsBuilding()
        }
        addTrafficTreeBands(layout: layout, includeHomeRoad: includeHomeRoad)
        addTrafficCars()
        ensureParkedCarForCurrentArea(defaultPoint: GameConstants.parkedCarPoint(for: layout))
    }

    private func addClearNewsThirdFloor() {
        addClearNewsBuilding(isThirdFloor: true)
    }

    private func addClearNewsOffice() {
        let layout = GameConstants.clearNewsOfficeLayout
        let office = SCNNode()
        office.name = "clearNewsOffice"

        let floor = SCNNode(
            geometry: SCNBox(
                width: layout.interiorRect.width,
                height: 0.08,
                length: layout.interiorRect.height,
                chamferRadius: 0.14
            )
        )
        floor.name = "clearNewsFloor"
        floor.geometry?.firstMaterial = clearNewsFloorMaterial()
        floor.position = position3D(for: layout.center, elevation: GameConstants.clearNewsFloorHeight / 2)
        office.addChildNode(floor)

        for (index, wallRect) in layout.wallRects.enumerated() {
            let wall = SCNNode(
                geometry: SCNBox(
                    width: wallRect.width,
                    height: GameConstants.clearNewsWallHeight,
                    length: wallRect.height,
                    chamferRadius: 0.1
                )
            )
            wall.name = "clearNewsOfficeWall\(index)"
            wall.geometry?.firstMaterial = clearNewsWallMaterial()
            wall.position = position3D(
                for: CGPoint(x: wallRect.midX, y: wallRect.midY),
                elevation: GameConstants.clearNewsWallHeight / 2
            )
            office.addChildNode(wall)
        }

        addClearNewsOfficeDoor(
            to: office,
            layout: layout,
            doorRect: layout.frontDoorRect,
            wallOrientation: .south,
            showsPlaque: false
        )
        addClearNewsOfficeInterior(to: office)

        let roof = SCNNode(
            geometry: SCNBox(
                width: layout.outerRect.width + 0.8,
                height: 0.28,
                length: layout.outerRect.height + 0.8,
                chamferRadius: 0.2
            )
        )
        roof.name = "clearNewsRoof"
        roof.geometry?.firstMaterial = clearNewsRoofMaterial()
        roof.position = position3D(
            for: layout.center,
            elevation: GameConstants.clearNewsWallHeight + 0.14
        )
        office.addChildNode(roof)
        clearNewsRoofNode = roof

        worldNode.addChildNode(office)
    }

    private func addSpawnHouse() {
        let house = HouseNode(layout: GameConstants.spawnHouseLayout, wallHeight: GameConstants.houseWallHeight)
        house.position = position3D(for: GameConstants.spawnHouseLayout.center)
        worldNode.addChildNode(house)
        spawnHouseNode = house
    }

    private func addHomesteadRoad() {
        let roadRect = worldLayout.roadSurfaceRect
        addPavedRoad(
            named: "northRoad",
            rect: roadRect,
            thickness: 0.04,
            chamferRadius: 0.58,
            orientation: .vertical,
            elevation: 0.021
        )
    }

    private func addTrafficRoadNetwork(layout: CrossroadsLayout, includeHomeRoad: Bool) {
        if includeHomeRoad {
            addPavedRoad(
                named: "crossroadsApproachRoad",
                rect: layout.verticalRoadRect,
                thickness: 0.04,
                chamferRadius: 0.46,
                orientation: .vertical,
                elevation: 0.021
            )
        }
        addPavedRoad(
            named: "crossroadsMainRoad",
            rect: layout.horizontalRoadRect,
            thickness: 0.05,
            chamferRadius: 0.54,
            orientation: .horizontal,
            elevation: 0.022
        )
    }

    private func addClearNewsBuilding(isThirdFloor: Bool = false) {
        let layout = isThirdFloor
            ? GameConstants.clearNewsThirdFloorLayout
            : GameConstants.clearNewsBuildingLayout
        let building = SCNNode()
        building.name = "clearNewsBuilding"

        let floor = SCNNode(
            geometry: SCNBox(
                width: layout.interiorRect.width,
                height: 0.08,
                length: layout.interiorRect.height,
                chamferRadius: 0.14
            )
        )
        floor.name = "clearNewsFloor"
        floor.geometry?.firstMaterial = clearNewsFloorMaterial()
        floor.position = position3D(for: layout.center, elevation: GameConstants.clearNewsFloorHeight / 2)
        building.addChildNode(floor)

        let wallRects = isThirdFloor ? clearNewsThirdFloorWallRects : layout.wallRects
        for (index, wallRect) in wallRects.enumerated() {
            let wall = SCNNode(
                geometry: SCNBox(
                    width: wallRect.width,
                    height: GameConstants.clearNewsWallHeight,
                    length: wallRect.height,
                    chamferRadius: 0.1
                )
            )
            wall.name = "clearNewsWall\(index)"
            wall.geometry?.firstMaterial = clearNewsWallMaterial()
            wall.position = position3D(
                for: CGPoint(x: wallRect.midX, y: wallRect.midY),
                elevation: GameConstants.clearNewsWallHeight / 2
            )
            building.addChildNode(wall)
        }

        if !isThirdFloor {
            let doorRect = layout.frontDoorRect
            let doorWidth = doorRect.width * 0.92
            let doorHeight = GameConstants.clearNewsWallHeight * 0.68
            let doorPivot = SCNNode()
            doorPivot.name = "clearNewsDoorPivot"
            doorPivot.position = position3D(
                for: CGPoint(x: doorRect.minX, y: layout.outerRect.minY - 0.05),
                elevation: doorHeight / 2
            )

            let door = SCNNode(
                geometry: SCNBox(
                    width: doorWidth,
                    height: doorHeight,
                    length: 0.16,
                    chamferRadius: 0.08
                )
            )
            door.name = "clearNewsDoor"
            door.geometry?.firstMaterial = clearNewsDoorMaterial()
            door.position = SCNVector3(Float(doorWidth / 2), 0, 0)
            doorPivot.addChildNode(door)
            building.addChildNode(doorPivot)
            clearNewsDoorPivot = doorPivot
        }

        let roof = SCNNode(
            geometry: SCNBox(
                width: layout.outerRect.width + 0.8,
                height: 0.28,
                length: layout.outerRect.height + 0.8,
                chamferRadius: 0.2
            )
        )
        roof.name = "clearNewsRoof"
        roof.geometry?.firstMaterial = clearNewsRoofMaterial()
        roof.position = position3D(
            for: layout.center,
            elevation: GameConstants.clearNewsWallHeight + 0.14
        )
        addClearNewsInterior(to: building, isThirdFloor: isThirdFloor)
        building.addChildNode(roof)
        clearNewsRoofNode = roof

        if !isThirdFloor {
            let sign = SCNNode(
                geometry: SCNPlane(
                    width: layout.outerRect.width * 0.68,
                    height: 2.5
                )
            )
            sign.name = "clearNewsSign"
            sign.geometry?.firstMaterial = clearNewsSignMaterial()
            sign.position = position3D(
                for: CGPoint(x: layout.center.x, y: layout.outerRect.minY - 0.72),
                elevation: GameConstants.clearNewsWallHeight - 1.35
            )
            building.addChildNode(sign)
        }

        worldNode.addChildNode(building)
    }

    private func addClearNewsInterior(to building: SCNNode, isThirdFloor: Bool) {
        if isThirdFloor {
            addClearNewsOfficeDoor(to: building)
            addClearNewsPrinter(to: building)
        } else {
            let counterRect = GameConstants.clearNewsCounterRect
            let counter = SCNNode(
                geometry: SCNBox(
                    width: counterRect.width,
                    height: 1.18,
                    length: counterRect.height,
                    chamferRadius: 0.08
                )
            )
            counter.name = "clearNewsCounter"
            counter.geometry?.firstMaterial = clearNewsCounterMaterial()
            counter.position = position3D(
                for: CGPoint(x: counterRect.midX, y: counterRect.midY),
                elevation: 0.59
            )
            building.addChildNode(counter)

            let clerk = PlayerNode(
                radius: GameConstants.clearNewsClerkRadius,
                outfit: .clearNewsClerk
            )
            clerk.name = "clearNewsClerk"
            clerk.setMovementState(.idle)
            clerk.setFacing(vector: CGVector(dx: 0, dy: -1), animated: false)
            clerk.position = position3D(
                for: GameConstants.clearNewsClerkPoint,
                elevation: GameConstants.clearNewsFloorHeight
            )
            building.addChildNode(clerk)
            clearNewsClerkNode = clerk
        }

        addClearNewsElevator(to: building)
    }

    private func addClearNewsOfficeDoor(
        to building: SCNNode,
        layout: ShellBuildingLayout = GameConstants.clearNewsThirdFloorLayout,
        doorRect: CGRect = GameConstants.clearNewsThirdFloorOfficeDoorRect,
        wallOrientation: DoorWallOrientation = .north,
        showsPlaque: Bool = true
    ) {
        let doorHeight = GameConstants.clearNewsWallHeight * 0.7
        let doorWidth = doorRect.width * 0.94
        let doorPivot = SCNNode()
        doorPivot.name = "clearNewsOfficeDoorPivot"
        doorPivot.position = position3D(
            for: CGPoint(
                x: doorRect.minX,
                y: wallOrientation == .north
                    ? layout.outerRect.maxY + 0.05
                    : layout.outerRect.minY - 0.05
            ),
            elevation: doorHeight / 2
        )

        let door = SCNNode(
            geometry: SCNBox(
                width: doorWidth,
                height: doorHeight,
                length: 0.16,
                chamferRadius: 0.06
            )
        )
        door.name = "clearNewsOfficeDoor"
        door.geometry?.firstMaterial = clearNewsOfficeDoorMaterial()
        door.position = SCNVector3(Float(doorWidth / 2), 0, 0)
        doorPivot.addChildNode(door)
        building.addChildNode(doorPivot)
        clearNewsOfficeDoorPivot = doorPivot
        clearNewsOfficeDoorWallOrientation = wallOrientation

        guard showsPlaque else {
            return
        }

        let plaque = SCNNode(
            geometry: SCNPlane(
                width: doorRect.width * 1.7,
                height: 1.35
            )
        )
        plaque.name = "clearNewsOfficePlaque"
        plaque.geometry?.firstMaterial = clearNewsOfficePlaqueMaterial()
        plaque.position = position3D(
            for: CGPoint(x: doorRect.midX, y: doorRect.midY - 0.14),
            elevation: doorHeight + 0.72
        )
        building.addChildNode(plaque)
    }

    private func addClearNewsPrinter(to building: SCNNode) {
        let printer = SCNNode()
        printer.name = "clearNewsPrinter"
        printer.position = position3D(
            for: GameConstants.clearNewsThirdFloorPrinterPoint,
            elevation: 0
        )
        printer.eulerAngles.y = -.pi / 10

        let body = SCNNode(
            geometry: SCNBox(
                width: 1.02,
                height: 1.08,
                length: 0.76,
                chamferRadius: 0.04
            )
        )
        body.name = "clearNewsPrinterBody"
        body.geometry?.firstMaterial = clearNewsPrinterMaterial()
        body.position.y = 0.54
        printer.addChildNode(body)

        let top = SCNNode(
            geometry: SCNBox(
                width: 1.12,
                height: 0.14,
                length: 0.88,
                chamferRadius: 0.03
            )
        )
        top.name = "clearNewsPrinterTop"
        top.geometry?.firstMaterial = clearNewsPrinterTopMaterial()
        top.position = SCNVector3(0, 1.16, -0.03)
        printer.addChildNode(top)

        let paperDoor = SCNNode(
            geometry: SCNBox(
                width: 0.64,
                height: 0.36,
                length: 0.04,
                chamferRadius: 0.02
            )
        )
        paperDoor.name = "clearNewsPrinterPaperDoor"
        paperDoor.geometry?.firstMaterial = clearNewsPrinterMaterial()
        paperDoor.position = SCNVector3(0, 0.48, 0.37)
        printer.addChildNode(paperDoor)

        let outputTray = SCNNode(
            geometry: SCNBox(
                width: 0.6,
                height: 0.05,
                length: 0.3,
                chamferRadius: 0.02
            )
        )
        outputTray.name = "clearNewsPrinterOutputTray"
        outputTray.geometry?.firstMaterial = clearNewsPrinterTopMaterial()
        outputTray.position = SCNVector3(0, 1.01, 0.45)
        printer.addChildNode(outputTray)

        let panel = SCNNode(
            geometry: SCNPlane(
                width: 0.34,
                height: 0.16
            )
        )
        panel.name = "clearNewsPrinterPanel"
        panel.geometry?.firstMaterial = clearNewsPrinterPanelMaterial()
        panel.position = SCNVector3(0.21, 1.04, 0.395)
        panel.eulerAngles.x = -.pi / 2
        printer.addChildNode(panel)

        building.addChildNode(printer)
    }

    private func addClearNewsOfficeInterior(to building: SCNNode) {
        let deskRect = GameConstants.clearNewsOfficeDeskRect
        let desk = SCNNode(
            geometry: SCNBox(
                width: deskRect.width,
                height: 0.92,
                length: deskRect.height,
                chamferRadius: 0.08
            )
        )
        desk.name = "clearNewsOfficeDesk"
        desk.geometry?.firstMaterial = clearNewsOfficeDeskMaterial()
        desk.position = position3D(
            for: CGPoint(x: deskRect.midX, y: deskRect.midY),
            elevation: 0.46
        )
        building.addChildNode(desk)

        let chair = SCNNode(
            geometry: SCNCylinder(radius: 0.34, height: 0.76)
        )
        chair.name = "clearNewsOfficeChair"
        chair.geometry?.firstMaterial = clearNewsOfficeChairMaterial()
        chair.position = position3D(
            for: GameConstants.clearNewsOfficeChairPoint,
            elevation: 0.38
        )
        building.addChildNode(chair)

        let johnson = PlayerNode(
            radius: GameConstants.clearNewsOfficeJohnsonRadius,
            outfit: .johnson
        )
        johnson.name = "clearNewsOfficeJohnson"
        johnson.setMovementState(.idle)
        johnson.setFacing(vector: CGVector(dx: 0, dy: -1), animated: false)
        johnson.position = position3D(
            for: GameConstants.clearNewsOfficeJohnsonPoint,
            elevation: GameConstants.clearNewsFloorHeight
        )
        building.addChildNode(johnson)

        let lamp = SCNNode()
        lamp.name = "clearNewsOfficeLamp"
        lamp.position = position3D(for: GameConstants.clearNewsOfficeLampPoint)

        let lampBase = SCNNode(geometry: SCNCylinder(radius: 0.18, height: 0.08))
        lampBase.name = "clearNewsOfficeLampBase"
        lampBase.geometry?.firstMaterial = clearNewsOfficeLampMetalMaterial()
        lampBase.position = SCNVector3(0, 0.04, 0)
        lamp.addChildNode(lampBase)

        let lampPole = SCNNode(geometry: SCNCylinder(radius: 0.05, height: 2.15))
        lampPole.name = "clearNewsOfficeLampPole"
        lampPole.geometry?.firstMaterial = clearNewsOfficeLampMetalMaterial()
        lampPole.position = SCNVector3(0, 1.08, 0)
        lamp.addChildNode(lampPole)

        let lampShade = SCNNode(geometry: SCNCylinder(radius: 0.34, height: 0.46))
        lampShade.name = "clearNewsOfficeLampShade"
        lampShade.geometry?.firstMaterial = clearNewsOfficeLampShadeMaterial()
        lampShade.position = SCNVector3(0, 2.26, 0)
        lamp.addChildNode(lampShade)

        let lampBulb = SCNNode(geometry: SCNSphere(radius: 0.1))
        lampBulb.name = "clearNewsOfficeLampBulb"
        lampBulb.geometry?.firstMaterial = clearNewsOfficeLampBulbMaterial()
        lampBulb.position = SCNVector3(0, 2.16, 0)
        lamp.addChildNode(lampBulb)

        let lampLight = SCNNode()
        lampLight.name = "clearNewsOfficeLampLight"
        lampLight.light = SCNLight()
        lampLight.light?.type = .omni
        lampLight.light?.color = UIColor(red: 1.0, green: 0.93, blue: 0.76, alpha: 1.0)
        lampLight.light?.intensity = 720
        lampLight.light?.attenuationStartDistance = 1.0
        lampLight.light?.attenuationEndDistance = 8.0
        lampLight.position = SCNVector3(0, 2.1, 0)
        lamp.addChildNode(lampLight)
        clearNewsOfficeLampLightNode = lampLight

        building.addChildNode(lamp)

        let bookshelfRect = GameConstants.clearNewsOfficeBookshelfRect
        let bookshelf = SCNNode(
            geometry: SCNBox(
                width: bookshelfRect.width,
                height: 2.3,
                length: bookshelfRect.height,
                chamferRadius: 0.04
            )
        )
        bookshelf.name = "clearNewsOfficeBookshelf"
        bookshelf.geometry?.firstMaterial = clearNewsOfficeDeskMaterial()
        bookshelf.position = position3D(
            for: CGPoint(x: bookshelfRect.midX, y: bookshelfRect.midY),
            elevation: 1.15
        )
        building.addChildNode(bookshelf)
    }

    private func addClearNewsElevator(to building: SCNNode) {
        let layout = GameConstants.clearNewsElevatorLayout
        let wallHeight: CGFloat = 4.4

        for (index, wallRect) in layout.wallRects.enumerated() {
            let wall = SCNNode(
                geometry: SCNBox(
                    width: wallRect.width,
                    height: wallHeight,
                    length: wallRect.height,
                    chamferRadius: 0.04
                )
            )
            wall.name = "clearNewsElevatorWall\(index)"
            wall.geometry?.firstMaterial = clearNewsElevatorMaterial()
            wall.position = position3D(
                for: CGPoint(x: wallRect.midX, y: wallRect.midY),
                elevation: wallHeight / 2
            )
            building.addChildNode(wall)
        }

        let roof = SCNNode(
            geometry: SCNBox(
                width: layout.outerRect.width + 0.18,
                height: 0.18,
                length: layout.outerRect.height + 0.18,
                chamferRadius: 0.04
            )
        )
        roof.name = "clearNewsElevatorRoof"
        roof.geometry?.firstMaterial = clearNewsElevatorMaterial()
        roof.position = position3D(
            for: layout.center,
            elevation: wallHeight + 0.09
        )
        building.addChildNode(roof)
        clearNewsElevatorRoofNode = roof

        let doorHeight = wallHeight * 0.82
        let doorDepth: CGFloat = 0.08
        let doorGap: CGFloat = 0.08
        let singleDoorWidth = (layout.frontDoorRect.width - doorGap) / 2
        let doorY = layout.outerRect.minY - 0.01

        let leftDoor = SCNNode(
            geometry: SCNBox(
                width: singleDoorWidth,
                height: doorHeight,
                length: doorDepth,
                chamferRadius: 0.03
            )
        )
        leftDoor.name = "clearNewsElevatorLeftDoor"
        leftDoor.geometry?.firstMaterial = clearNewsElevatorDoorMaterial()
        leftDoor.position = position3D(
            for: CGPoint(
                x: layout.frontDoorRect.minX + (singleDoorWidth / 2),
                y: doorY
            ),
            elevation: doorHeight / 2
        )
        building.addChildNode(leftDoor)
        clearNewsElevatorLeftDoorNode = leftDoor

        let rightDoor = SCNNode(
            geometry: SCNBox(
                width: singleDoorWidth,
                height: doorHeight,
                length: doorDepth,
                chamferRadius: 0.03
            )
        )
        rightDoor.name = "clearNewsElevatorRightDoor"
        rightDoor.geometry?.firstMaterial = clearNewsElevatorDoorMaterial()
        rightDoor.position = position3D(
            for: CGPoint(
                x: layout.frontDoorRect.maxX - (singleDoorWidth / 2),
                y: doorY
            ),
            elevation: doorHeight / 2
        )
        building.addChildNode(rightDoor)
        clearNewsElevatorRightDoorNode = rightDoor
        applyClearNewsElevatorDoorState(animated: false)
    }

    private func addHomesteadTreeBands() {
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

    private func addTrafficTreeBands(layout: CrossroadsLayout, includeHomeRoad: Bool) {
        let approachRoadClearing = layout.verticalRoadRect.insetBy(dx: -1.1, dy: -1.5)
        let mainRoadClearing = layout.horizontalRoadRect.insetBy(dx: -1.4, dy: -1.8)

        addHorizontalTreeBand(
            startX: layout.worldRect.minX + (GameConstants.treeSpacing / 2),
            endX: layout.worldRect.maxX - (GameConstants.treeSpacing / 2),
            frontY: layout.movementRect.maxY + (GameConstants.frontTreeSize * 0.3),
            depthDirection: 1,
            variationOffset: 7_000
        )
        addHorizontalTreeBand(
            startX: layout.worldRect.minX + (GameConstants.treeSpacing / 2),
            endX: layout.worldRect.maxX - (GameConstants.treeSpacing / 2),
            frontY: layout.movementRect.minY - (GameConstants.frontTreeSize * 0.3),
            depthDirection: -1,
            variationOffset: 8_000,
            clearings: includeHomeRoad ? [approachRoadClearing] : []
        )
        addVerticalTreeBand(
            startY: layout.worldRect.minY + (GameConstants.treeSpacing / 2),
            endY: layout.worldRect.maxY - (GameConstants.treeSpacing / 2),
            frontX: layout.movementRect.minX - (GameConstants.frontTreeSize * 0.3),
            depthDirection: -1,
            variationOffset: 9_000,
            clearings: [mainRoadClearing]
        )
        addVerticalTreeBand(
            startY: layout.worldRect.minY + (GameConstants.treeSpacing / 2),
            endY: layout.worldRect.maxY - (GameConstants.treeSpacing / 2),
            frontX: layout.movementRect.maxX + (GameConstants.frontTreeSize * 0.3),
            depthDirection: 1,
            variationOffset: 10_000,
            clearings: [mainRoadClearing]
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

    private func addFloorDetails(in playableRect: CGRect, excludedRects: [CGRect]) {
        for index in 0..<24 {
            let xRatio = 0.08 + (variation(for: index, salt: 3) * 0.84)
            let yRatio = 0.08 + (variation(for: index, salt: 5) * 0.84)
            let radius = 0.5 + (variation(for: index, salt: 13) * 1.4)
            let point = CGPoint(
                x: playableRect.minX + (playableRect.width * xRatio),
                y: playableRect.minY + (playableRect.height * yRatio)
            )

            guard !excludedRects.contains(where: { $0.contains(point) }) else {
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

    private func addTrafficCars() {
        let layout = activeTrafficLayout
        let colors: [UIColor] = [
            UIColor(red: 0.83, green: 0.24, blue: 0.22, alpha: 1.0),
            UIColor(red: 0.21, green: 0.49, blue: 0.82, alpha: 1.0),
            UIColor(red: 0.94, green: 0.73, blue: 0.22, alpha: 1.0),
            UIColor(red: 0.18, green: 0.67, blue: 0.43, alpha: 1.0),
            UIColor(red: 0.78, green: 0.44, blue: 0.19, alpha: 1.0),
            UIColor(red: 0.56, green: 0.34, blue: 0.76, alpha: 1.0)
        ]
        let configurations: [(CGFloat, CGFloat, Int)] = [
            (layout.trafficWrapRange.lowerBound + 8, layout.trafficLaneYs[0], 0),
            (layout.trafficWrapRange.upperBound - 14, layout.trafficLaneYs[1], 1),
            (layout.trafficWrapRange.lowerBound + 31, layout.trafficLaneYs[0], 2),
            (layout.trafficWrapRange.upperBound - 37, layout.trafficLaneYs[1], 3),
            (layout.trafficWrapRange.lowerBound + 53, layout.trafficLaneYs[0], 4),
            (layout.trafficWrapRange.upperBound - 61, layout.trafficLaneYs[1], 5)
        ]

        trafficCars = configurations.enumerated().map { index, configuration in
            let (x, laneY, colorIndex) = configuration
            let direction: CGFloat = laneY < layout.horizontalRoadRect.midY ? 1 : -1
            let length = 2.6 + (variation(for: index, salt: 311) * 1.3)
            let width = 1.34 + (variation(for: index, salt: 313) * 0.42)
            let node = trafficCarNode(
                styleIndex: index,
                bodyColor: colors[colorIndex % colors.count],
                length: length,
                width: width,
                name: "trafficCar"
            )
            node.position = position3D(for: CGPoint(x: x, y: laneY), elevation: 0.05)
            worldNode.addChildNode(node)

            return TrafficCarState(
                node: node,
                laneY: laneY,
                direction: direction,
                speed: GameConstants.trafficCarBaseSpeed + (variation(for: index, salt: 317) * 2.8),
                halfLength: length / 2,
                halfWidth: width / 2,
                x: x
            )
        }
    }

    private func ensureParkedCarForCurrentArea(defaultPoint: CGPoint) {
        if
            currentArea.isTrafficArea,
            parkedCarState == nil || (parkedCarState?.isOccupied == false && parkedCarState?.area != currentArea)
        {
            let node = trafficCarNode(
                styleIndex: 6,
                bodyColor: UIColor(red: 0.78, green: 0.16, blue: 0.14, alpha: 1.0),
                length: GameConstants.parkedCarLength,
                width: GameConstants.parkedCarWidth,
                name: "parkedCar"
            )
            parkedCarState = ParkedCarState(
                node: node,
                halfLength: GameConstants.parkedCarLength / 2,
                halfWidth: GameConstants.parkedCarWidth / 2,
                area: currentArea,
                point: defaultPoint,
                headingVector: CGVector(dx: 0, dy: 1),
                isOccupied: false
            )
        }

        guard let parkedCarState, parkedCarState.area == currentArea else {
            return
        }

        updateParkedCarNode()
        worldNode.addChildNode(parkedCarState.node)
    }

    private func trafficCarNode(
        styleIndex: Int,
        bodyColor: UIColor,
        length: CGFloat,
        width: CGFloat,
        name: String
    ) -> SCNNode {
        let root = SCNNode()
        root.name = name

        let bodyMaterial = material(diffuse: bodyColor, roughness: 0.6)
        let trimMaterial = material(
            diffuse: UIColor(red: 0.12, green: 0.14, blue: 0.16, alpha: 1.0),
            roughness: 0.55
        )
        let windowMaterial = material(
            diffuse: UIColor(red: 0.73, green: 0.84, blue: 0.95, alpha: 1.0),
            roughness: 0.18
        )
        windowMaterial.transparency = 0.88

        let body = SCNNode(
            geometry: SCNBox(
                width: length,
                height: 0.72,
                length: width,
                chamferRadius: 0.16
            )
        )
        body.geometry?.firstMaterial = bodyMaterial
        body.position = SCNVector3(0, 0.46, 0)
        root.addChildNode(body)

        let cabinLength = length * (styleIndex % 3 == 0 ? 0.38 : 0.46)
        let cabin = SCNNode(
            geometry: SCNBox(
                width: cabinLength,
                height: styleIndex.isMultiple(of: 2) ? 0.62 : 0.74,
                length: width * 0.82,
                chamferRadius: 0.12
            )
        )
        cabin.geometry?.firstMaterial = styleIndex % 3 == 1 ? trimMaterial : windowMaterial
        cabin.position = SCNVector3(
            Float(styleIndex % 2 == 0 ? length * 0.12 : -length * 0.08),
            Float(styleIndex.isMultiple(of: 2) ? 0.98 : 1.04),
            0
        )
        root.addChildNode(cabin)

        if styleIndex % 3 == 2 {
            let cargo = SCNNode(
                geometry: SCNBox(
                    width: length * 0.3,
                    height: 0.28,
                    length: width * 0.74,
                    chamferRadius: 0.08
                )
            )
            cargo.geometry?.firstMaterial = trimMaterial
            cargo.position = SCNVector3(Float(-length * 0.18), 0.86, 0)
            root.addChildNode(cargo)
        }

        let wheelOffsets = [
            (length * 0.3, width * 0.34),
            (length * 0.3, -width * 0.34),
            (-length * 0.3, width * 0.34),
            (-length * 0.3, -width * 0.34)
        ]
        for (x, z) in wheelOffsets {
            let wheel = SCNNode(geometry: SCNCylinder(radius: 0.23, height: 0.18))
            wheel.geometry?.firstMaterial = trimMaterial
            wheel.position = SCNVector3(Float(x), 0.22, Float(z))
            wheel.eulerAngles.x = .pi / 2
            root.addChildNode(wheel)
        }

        return root
    }

    private func parkedCarFootprintRect(for point: CGPoint) -> CGRect {
        CGRect(
            x: point.x - (GameConstants.parkedCarWidth / 2),
            y: point.y - (GameConstants.parkedCarLength / 2),
            width: GameConstants.parkedCarWidth,
            height: GameConstants.parkedCarLength
        )
    }

    private func parkedCarInteractionRect(for point: CGPoint) -> CGRect {
        parkedCarFootprintRect(for: point).insetBy(
            dx: -GameConstants.parkedCarInteractionReach,
            dy: -GameConstants.parkedCarInteractionReach
        )
    }

    private func updateParkedCarStateIfNeeded() {
        guard var parkedCarState else {
            return
        }

        if parkedCarState.isOccupied {
            parkedCarState.point = worldFocusPoint
            parkedCarState.headingVector = lastFacingVector
            parkedCarState.area = currentArea
            self.parkedCarState = parkedCarState
        }
        updateParkedCarNode()
    }

    private func updateParkedCarNode() {
        guard let parkedCarState else {
            return
        }

        parkedCarState.node.position = position3D(for: parkedCarState.point, elevation: 0.05)
        parkedCarState.node.eulerAngles.y = Float(
            atan2(parkedCarState.headingVector.dy, parkedCarState.headingVector.dx)
        )
    }

    private func parkedCarExitPoint(from point: CGPoint, heading: CGVector) -> CGPoint {
        let forward = heading == .zero ? CGVector(dx: 0, dy: 1) : heading.normalized
        let lateral = CGVector(dx: -forward.dy, dy: forward.dx)
        let exitDistance = GameConstants.parkedCarWidth / 2 + GameConstants.playerRadius + 0.42
        let fallbackDistance = GameConstants.parkedCarLength / 2 + GameConstants.playerRadius + 0.4

        let candidates = [
            CGPoint(x: point.x + (lateral.dx * exitDistance), y: point.y + (lateral.dy * exitDistance)),
            CGPoint(x: point.x - (lateral.dx * exitDistance), y: point.y - (lateral.dy * exitDistance)),
            CGPoint(x: point.x - (forward.dx * fallbackDistance), y: point.y - (forward.dy * fallbackDistance))
        ]

        for candidate in candidates {
            let clamped = CGPoint(
                x: min(max(candidate.x, activeMovementRect.minX + GameConstants.playerRadius), activeMovementRect.maxX - GameConstants.playerRadius),
                y: min(max(candidate.y, activeMovementRect.minY + GameConstants.playerRadius), activeMovementRect.maxY - GameConstants.playerRadius)
            )
            if parkedCarFootprintRect(for: point)
                .insetBy(dx: -GameConstants.playerRadius, dy: -GameConstants.playerRadius)
                .contains(clamped) == false
            {
                return clamped
            }
        }

        return CGPoint(
            x: point.x,
            y: min(
                max(point.y - fallbackDistance, activeMovementRect.minY + GameConstants.playerRadius),
                activeMovementRect.maxY - GameConstants.playerRadius
            )
        )
    }

    private func updateTraffic(by deltaTime: TimeInterval) {
        guard currentArea.isTrafficArea else {
            return
        }

        let layout = activeTrafficLayout
        let obstacleRadius = isDrivingParkedCar ? GameConstants.parkedCarMovementRadius : GameConstants.playerRadius
        let eastboundObstacleX = trafficLaneInteractionRect(
            laneY: layout.trafficLaneYs[0],
            obstacleRadius: obstacleRadius
        ).contains(worldFocusPoint) ? worldFocusPoint.x : nil
        let westboundObstacleX = trafficLaneInteractionRect(
            laneY: layout.trafficLaneYs[1],
            obstacleRadius: obstacleRadius
        ).contains(worldFocusPoint) ? worldFocusPoint.x : nil

        updateTrafficLane(
            indices: trafficCars.indices
                .filter { trafficCars[$0].direction > 0 }
                .sorted { trafficCars[$0].x > trafficCars[$1].x },
            direction: 1,
            obstacleX: eastboundObstacleX,
            deltaTime: deltaTime,
            layout: layout
        )
        updateTrafficLane(
            indices: trafficCars.indices
                .filter { trafficCars[$0].direction < 0 }
                .sorted { trafficCars[$0].x < trafficCars[$1].x },
            direction: -1,
            obstacleX: westboundObstacleX,
            deltaTime: deltaTime,
            layout: layout
        )

        for index in trafficCars.indices {
            trafficCars[index].node.position = position3D(
                for: CGPoint(x: trafficCars[index].x, y: trafficCars[index].laneY),
                elevation: 0.05
            )
            trafficCars[index].node.eulerAngles.y = trafficCars[index].direction > 0 ? 0 : .pi
        }
    }

    private func updateTrafficLane(
        indices: [Int],
        direction: CGFloat,
        obstacleX: CGFloat?,
        deltaTime: TimeInterval,
        layout: CrossroadsLayout
    ) {
        var leaderCenterX: CGFloat?
        var leaderHalfLength: CGFloat?

        for index in indices {
            let car = trafficCars[index]
            var proposedX = car.x + (car.direction * car.speed * deltaTime)

            if let obstacleX {
                if direction > 0, car.x < obstacleX {
                    let stopCenterX = obstacleX
                        - activeTrafficObstacleRadius
                        - GameConstants.trafficPedestrianYieldGap
                        - car.halfLength
                    proposedX = min(proposedX, stopCenterX)
                } else if direction < 0, car.x > obstacleX {
                    let stopCenterX = obstacleX
                        + activeTrafficObstacleRadius
                        + GameConstants.trafficPedestrianYieldGap
                        + car.halfLength
                    proposedX = max(proposedX, stopCenterX)
                }
            }

            if let leaderCenterX, let leaderHalfLength {
                let followingDistance = leaderHalfLength + car.halfLength + GameConstants.trafficCarFollowingGap
                if direction > 0 {
                    proposedX = min(proposedX, leaderCenterX - followingDistance)
                } else {
                    proposedX = max(proposedX, leaderCenterX + followingDistance)
                }
            }

            var wrapped = false
            if direction > 0 {
                proposedX = max(proposedX, car.x)
            } else {
                proposedX = min(proposedX, car.x)
            }
            if
                direction > 0,
                proposedX - car.halfLength > layout.trafficWrapRange.upperBound
            {
                proposedX = layout.trafficWrapRange.lowerBound - car.halfLength
                wrapped = true
            } else if
                direction < 0,
                proposedX + car.halfLength < layout.trafficWrapRange.lowerBound
            {
                proposedX = layout.trafficWrapRange.upperBound + car.halfLength
                wrapped = true
            }

            trafficCars[index].x = proposedX

            if wrapped {
                leaderCenterX = nil
                leaderHalfLength = nil
            } else {
                leaderCenterX = proposedX
                leaderHalfLength = car.halfLength
            }
        }
    }

    private var activeTrafficObstacleRadius: CGFloat {
        isDrivingParkedCar ? GameConstants.parkedCarMovementRadius : GameConstants.playerRadius
    }

    private func trafficLaneInteractionRect(laneY: CGFloat, obstacleRadius: CGFloat) -> CGRect {
        let laneHalfHeight = GameConstants.trafficCarMaxWidth / 2
            + obstacleRadius
            + GameConstants.trafficPedestrianYieldGap
        return CGRect(
            x: activeTrafficLayout.horizontalRoadRect.minX,
            y: laneY - laneHalfHeight,
            width: activeTrafficLayout.horizontalRoadRect.width,
            height: laneHalfHeight * 2
        )
    }

    private func trafficCarFootprintRect(for car: TrafficCarState) -> CGRect {
        CGRect(
            x: car.x - car.halfLength,
            y: car.laneY - car.halfWidth,
            width: car.halfLength * 2,
            height: car.halfWidth * 2
        )
    }

    private func updateWorldOffset() {
        worldNode.position = SCNVector3(Float(-worldFocusPoint.x), 0, Float(worldFocusPoint.y))
        switch cameraFocusMode {
        case .player:
            focusTargetNode.position = SCNVector3(0, 2.15 + playerNode.position.y, 0)
        case .clearNewsClerk:
            guard let clearNewsClerkNode else {
                focusTargetNode.position = SCNVector3(0, 2.15 + playerNode.position.y, 0)
                return
            }

            let clerkWorldPosition = clearNewsClerkNode.presentation.worldPosition
            focusTargetNode.position = SCNVector3(
                clerkWorldPosition.x,
                clerkWorldPosition.y + Float(GameConstants.clearNewsClerkRadius * 2.4),
                clerkWorldPosition.z
            )
        }
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

        let lampProgress = fadeProgress
        clearNewsOfficeLampLightNode?.light?.intensity = 110 + (610 * lampProgress)

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
        switch currentArea {
        case .homestead:
            spawnHouseNode?.setRoofHidden(GameConstants.spawnHouseLayout.containsInterior(worldFocusPoint))
        case .traffic3, .clearNewsThirdFloor, .clearNewsOffice:
            clearNewsRoofNode?.isHidden = activeClearNewsBuildingLayout.containsInterior(worldFocusPoint)
            clearNewsElevatorRoofNode?.isHidden = GameConstants.clearNewsElevatorLayout.containsInterior(worldFocusPoint)
        case .traffic1, .traffic2:
            return
        }
    }

    private func updatePlayerGrounding() {
        playerNode.setGroundElevation(currentGroundElevation())
    }

    private func currentGroundElevation() -> CGFloat {
        guard
            currentArea == .homestead
                || currentArea == .traffic3
                || currentArea == .clearNewsThirdFloor
                || currentArea == .clearNewsOffice
        else {
            return 0
        }

        switch currentArea {
        case .homestead:
            guard GameConstants.spawnHouseLayout.containsInterior(worldFocusPoint) else {
                return 0
            }
            let foundationHeight = GameConstants.houseWallHeight * 0.12
            let floorHeight = GameConstants.houseWallHeight * 0.06
            return foundationHeight + floorHeight
        case .traffic3:
            guard activeClearNewsBuildingLayout.containsInterior(worldFocusPoint) else {
                return 0
            }
            return GameConstants.clearNewsFloorHeight
        case .clearNewsThirdFloor, .clearNewsOffice:
            return GameConstants.clearNewsFloorHeight
        case .traffic1, .traffic2:
            return 0
        }
    }

    private func refreshRoomBounds() {
        roomBounds = RoomBounds(rect: activeMovementRect, blockedRects: currentBlockedRects())
    }

    private func currentBlockedRects() -> [CGRect] {
        let baseBlockedRects: [CGRect]
        switch currentArea {
        case .homestead:
            let houseBlockedRects = isDrivingParkedCar
                ? [GameConstants.spawnHouseLayout.outerRect]
                : GameConstants.spawnHouseLayout.blockedRects(frontDoorOpen: isFrontDoorOpen)
            baseBlockedRects = houseBlockedRects + worldLayout.blockedRects
        case .traffic1, .traffic2:
            baseBlockedRects = trafficCars.map(trafficCarFootprintRect(for:))
        case .traffic3:
            baseBlockedRects = GameConstants.clearNewsBuildingLayout.blockedRects(frontDoorOpen: isClearNewsDoorOpen)
                + [GameConstants.clearNewsCounterRect]
                + GameConstants.clearNewsElevatorLayout.blockedRects(frontDoorOpen: isClearNewsElevatorDoorOpenState)
                + [CGRect(
                    x: GameConstants.clearNewsClerkPoint.x - GameConstants.clearNewsClerkRadius,
                    y: GameConstants.clearNewsClerkPoint.y - GameConstants.clearNewsClerkRadius,
                    width: GameConstants.clearNewsClerkRadius * 2,
                    height: GameConstants.clearNewsClerkRadius * 2
                )]
                + trafficCars.map(trafficCarFootprintRect(for:))
        case .clearNewsThirdFloor:
            baseBlockedRects = clearNewsThirdFloorBlockedRects
                + GameConstants.clearNewsElevatorLayout.blockedRects(frontDoorOpen: isClearNewsElevatorDoorOpenState)
        case .clearNewsOffice:
            baseBlockedRects = GameConstants.clearNewsOfficeLayout.blockedRects(frontDoorOpen: isClearNewsOfficeDoorOpen)
                + [
                    GameConstants.clearNewsOfficeDeskRect,
                    CGRect(
                        x: GameConstants.clearNewsOfficeChairPoint.x - 0.38,
                        y: GameConstants.clearNewsOfficeChairPoint.y - 0.38,
                        width: 0.76,
                        height: 0.76
                    ),
                    CGRect(
                        x: GameConstants.clearNewsOfficeJohnsonPoint.x - GameConstants.clearNewsOfficeJohnsonRadius,
                        y: GameConstants.clearNewsOfficeJohnsonPoint.y - GameConstants.clearNewsOfficeJohnsonRadius,
                        width: GameConstants.clearNewsOfficeJohnsonRadius * 2,
                        height: GameConstants.clearNewsOfficeJohnsonRadius * 2
                    ),
                    GameConstants.clearNewsOfficeLampRect,
                    GameConstants.clearNewsOfficeBookshelfRect
                ]
        }

        guard
            let parkedCarState,
            parkedCarState.area == currentArea,
            !parkedCarState.isOccupied
        else {
            return baseBlockedRects
        }

        return baseBlockedRects + [parkedCarFootprintRect(for: parkedCarState.point)]
    }

    private func updateDoorStates(current: CGPoint, proposed: CGPoint) {
        guard !isDrivingParkedCar else {
            isFrontDoorOpen = false
            spawnHouseNode?.setFrontDoorOpen(false, swingDirection: .outward)
            setClearNewsDoorOpen(false, swingDirection: .outward)
            setClearNewsOfficeDoorOpen(false, swingDirection: .outward, wallOrientation: clearNewsOfficeDoorWallOrientation)
            return
        }

        switch currentArea {
        case .homestead:
            let frontDoorShouldOpen = shouldOpenDoor(
                openingRect: GameConstants.spawnHouseLayout.frontDoorOpeningRect,
                current: current,
                proposed: proposed
            )
            let frontDoorSwingDirection = swingDirection(
                openingRect: GameConstants.spawnHouseLayout.frontDoorOpeningRect,
                containsInterior: GameConstants.spawnHouseLayout.containsInterior,
                current: current,
                proposed: proposed
            )

            isFrontDoorOpen = frontDoorShouldOpen
            spawnHouseNode?.setFrontDoorOpen(frontDoorShouldOpen, swingDirection: frontDoorSwingDirection)
            setClearNewsDoorOpen(false, swingDirection: .outward)
            setClearNewsOfficeDoorOpen(false, swingDirection: .outward, wallOrientation: clearNewsOfficeDoorWallOrientation)
        case .traffic3:
            isFrontDoorOpen = false
            spawnHouseNode?.setFrontDoorOpen(false, swingDirection: .outward)

            let clearNewsDoorShouldOpen = shouldOpenDoor(
                openingRect: GameConstants.clearNewsBuildingLayout.frontDoorRect,
                current: current,
                proposed: proposed
            )
            let clearNewsSwingDirection = swingDirection(
                openingRect: GameConstants.clearNewsBuildingLayout.frontDoorRect,
                containsInterior: GameConstants.clearNewsBuildingLayout.containsInterior,
                current: current,
                proposed: proposed
            )
            setClearNewsDoorOpen(clearNewsDoorShouldOpen, swingDirection: clearNewsSwingDirection)
            setClearNewsOfficeDoorOpen(false, swingDirection: .outward, wallOrientation: clearNewsOfficeDoorWallOrientation)
        case .clearNewsThirdFloor:
            isFrontDoorOpen = false
            spawnHouseNode?.setFrontDoorOpen(false, swingDirection: .outward)
            setClearNewsDoorOpen(false, swingDirection: .outward)
            let officeDoorShouldOpen = shouldOpenDoor(
                openingRect: GameConstants.clearNewsThirdFloorOfficeDoorRect,
                current: current,
                proposed: proposed
            )
            let officeDoorSwingDirection = swingDirection(
                openingRect: GameConstants.clearNewsThirdFloorOfficeDoorRect,
                containsInterior: GameConstants.clearNewsThirdFloorLayout.containsInterior,
                current: current,
                proposed: proposed
            )
            setClearNewsOfficeDoorOpen(
                officeDoorShouldOpen,
                swingDirection: officeDoorSwingDirection,
                wallOrientation: .north
            )
        case .clearNewsOffice:
            isFrontDoorOpen = false
            spawnHouseNode?.setFrontDoorOpen(false, swingDirection: .outward)
            setClearNewsDoorOpen(false, swingDirection: .outward)
            let officeDoorShouldOpen = shouldOpenDoor(
                openingRect: GameConstants.clearNewsOfficeLayout.frontDoorRect,
                current: current,
                proposed: proposed
            )
            let officeDoorSwingDirection = swingDirection(
                openingRect: GameConstants.clearNewsOfficeLayout.frontDoorRect,
                containsInterior: GameConstants.clearNewsOfficeLayout.containsInterior,
                current: current,
                proposed: proposed
            )
            setClearNewsOfficeDoorOpen(
                officeDoorShouldOpen,
                swingDirection: officeDoorSwingDirection,
                wallOrientation: .south
            )
        case .traffic1, .traffic2:
            isFrontDoorOpen = false
            spawnHouseNode?.setFrontDoorOpen(false, swingDirection: .outward)
            setClearNewsDoorOpen(false, swingDirection: .outward)
            setClearNewsOfficeDoorOpen(false, swingDirection: .outward, wallOrientation: clearNewsOfficeDoorWallOrientation)
        }
    }

    private func swingDirection(
        openingRect: CGRect,
        containsInterior: (CGPoint) -> Bool,
        current: CGPoint,
        proposed: CGPoint
    ) -> HouseNode.DoorSwingDirection {
        let currentInside = containsInterior(current)
        let proposedInside = containsInterior(proposed)

        if currentInside && !proposedInside {
            return .outward
        }
        if !currentInside && proposedInside {
            return .inward
        }
        return proposed.y >= openingRect.midY ? .inward : .outward
    }

    private func setClearNewsDoorOpen(_ isOpen: Bool, swingDirection: HouseNode.DoorSwingDirection) {
        guard
            isClearNewsDoorOpen != isOpen || clearNewsDoorSwingDirection != swingDirection
        else {
            return
        }

        isClearNewsDoorOpen = isOpen
        clearNewsDoorSwingDirection = swingDirection

        let openAngle: Float = swingDirection == .inward ? -.pi / 2.35 : .pi / 2.35
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.24
        clearNewsDoorPivot?.eulerAngles.y = isOpen ? openAngle : 0
        SCNTransaction.commit()
    }

    private func setClearNewsOfficeDoorOpen(
        _ isOpen: Bool,
        swingDirection: HouseNode.DoorSwingDirection,
        wallOrientation: DoorWallOrientation
    ) {
        guard
            isClearNewsOfficeDoorOpen != isOpen
                || clearNewsOfficeDoorSwingDirection != swingDirection
                || clearNewsOfficeDoorWallOrientation != wallOrientation
        else {
            return
        }

        isClearNewsOfficeDoorOpen = isOpen
        clearNewsOfficeDoorSwingDirection = swingDirection
        clearNewsOfficeDoorWallOrientation = wallOrientation

        let openAngle: Float
        switch wallOrientation {
        case .north:
            openAngle = swingDirection == .inward ? .pi / 2.35 : -.pi / 2.35
        case .south:
            openAngle = swingDirection == .inward ? -.pi / 2.35 : .pi / 2.35
        }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.24
        clearNewsOfficeDoorPivot?.eulerAngles.y = isOpen ? openAngle : 0
        SCNTransaction.commit()
    }

    private func setClearNewsElevatorDoorOpen(_ isOpen: Bool, animated: Bool = true) {
        guard isClearNewsElevatorDoorOpenState != isOpen else {
            return
        }

        isClearNewsElevatorDoorOpenState = isOpen
        applyClearNewsElevatorDoorState(animated: animated)
    }

    private func applyClearNewsElevatorDoorState(animated: Bool) {
        let layout = GameConstants.clearNewsElevatorLayout
        let doorGap: CGFloat = 0.08
        let singleDoorWidth = (layout.frontDoorRect.width - doorGap) / 2
        let doorY = layout.outerRect.minY - 0.01
        let doorHeight = 4.4 * 0.82
        let doorTravel = singleDoorWidth * 0.82

        let leftDoorPosition = position3D(
            for: CGPoint(
                x: layout.frontDoorRect.minX + (singleDoorWidth / 2)
                    - (isClearNewsElevatorDoorOpenState ? doorTravel : 0),
                y: doorY
            ),
            elevation: doorHeight / 2
        )
        let rightDoorPosition = position3D(
            for: CGPoint(
                x: layout.frontDoorRect.maxX - (singleDoorWidth / 2)
                    + (isClearNewsElevatorDoorOpenState ? doorTravel : 0),
                y: doorY
            ),
            elevation: doorHeight / 2
        )

        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.22
        }
        clearNewsElevatorLeftDoorNode?.position = leftDoorPosition
        clearNewsElevatorRightDoorNode?.position = rightDoorPosition
        if animated {
            SCNTransaction.commit()
        }
    }

    private func setCameraFocusMode(_ mode: CameraFocusMode, animated: Bool = true) {
        guard cameraFocusMode != mode else {
            return
        }

        cameraFocusMode = mode
        applyCameraFocusMode(animated: animated)
    }

    private func applyCameraFocusMode(animated: Bool) {
        let targetHeight: CGFloat
        let targetDistance: CGFloat
        let targetFieldOfView: CGFloat

        switch cameraFocusMode {
        case .player:
            targetHeight = GameConstants.cameraHeight
            targetDistance = GameConstants.cameraDistance
            targetFieldOfView = GameConstants.cameraFieldOfView
        case .clearNewsClerk:
            targetHeight = GameConstants.conversationCameraHeight
            targetDistance = GameConstants.conversationCameraDistance
            targetFieldOfView = GameConstants.conversationCameraFieldOfView
        }

        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.24
        }
        cameraNode.position = SCNVector3(0, Float(targetHeight), Float(targetDistance))
        cameraNode.camera?.fieldOfView = targetFieldOfView
        if animated {
            SCNTransaction.commit()
        }
    }

    private func updateClearNewsElevatorStateIfNeeded() {
        switch currentArea {
        case .traffic3:
            guard
                hasMetClearNewsReceptionist,
                isClearNewsElevatorDoorOpenState
            else {
                return
            }

            if
                !hasExitedClearNewsLobbyElevator,
                !clearNewsElevatorExitClearanceRect.contains(worldFocusPoint)
            {
                hasExitedClearNewsLobbyElevator = true
                setClearNewsElevatorDoorOpen(false)
                refreshRoomBounds()
                return
            }

            guard
                hasExitedClearNewsLobbyElevator,
                clearNewsElevatorFullyEnteredRect.contains(worldFocusPoint)
            else {
                return
            }

            setClearNewsElevatorDoorOpen(false)
            refreshRoomBounds()
            onClearNewsElevatorSealed?()
        case .clearNewsThirdFloor:
            guard isClearNewsElevatorDoorOpenState else {
                return
            }

            if
                !hasExitedClearNewsThirdFloorElevator,
                !clearNewsElevatorExitClearanceRect.contains(worldFocusPoint)
            {
                hasExitedClearNewsThirdFloorElevator = true
                setClearNewsElevatorDoorOpen(false)
                refreshRoomBounds()
                return
            }

            guard
                hasExitedClearNewsThirdFloorElevator,
                clearNewsElevatorFullyEnteredRect.contains(worldFocusPoint)
            else {
                return
            }

            setClearNewsElevatorDoorOpen(false)
            refreshRoomBounds()
            onClearNewsElevatorSealed?()
        case .homestead, .traffic1, .traffic2, .clearNewsOffice:
            return
        }
    }

    private func updateAreaTransitionIfNeeded() {
        guard !areaTransitionPending else {
            return
        }

        switch currentArea {
        case .homestead:
            let movementRadius = isDrivingParkedCar ? GameConstants.parkedCarMovementRadius : GameConstants.playerRadius
            let exitThreshold = worldLayout.movementRect.maxY - (movementRadius + 0.1)
            guard
                worldFocusPoint.y >= exitThreshold,
                worldLayout.roadCorridorRect.insetBy(dx: 0.15, dy: 0).contains(worldFocusPoint)
            else {
                return
            }

            areaTransitionPending = true
            playerNode.setMovementState(.idle)
            onNorthRoadExitReached?()
        case .traffic1:
            let layout = activeTrafficLayout
            let movementRadius = isDrivingParkedCar ? GameConstants.parkedCarMovementRadius : GameConstants.playerRadius
            let southExitThreshold = layout.movementRect.minY + (movementRadius + 0.1)
            if
                worldFocusPoint.y <= southExitThreshold,
                layout.verticalRoadRect.insetBy(dx: 0.2, dy: 0).contains(worldFocusPoint)
            {
                areaTransitionPending = true
                playerNode.setMovementState(.idle)
                onSouthRoadExitReached?()
                return
            }

            let westExitThreshold = layout.movementRect.minX + (movementRadius + 0.1)
            guard
                worldFocusPoint.x <= westExitThreshold,
                layout.horizontalRoadRect.insetBy(dx: 0, dy: 0.2).contains(worldFocusPoint)
            else {
                return
            }

            areaTransitionPending = true
            playerNode.setMovementState(.idle)
            onWestRoadExitReached?()
        case .traffic2:
            let layout = activeTrafficLayout
            let movementRadius = isDrivingParkedCar ? GameConstants.parkedCarMovementRadius : GameConstants.playerRadius
            let westExitThreshold = layout.movementRect.minX + (movementRadius + 0.1)
            if
                worldFocusPoint.x <= westExitThreshold,
                layout.horizontalRoadRect.insetBy(dx: 0, dy: 0.2).contains(worldFocusPoint)
            {
                areaTransitionPending = true
                playerNode.setMovementState(.idle)
                onWestRoadExitReached?()
                return
            }

            let eastExitThreshold = layout.movementRect.maxX - (movementRadius + 0.1)
            guard
                worldFocusPoint.x >= eastExitThreshold,
                layout.horizontalRoadRect.insetBy(dx: 0, dy: 0.2).contains(worldFocusPoint)
            else {
                return
            }

            areaTransitionPending = true
            playerNode.setMovementState(.idle)
            onEastRoadExitReached?()
        case .traffic3:
            let layout = activeTrafficLayout
            let movementRadius = isDrivingParkedCar ? GameConstants.parkedCarMovementRadius : GameConstants.playerRadius
            let eastExitThreshold = layout.movementRect.maxX - (movementRadius + 0.1)
            guard
                worldFocusPoint.x >= eastExitThreshold,
                layout.horizontalRoadRect.insetBy(dx: 0, dy: 0.2).contains(worldFocusPoint)
            else {
                return
            }

            areaTransitionPending = true
            playerNode.setMovementState(.idle)
            onEastRoadExitReached?()
        case .clearNewsThirdFloor:
            guard
                isClearNewsOfficeDoorOpen,
                clearNewsOfficeDoorOpenElapsed >= 0.1,
                clearNewsThirdFloorOfficeTransitionRect.contains(worldFocusPoint)
            else {
                return
            }

            completeTransition(
                to: .clearNewsOffice,
                destinationPoint: GameConstants.clearNewsOfficeSpawnPoint,
                heading: CGVector(dx: 0, dy: 1)
            )
        case .clearNewsOffice:
            guard
                isClearNewsOfficeDoorOpen,
                clearNewsOfficeDoorOpenElapsed >= 0.1,
                clearNewsOfficeExitTransitionRect.contains(worldFocusPoint)
            else {
                return
            }

            completeTransition(
                to: .clearNewsThirdFloor,
                destinationPoint: GameConstants.clearNewsThirdFloorOfficeExitPoint,
                heading: CGVector(dx: 0, dy: -1)
            )
        }
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

    private func pavedRoadMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.22, green: 0.21, blue: 0.2, alpha: 1.0),
            roughness: 0.94
        )
    }

    private func roadEdgeStripeMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.93, green: 0.93, blue: 0.9, alpha: 1.0),
            roughness: 0.62
        )
    }

    private func roadCenterStripeMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.92, green: 0.89, blue: 0.7, alpha: 1.0),
            roughness: 0.58
        )
    }

    private func clearNewsWallMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.2, green: 0.56, blue: 0.26, alpha: 1.0),
            roughness: 0.82
        )
    }

    private func clearNewsFloorMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.66, green: 0.69, blue: 0.63, alpha: 1.0),
            roughness: 0.92
        )
    }

    private func clearNewsDoorMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.12, green: 0.18, blue: 0.11, alpha: 1.0),
            roughness: 0.7
        )
    }

    private func clearNewsOfficeDoorMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.78, green: 0.67, blue: 0.43, alpha: 1.0),
            roughness: 0.56
        )
    }

    private func clearNewsOfficeDeskMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.46, green: 0.32, blue: 0.2, alpha: 1.0),
            roughness: 0.74
        )
    }

    private func clearNewsOfficeChairMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.16, green: 0.18, blue: 0.2, alpha: 1.0),
            roughness: 0.54
        )
    }

    private func clearNewsOfficeLampMetalMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.41, green: 0.38, blue: 0.34, alpha: 1.0),
            roughness: 0.4
        )
    }

    private func clearNewsOfficeLampShadeMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.92, green: 0.87, blue: 0.73, alpha: 1.0),
            roughness: 0.68
        )
    }

    private func clearNewsOfficeLampBulbMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 1.0, green: 0.96, blue: 0.82, alpha: 1.0),
            roughness: 0.18
        )
    }

    private func clearNewsPrinterMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.86, green: 0.87, blue: 0.84, alpha: 1.0),
            roughness: 0.42
        )
    }

    private func clearNewsPrinterTopMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.26, green: 0.29, blue: 0.31, alpha: 1.0),
            roughness: 0.36
        )
    }

    private func clearNewsPrinterPanelMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.12, green: 0.4, blue: 0.5, alpha: 1.0),
            roughness: 0.24
        )
    }

    private func clearNewsRoofMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.11, green: 0.34, blue: 0.15, alpha: 1.0),
            roughness: 0.86
        )
    }


    private func clearNewsCounterMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.58, green: 0.72, blue: 0.62, alpha: 1.0),
            roughness: 0.78
        )
    }

    private func clearNewsElevatorMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.73, green: 0.77, blue: 0.76, alpha: 1.0),
            roughness: 0.44
        )
    }

    private func clearNewsElevatorDoorMaterial() -> SCNMaterial {
        material(
            diffuse: UIColor(red: 0.62, green: 0.66, blue: 0.65, alpha: 1.0),
            roughness: 0.38
        )
    }

    private func clearNewsSignMaterial() -> SCNMaterial {
        let material = self.material(diffuse: .white, roughness: 0.72)
        material.diffuse.contents = clearNewsSignTexture()
        material.isDoubleSided = true
        return material
    }

    private func clearNewsOfficePlaqueMaterial() -> SCNMaterial {
        let material = self.material(diffuse: .white, roughness: 0.66)
        material.diffuse.contents = clearNewsOfficePlaqueTexture()
        material.isDoubleSided = true
        return material
    }

    private func addPavedRoad(
        named name: String,
        rect: CGRect,
        thickness: CGFloat,
        chamferRadius: CGFloat,
        orientation: RoadOrientation,
        elevation: CGFloat
    ) {
        let road = SCNNode(
            geometry: SCNBox(
                width: rect.width,
                height: thickness,
                length: rect.height,
                chamferRadius: chamferRadius
            )
        )
        road.name = name
        road.geometry?.firstMaterial = pavedRoadMaterial()
        road.position = position3D(
            for: CGPoint(x: rect.midX, y: rect.midY),
            elevation: elevation
        )
        worldNode.addChildNode(road)

        addRoadEdgeStripes(for: rect, orientation: orientation, elevation: elevation + 0.029)
        addRoadCenterStripes(for: rect, orientation: orientation, elevation: elevation + 0.032)
    }

    private func addRoadEdgeStripes(for rect: CGRect, orientation: RoadOrientation, elevation: CGFloat) {
        let stripeThickness: CGFloat = 0.008
        let stripeWidth: CGFloat = 0.16
        let edgeInset: CGFloat = 0.1

        for direction in [-1.0, 1.0] {
            let stripeGeometry: SCNBox
            let point: CGPoint

            switch orientation {
            case .horizontal:
                stripeGeometry = SCNBox(
                    width: rect.width * 0.94,
                    height: stripeThickness,
                    length: stripeWidth,
                    chamferRadius: 0.04
                )
                point = CGPoint(
                    x: rect.midX,
                    y: rect.midY + (CGFloat(direction) * ((rect.height / 2) - edgeInset))
                )
            case .vertical:
                stripeGeometry = SCNBox(
                    width: stripeWidth,
                    height: stripeThickness,
                    length: rect.height * 0.94,
                    chamferRadius: 0.04
                )
                point = CGPoint(
                    x: rect.midX + (CGFloat(direction) * ((rect.width / 2) - edgeInset)),
                    y: rect.midY
                )
            }

            let stripe = SCNNode(geometry: stripeGeometry)
            stripe.geometry?.firstMaterial = roadEdgeStripeMaterial()
            stripe.position = position3D(for: point, elevation: elevation)
            worldNode.addChildNode(stripe)
        }
    }

    private func addRoadCenterStripes(for rect: CGRect, orientation: RoadOrientation, elevation: CGFloat) {
        let dashLength: CGFloat = 1.95
        let dashWidth: CGFloat = 0.2
        let dashStep: CGFloat = 7.15
        let axisInset: CGFloat = 4.7

        switch orientation {
        case .horizontal:
            var x = rect.minX + axisInset
            while x <= rect.maxX - axisInset {
                let stripe = SCNNode(
                    geometry: SCNBox(
                        width: dashLength,
                        height: 0.01,
                        length: dashWidth,
                        chamferRadius: 0.05
                    )
                )
                stripe.geometry?.firstMaterial = roadCenterStripeMaterial()
                stripe.position = position3D(
                    for: CGPoint(x: x, y: rect.midY),
                    elevation: elevation
                )
                worldNode.addChildNode(stripe)
                x += dashStep
            }
        case .vertical:
            var y = rect.minY + axisInset
            while y <= rect.maxY - axisInset {
                let stripe = SCNNode(
                    geometry: SCNBox(
                        width: dashWidth,
                        height: 0.01,
                        length: dashLength,
                        chamferRadius: 0.05
                    )
                )
                stripe.geometry?.firstMaterial = roadCenterStripeMaterial()
                stripe.position = position3D(
                    for: CGPoint(x: rect.midX, y: y),
                    elevation: elevation
                )
                worldNode.addChildNode(stripe)
                y += dashStep
            }
        }
    }

    private func groundMaterial() -> SCNMaterial {
        let baseColor = UIColor(red: 0.17, green: 0.28, blue: 0.13, alpha: 1.0)
        let material = material(diffuse: baseColor, roughness: 0.98)
        let textureScale: Float = 16.0

        material.diffuse.contents = groundTexture(baseColor: baseColor)
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(textureScale, textureScale, 1)
        material.normal.contents = groundNormalTexture()
        material.normal.wrapS = .repeat
        material.normal.wrapT = .repeat
        material.normal.contentsTransform = SCNMatrix4MakeScale(textureScale, textureScale, 1)
        material.normal.intensity = 0.16
        return material
    }

    private func clearNewsSignTexture() -> UIImage {
        let size = CGSize(width: 768, height: 192)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1

        let backgroundColor = UIColor(red: 0.09, green: 0.3, blue: 0.14, alpha: 1.0)
        let borderColor = UIColor(red: 0.72, green: 0.9, blue: 0.68, alpha: 1.0)
        let textColor = UIColor(red: 0.95, green: 0.98, blue: 0.92, alpha: 1.0)
        let shadowColor = UIColor(red: 0.04, green: 0.11, blue: 0.05, alpha: 0.35)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let font = UIFont.systemFont(ofSize: 86, weight: .black)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            let bounds = CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 10)
            let path = UIBezierPath(roundedRect: bounds, cornerRadius: 24)

            context.setFillColor(backgroundColor.cgColor)
            context.addPath(path.cgPath)
            context.fillPath()

            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(10)
            context.addPath(path.cgPath)
            context.strokePath()

            let shadowOffset = CGSize(width: 0, height: 5)
            context.setShadow(offset: shadowOffset, blur: 8, color: shadowColor.cgColor)

            let textBounds = CGRect(
                x: 24,
                y: 44,
                width: size.width - 48,
                height: size.height - 88
            )
            NSString(string: "Clear News").draw(in: textBounds, withAttributes: attributes)
        }
    }

    private func clearNewsOfficePlaqueTexture() -> UIImage {
        let size = CGSize(width: 760, height: 220)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1

        let backgroundColor = UIColor(red: 0.08, green: 0.1, blue: 0.08, alpha: 1.0)
        let borderColor = UIColor(red: 0.93, green: 0.82, blue: 0.52, alpha: 1.0)
        let textColor = UIColor(red: 1.0, green: 0.98, blue: 0.9, alpha: 1.0)
        let shadowColor = UIColor(red: 0.03, green: 0.04, blue: 0.03, alpha: 0.55)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let font = UIFont.systemFont(ofSize: 110, weight: .black)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            let bounds = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 10)
            let path = UIBezierPath(roundedRect: bounds, cornerRadius: 22)

            context.setFillColor(backgroundColor.cgColor)
            context.addPath(path.cgPath)
            context.fillPath()

            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(10)
            context.addPath(path.cgPath)
            context.strokePath()

            context.setShadow(offset: CGSize(width: 0, height: 8), blur: 10, color: shadowColor.cgColor)

            let textBounds = CGRect(
                x: 32,
                y: 42,
                width: size.width - 64,
                height: size.height - 84
            )
            NSString(string: "Johnson").draw(in: textBounds, withAttributes: attributes)
        }
    }

    private func groundTexture(baseColor: UIColor) -> UIImage {
        let size = CGSize(width: 64, height: 64)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1

        let shadowColor = blendedColor(
            from: baseColor,
            to: UIColor(red: 0.10, green: 0.17, blue: 0.08, alpha: 1.0),
            progress: 0.55
        )
        let highlightColor = blendedColor(
            from: baseColor,
            to: UIColor(red: 0.28, green: 0.40, blue: 0.19, alpha: 1.0),
            progress: 0.55
        )

        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            context.setFillColor(baseColor.cgColor)
            context.fill(CGRect(origin: .zero, size: size))

            for y in stride(from: 0, to: Int(size.height), by: 2) {
                for x in stride(from: 0, to: Int(size.width), by: 2) {
                    let variation = groundNoiseValue(x: x, y: y, seed: 17)
                    let color = variation > 0.58 ? highlightColor : shadowColor
                    let alpha = 0.06 + (variation * 0.1)
                    context.setFillColor(color.withAlphaComponent(alpha).cgColor)
                    context.fill(CGRect(x: x, y: y, width: 1, height: 1))

                    if groundNoiseValue(x: x, y: y, seed: 41) > 0.93 {
                        context.fill(CGRect(x: x, y: y, width: 1, height: 2))
                    }
                }
            }
        }
    }

    private func groundNormalTexture() -> UIImage {
        let size = CGSize(width: 64, height: 64)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            let baseNormal = UIColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0)
            context.setFillColor(baseNormal.cgColor)
            context.fill(CGRect(origin: .zero, size: size))

            for y in 0..<Int(size.height) {
                for x in 0..<Int(size.width) {
                    let variation = groundNoiseValue(x: x, y: y, seed: 89)
                    let nx = 0.5 + ((groundNoiseValue(x: x, y: y, seed: 131) - 0.5) * 0.08)
                    let ny = 0.5 + ((groundNoiseValue(x: x, y: y, seed: 197) - 0.5) * 0.08)
                    let nz = 0.9 + (variation * 0.1)
                    let normalColor = UIColor(
                        red: nx,
                        green: ny,
                        blue: min(nz, 1.0),
                        alpha: 1.0
                    )
                    context.setFillColor(normalColor.cgColor)
                    context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }

    private func groundNoiseValue(x: Int, y: Int, seed: UInt32) -> CGFloat {
        var value = UInt32(truncatingIfNeeded: x) &* 73_856_093
        value ^= UInt32(truncatingIfNeeded: y) &* 19_349_663
        value ^= seed &* 83_492_791
        value = (value << 13) ^ value
        let hashed = value &* (value &* value &* 15_731 &+ 789_221) &+ 1_376_312_589
        return CGFloat(hashed & 0x7fff_ffff) / CGFloat(0x7fff_ffff)
    }
}
