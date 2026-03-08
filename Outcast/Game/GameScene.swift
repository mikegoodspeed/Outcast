import CoreGraphics
import SceneKit
import UIKit

final class GameScene: NSObject, SCNSceneRendererDelegate {
    var movementInputProvider: () -> CGVector = { .zero }
    let scene = SCNScene()

    private let playerNode = PlayerNode(radius: GameConstants.playerRadius)
    private let worldNode = SCNNode()
    private let movementSystem = MovementSystem()
    private let cameraNode = SCNNode()
    private let focusTargetNode = SCNNode()

    private var worldFocusPoint = CGPoint.zero
    private var roomBounds = RoomBounds(rect: .zero)
    private var lastUpdateTime: TimeInterval?
    private var viewportSize: CGSize

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

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }

        guard let lastUpdateTime else {
            return
        }

        let deltaTime = min(max(currentTime - lastUpdateTime, 0), 1.0 / 30.0)
        let movementVector = movementInputProvider().clampedToUnit
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
        worldFocusPoint = movementSystem.move(
            from: worldFocusPoint,
            inputVector: movementVector,
            deltaTime: deltaTime,
            speed: travelSpeed,
            radius: GameConstants.playerRadius,
            within: roomBounds
        )

        playerNode.setMovementState(animationState)
        playerNode.setFacing(vector: movementVector)
        updateWorldOffset()
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
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(red: 0.28, green: 0.34, blue: 0.45, alpha: 1.0)
        scene.rootNode.addChildNode(ambient)

        let moonlight = SCNNode()
        moonlight.light = SCNLight()
        moonlight.light?.type = .directional
        moonlight.light?.color = UIColor(red: 0.74, green: 0.83, blue: 0.96, alpha: 1.0)
        moonlight.light?.castsShadow = true
        moonlight.light?.shadowRadius = 6
        moonlight.light?.shadowSampleCount = 24
        moonlight.light?.shadowMode = .deferred
        moonlight.eulerAngles = SCNVector3(-0.9, 0.75, 0)
        scene.rootNode.addChildNode(moonlight)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .omni
        fill.light?.color = UIColor(red: 0.3, green: 0.36, blue: 0.45, alpha: 1.0)
        fill.position = SCNVector3(0, 7, 5)
        scene.rootNode.addChildNode(fill)
    }

    private func configureWorld() {
        let worldRect = CGRect(
            x: -(GameConstants.worldWidth / 2),
            y: -(GameConstants.worldHeight / 2),
            width: GameConstants.worldWidth,
            height: GameConstants.worldHeight
        )
        let barrierInset = GameConstants.roomInteriorMargin + GameConstants.treeBarrierDepth
        let playableRect = CGRect(
            x: worldRect.minX + barrierInset,
            y: worldRect.minY + barrierInset,
            width: worldRect.width - (barrierInset * 2),
            height: worldRect.height - (barrierInset * 2)
        )

        roomBounds = RoomBounds(rect: playableRect)
        worldNode.childNodes.forEach { $0.removeFromParentNode() }

        addGround(in: worldRect)
        addFloorDetails(in: playableRect)
        addTreeBands(in: worldRect)

        if worldFocusPoint == .zero {
            worldFocusPoint = CGPoint(x: playableRect.midX, y: playableRect.midY)
        } else {
            worldFocusPoint = roomBounds.clamped(worldFocusPoint, radius: GameConstants.playerRadius)
        }

        updateWorldOffset()
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
        ground.geometry?.firstMaterial = material(
            diffuse: UIColor(red: 0.09, green: 0.12, blue: 0.14, alpha: 1.0),
            roughness: 0.96
        )
        ground.geometry?.firstMaterial?.normal.contents = UIColor(red: 0.12, green: 0.14, blue: 0.15, alpha: 1.0)
        ground.position = SCNVector3(0, Float(-GameConstants.groundThickness / 2), 0)
        ground.castsShadow = false
        worldNode.addChildNode(ground)
    }

    private func addTreeBands(in worldRect: CGRect) {
        addHorizontalTreeBand(
            startX: worldRect.minX + (GameConstants.treeSpacing / 2),
            endX: worldRect.maxX - (GameConstants.treeSpacing / 2),
            frontY: roomBounds.rect.maxY + (GameConstants.frontTreeSize * 0.3),
            depthDirection: 1,
            variationOffset: 0
        )
        addHorizontalTreeBand(
            startX: worldRect.minX + (GameConstants.treeSpacing / 2),
            endX: worldRect.maxX - (GameConstants.treeSpacing / 2),
            frontY: roomBounds.rect.minY - (GameConstants.frontTreeSize * 0.3),
            depthDirection: -1,
            variationOffset: 1_000
        )
        addVerticalTreeBand(
            startY: worldRect.minY + (GameConstants.treeSpacing / 2),
            endY: worldRect.maxY - (GameConstants.treeSpacing / 2),
            frontX: roomBounds.rect.minX - (GameConstants.frontTreeSize * 0.3),
            depthDirection: -1,
            variationOffset: 2_000
        )
        addVerticalTreeBand(
            startY: worldRect.minY + (GameConstants.treeSpacing / 2),
            endY: worldRect.maxY - (GameConstants.treeSpacing / 2),
            frontX: roomBounds.rect.maxX + (GameConstants.frontTreeSize * 0.3),
            depthDirection: 1,
            variationOffset: 3_000
        )
    }

    private func addHorizontalTreeBand(
        startX: CGFloat,
        endX: CGFloat,
        frontY: CGFloat,
        depthDirection: CGFloat,
        variationOffset: Int
    ) {
        let midRowY = frontY + (GameConstants.treeRowOffset * depthDirection)
        let backRowY = midRowY + ((GameConstants.treeRowOffset * 0.9) * depthDirection)
        let farRowY = backRowY + ((GameConstants.treeRowOffset * 0.85) * depthDirection)
        let deepestRowY = farRowY + ((GameConstants.treeRowOffset * 0.8) * depthDirection)

        var x = startX
        var treeIndex = 0
        while x <= endX {
            let index = treeIndex + variationOffset
            let frontTree = TreeNode(
                size: GameConstants.frontTreeSize,
                isBackgroundRow: false,
                variation: variation(for: index, salt: 11)
            )
            frontTree.position = position3D(for: CGPoint(x: x, y: frontY))
            worldNode.addChildNode(frontTree)

            let middleTree = TreeNode(
                size: GameConstants.backTreeSize,
                isBackgroundRow: true,
                variation: variation(for: index, salt: 29)
            )
            middleTree.position = position3D(
                for: CGPoint(
                    x: x + (GameConstants.treeSpacing * (0.36 + (variation(for: index, salt: 7) * 0.22))),
                    y: midRowY
                )
            )
            worldNode.addChildNode(middleTree)

            let backTree = TreeNode(
                size: GameConstants.backTreeSize * 0.96,
                isBackgroundRow: true,
                variation: variation(for: index, salt: 53)
            )
            backTree.position = position3D(
                for: CGPoint(
                    x: x - (GameConstants.treeSpacing * (0.14 + (variation(for: index, salt: 17) * 0.24))),
                    y: backRowY
                )
            )
            worldNode.addChildNode(backTree)

            let farTree = TreeNode(
                size: GameConstants.backTreeSize * 0.9,
                isBackgroundRow: true,
                variation: variation(for: index, salt: 71)
            )
            farTree.position = position3D(
                for: CGPoint(
                    x: x + (GameConstants.treeSpacing * (0.18 + (variation(for: index, salt: 41) * 0.28))),
                    y: farRowY
                )
            )
            worldNode.addChildNode(farTree)

            let deepestTree = TreeNode(
                size: GameConstants.backTreeSize * 0.84,
                isBackgroundRow: true,
                variation: variation(for: index, salt: 89)
            )
            deepestTree.position = position3D(
                for: CGPoint(
                    x: x - (GameConstants.treeSpacing * (0.1 + (variation(for: index, salt: 61) * 0.3))),
                    y: deepestRowY
                )
            )
            worldNode.addChildNode(deepestTree)

            treeIndex += 1
            x += GameConstants.treeSpacing
        }
    }

    private func addVerticalTreeBand(
        startY: CGFloat,
        endY: CGFloat,
        frontX: CGFloat,
        depthDirection: CGFloat,
        variationOffset: Int
    ) {
        let midRowX = frontX + (GameConstants.treeRowOffset * depthDirection)
        let backRowX = midRowX + ((GameConstants.treeRowOffset * 0.9) * depthDirection)
        let farRowX = backRowX + ((GameConstants.treeRowOffset * 0.85) * depthDirection)
        let deepestRowX = farRowX + ((GameConstants.treeRowOffset * 0.8) * depthDirection)

        var y = startY
        var treeIndex = 0
        while y <= endY {
            let index = treeIndex + variationOffset
            let frontTree = TreeNode(
                size: GameConstants.frontTreeSize,
                isBackgroundRow: false,
                variation: variation(for: index, salt: 101)
            )
            frontTree.position = position3D(for: CGPoint(x: frontX, y: y))
            worldNode.addChildNode(frontTree)

            let middleTree = TreeNode(
                size: GameConstants.backTreeSize,
                isBackgroundRow: true,
                variation: variation(for: index, salt: 131)
            )
            middleTree.position = position3D(
                for: CGPoint(
                    x: midRowX,
                    y: y + (GameConstants.treeSpacing * (0.34 + (variation(for: index, salt: 107) * 0.22)))
                )
            )
            worldNode.addChildNode(middleTree)

            let backTree = TreeNode(
                size: GameConstants.backTreeSize * 0.96,
                isBackgroundRow: true,
                variation: variation(for: index, salt: 157)
            )
            backTree.position = position3D(
                for: CGPoint(
                    x: backRowX,
                    y: y - (GameConstants.treeSpacing * (0.16 + (variation(for: index, salt: 117) * 0.24)))
                )
            )
            worldNode.addChildNode(backTree)

            let farTree = TreeNode(
                size: GameConstants.backTreeSize * 0.9,
                isBackgroundRow: true,
                variation: variation(for: index, salt: 179)
            )
            farTree.position = position3D(
                for: CGPoint(
                    x: farRowX,
                    y: y + (GameConstants.treeSpacing * (0.2 + (variation(for: index, salt: 141) * 0.26)))
                )
            )
            worldNode.addChildNode(farTree)

            let deepestTree = TreeNode(
                size: GameConstants.backTreeSize * 0.84,
                isBackgroundRow: true,
                variation: variation(for: index, salt: 199)
            )
            deepestTree.position = position3D(
                for: CGPoint(
                    x: deepestRowX,
                    y: y - (GameConstants.treeSpacing * (0.1 + (variation(for: index, salt: 161) * 0.28)))
                )
            )
            worldNode.addChildNode(deepestTree)

            treeIndex += 1
            y += GameConstants.treeSpacing
        }
    }

    private func addFloorDetails(in playableRect: CGRect) {
        for index in 0..<24 {
            let xRatio = 0.08 + (variation(for: index, salt: 3) * 0.84)
            let yRatio = 0.08 + (variation(for: index, salt: 5) * 0.84)
            let radius = 0.5 + (variation(for: index, salt: 13) * 1.4)
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
            patch.position = position3D(
                for: CGPoint(
                    x: playableRect.minX + (playableRect.width * xRatio),
                    y: playableRect.minY + (playableRect.height * yRatio)
                ),
                elevation: 0.02
            )
            worldNode.addChildNode(patch)
        }
    }

    private func updateWorldOffset() {
        worldNode.position = SCNVector3(
            Float(-worldFocusPoint.x),
            0,
            Float(worldFocusPoint.y)
        )
        focusTargetNode.position = SCNVector3(0, 2.15, 0)
    }

    private func position3D(for point: CGPoint, elevation: CGFloat = 0) -> SCNVector3 {
        SCNVector3(Float(point.x), Float(elevation), Float(-point.y))
    }

    private func variation(for index: Int, salt: Int) -> CGFloat {
        let value = sin(Double((index + 1) * 37 + (salt * 19))) * 43758.5453
        return CGFloat(value - floor(value))
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
