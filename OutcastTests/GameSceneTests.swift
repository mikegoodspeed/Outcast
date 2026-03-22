import CoreGraphics
import SceneKit
import XCTest
@testable import Outcast

@MainActor
final class GameSceneTests: XCTestCase {
    func testSceneStartsWithPlayerAtOriginAndHouseBehindSpawn() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))

        let player = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "player", recursively: true))
        let house = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "house", recursively: true))
        let ceiling = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "houseCeiling", recursively: true))
        let frontGable = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "houseFrontGable", recursively: true))
        let treeNodes = allNodes(in: gameScene.scene.rootNode).filter { $0.name == "tree" }

        XCTAssertEqual(player.worldPosition.x, 0, accuracy: 0.001)
        XCTAssertEqual(player.worldPosition.y, 0, accuracy: 0.001)
        XCTAssertEqual(player.worldPosition.z, 0, accuracy: 0.001)

        XCTAssertEqual(house.worldPosition.x, Float(GameConstants.spawnHouseCenter.x), accuracy: 0.001)
        XCTAssertEqual(house.worldPosition.z, Float(-GameConstants.spawnHouseCenter.y), accuracy: 0.001)
        XCTAssertFalse(ceiling.isHidden)
        XCTAssertFalse(frontGable.isHidden)
        XCTAssertFalse(treeNodes.isEmpty)
    }

    func testSceneBuildsTreeBarrierOnAllEdges() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let treeNodes = allNodes(in: gameScene.scene.rootNode).filter { $0.name == "tree" }

        XCTAssertTrue(treeNodes.contains { $0.worldPosition.x < -30 })
        XCTAssertTrue(treeNodes.contains { $0.worldPosition.x > 30 })
        XCTAssertTrue(treeNodes.contains { $0.worldPosition.z < -25 })
        XCTAssertTrue(treeNodes.contains { $0.worldPosition.z > 25 })
    }

    func testSceneClearsNorthRoadOpeningWithoutDroppingOuterTreeWalls() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let treePoints = allNodes(in: gameScene.scene.rootNode)
            .filter { $0.name == "tree" }
            .map { CGPoint(x: CGFloat($0.worldPosition.x), y: CGFloat(-$0.worldPosition.z)) }
        let road = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "northRoad", recursively: true))
        let ground = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "worldGround", recursively: true))
        let groundGeometry = try XCTUnwrap(ground.geometry as? SCNBox)
        let worldLayout = GameConstants.worldLayout

        XCTAssertFalse(treePoints.contains { worldLayout.roadTreeClearanceRect.contains($0) })
        XCTAssertFalse(treePoints.contains { worldLayout.roadSurfaceRect.insetBy(dx: -0.15, dy: 0).contains($0) })
        XCTAssertTrue(treePoints.contains { $0.y > worldLayout.mainPlayableRect.maxY && $0.x < worldLayout.roadCorridorRect.minX - 1.5 })
        XCTAssertTrue(treePoints.contains { $0.x > worldLayout.mainPlayableRect.maxX })
        XCTAssertEqual(CGFloat(road.worldPosition.x), worldLayout.roadSurfaceRect.midX, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(
            CGFloat(-ground.worldPosition.z) + (groundGeometry.length / 2),
            worldLayout.roadSurfaceRect.maxY - 0.001
        )
    }

    func testHouseContainsBedInTopLeftInteriorCorner() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))

        let house = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "house", recursively: true))
        let bed = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "houseBed", recursively: true))

        XCTAssertLessThan(bed.worldPosition.x, house.worldPosition.x)
        XCTAssertLessThan(bed.worldPosition.z, house.worldPosition.z)
    }

    func testRendererMovesWorldWhilePlayerStaysCentered() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        let player = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "player", recursively: true))
        let house = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "house", recursively: true))
        let initialPlayerPosition = player.worldPosition
        let initialHousePosition = house.worldPosition

        gameScene.movementInputProvider = { CGVector(dx: 1, dy: 0) }

        gameScene.renderer(renderer, updateAtTime: 0)
        gameScene.renderer(renderer, updateAtTime: 1.0 / 30.0)

        XCTAssertEqual(player.worldPosition.x, initialPlayerPosition.x, accuracy: 0.001)
        XCTAssertEqual(player.worldPosition.y, initialPlayerPosition.y, accuracy: 0.001)
        XCTAssertEqual(player.worldPosition.z, initialPlayerPosition.z, accuracy: 0.001)

        XCTAssertLessThan(house.worldPosition.x, initialHousePosition.x)
        XCTAssertEqual(house.worldPosition.z, initialHousePosition.z, accuracy: 0.001)
    }

    func testRoofHidesInsideHouseAndReturnsWhenPlayerLeaves() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        let roof = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "houseRoof", recursively: true))
        XCTAssertFalse(roof.isHidden)

        gameScene.movementInputProvider = { CGVector(dx: 0, dy: 1) }
        gameScene.renderer(renderer, updateAtTime: 0)
        for frame in 1...22 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        XCTAssertTrue(roof.isHidden)

        gameScene.movementInputProvider = { CGVector(dx: 0, dy: -1) }
        for frame in 23...44 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        XCTAssertFalse(roof.isHidden)
    }

    func testPlayerRestsOnHouseFloorInsideAndGroundOutside() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        let player = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "player", recursively: true))
        XCTAssertEqual(player.worldPosition.y, 0, accuracy: 0.001)

        gameScene.movementInputProvider = { CGVector(dx: 0, dy: 1) }
        gameScene.renderer(renderer, updateAtTime: 0)
        for frame in 1...22 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        XCTAssertGreaterThan(player.worldPosition.y, 0.65)

        gameScene.movementInputProvider = { CGVector(dx: 0, dy: -1) }
        for frame in 23...44 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        XCTAssertEqual(player.worldPosition.y, 0, accuracy: 0.001)
    }

    func testFrontDoorSwingsInsideWhenPlayerEntersHouse() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        let frontDoorPivot = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "frontDoorPivot", recursively: true))
        XCTAssertEqual(frontDoorPivot.eulerAngles.y, 0, accuracy: 0.001)

        gameScene.movementInputProvider = { CGVector(dx: 0, dy: 1) }
        gameScene.renderer(renderer, updateAtTime: 0)
        for frame in 1...15 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        XCTAssertGreaterThan(frontDoorPivot.eulerAngles.y, 1.0)
    }

    func testFrontDoorSwingsOutsideWhenPlayerExitsHouse() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        let frontDoorPivot = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "frontDoorPivot", recursively: true))

        gameScene.movementInputProvider = { CGVector(dx: 0, dy: 1) }
        gameScene.renderer(renderer, updateAtTime: 0)
        for frame in 1...22 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        gameScene.movementInputProvider = { CGVector(dx: 0, dy: -1) }
        for frame in 23...30 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        XCTAssertLessThan(frontDoorPivot.eulerAngles.y, -1.0)
    }

    func testPlayerCanInteractWhenStandingNearBed() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        XCTAssertFalse(gameScene.isPlayerNearBedForInteraction)

        gameScene.movementInputProvider = { CGVector(dx: 0, dy: 1) }
        gameScene.renderer(renderer, updateAtTime: 0)
        for frame in 1...22 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        gameScene.movementInputProvider = { CGVector(dx: -1, dy: 0) }
        for frame in 23...28 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        XCTAssertTrue(gameScene.isPlayerNearBedForInteraction)
    }

    func testBedSequenceDoesNotStartWhenPlayerIsAwayFromBed() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))

        XCTAssertFalse(gameScene.beginBedSequence())
        XCTAssertFalse(gameScene.isBedSequenceActive)
    }

    func testBedSequencePullsBlanketDownThenFinishes() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        gameScene.movementInputProvider = { CGVector(dx: 0, dy: 1) }
        gameScene.renderer(renderer, updateAtTime: 0)
        for frame in 1...22 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        gameScene.movementInputProvider = { CGVector(dx: -1, dy: 0) }
        for frame in 23...28 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        let blanket = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "houseBedBlanket", recursively: true))
        let initialBlanketZ = blanket.position.z
        let finished = expectation(description: "bed sequence finished")
        gameScene.onBedSequenceFinished = {
            finished.fulfill()
        }

        XCTAssertTrue(gameScene.beginBedSequence())
        XCTAssertTrue(gameScene.isBedSequenceActive)

        for frame in 29...63 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        XCTAssertGreaterThan(blanket.position.z, initialBlanketZ + 0.12)

        for frame in 64...130 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        wait(for: [finished], timeout: 1.0)
        XCTAssertFalse(gameScene.isBedSequenceActive)
        XCTAssertGreaterThan(blanket.position.y, Float(0.35))
    }

    func testWakeFromBedRestoresStandingPointAndResetsDaylight() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene
        let house = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "house", recursively: true))

        gameScene.movementInputProvider = { .zero }
        gameScene.renderer(renderer, updateAtTime: 0)
        for frame in 1...60 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        XCTAssertGreaterThan(gameScene.daylightCycleProgress, 0)

        gameScene.movementInputProvider = { CGVector(dx: 0, dy: 1) }
        for frame in 61...82 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        gameScene.movementInputProvider = { CGVector(dx: -1, dy: 0) }
        for frame in 83...88 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        let returnHousePosition = house.worldPosition
        XCTAssertTrue(gameScene.beginBedSequence())
        for frame in 89...190 {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }

        gameScene.wakeFromBed()

        XCTAssertEqual(gameScene.daylightCycleProgress, 0, accuracy: 0.001)
        XCTAssertEqual(house.worldPosition.x, returnHousePosition.x, accuracy: 0.001)
        XCTAssertEqual(house.worldPosition.z, returnHousePosition.z, accuracy: 0.001)
        XCTAssertFalse(gameScene.isBedSequenceActive)
    }

    func testNorthRoadExitTriggersSingleAreaTransitionSignal() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        var callbackCount = 0
        gameScene.onNorthRoadExitReached = {
            callbackCount += 1
        }

        advance(gameScene, renderer: renderer, frames: 0...72, input: CGVector(dx: 1, dy: 0))
        advance(gameScene, renderer: renderer, frames: 73...193, input: CGVector(dx: 0, dy: 1))
        advance(gameScene, renderer: renderer, frames: 194...220, input: CGVector(dx: 0, dy: 1))

        XCTAssertEqual(callbackCount, 1)
        XCTAssertEqual(gameScene.currentAreaIdentifier, "home")
    }

    func testCompletingNorthRoadTransitionBuildsCrossroadsWithTraffic() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))

        gameScene.completeNorthRoadTransition()

        let approachRoad = gameScene.scene.rootNode.childNode(withName: "crossroadsApproachRoad", recursively: true)
        let mainRoad = gameScene.scene.rootNode.childNode(withName: "crossroadsMainRoad", recursively: true)
        let house = gameScene.scene.rootNode.childNode(withName: "house", recursively: true)
        let cars = allNodes(in: gameScene.scene.rootNode).filter { $0.name == "trafficCar" }
        let carVariants = Set(cars.map(\.childNodes.count))

        XCTAssertEqual(gameScene.currentAreaIdentifier, "crossroads")
        XCTAssertNotNil(approachRoad)
        XCTAssertNotNil(mainRoad)
        XCTAssertNil(house)
        XCTAssertGreaterThanOrEqual(cars.count, 6)
        XCTAssertGreaterThan(carVariants.count, 1)
    }

    func testSouthRoadExitTriggersSingleReturnHomeSignal() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        gameScene.completeNorthRoadTransition()

        var callbackCount = 0
        gameScene.onSouthRoadExitReached = {
            callbackCount += 1
        }

        advance(gameScene, renderer: renderer, frames: 0...36, input: CGVector(dx: 0, dy: -1))
        advance(gameScene, renderer: renderer, frames: 37...60, input: CGVector(dx: 0, dy: -1))

        XCTAssertEqual(callbackCount, 1)
        XCTAssertEqual(gameScene.currentAreaIdentifier, "crossroads")
    }

    func testCompletingSouthRoadTransitionReturnsPlayerToHome() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))

        gameScene.completeNorthRoadTransition()
        gameScene.completeSouthRoadTransition()

        let house = gameScene.scene.rootNode.childNode(withName: "house", recursively: true)
        let northRoad = gameScene.scene.rootNode.childNode(withName: "northRoad", recursively: true)
        let crossroadsRoad = gameScene.scene.rootNode.childNode(withName: "crossroadsMainRoad", recursively: true)

        XCTAssertEqual(gameScene.currentAreaIdentifier, "home")
        XCTAssertNotNil(house)
        XCTAssertNotNil(northRoad)
        XCTAssertNil(crossroadsRoad)
    }

    func testCrossroadsKeepsTreesOffRoadAndCarsInsideTravelLanes() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let layout = GameConstants.crossroadsLayout

        gameScene.completeNorthRoadTransition()

        let treePoints = allNodes(in: gameScene.scene.rootNode)
            .filter { $0.name == "tree" }
            .map { CGPoint(x: CGFloat($0.position.x), y: CGFloat(-$0.position.z)) }
        let carPoints = allNodes(in: gameScene.scene.rootNode)
            .filter { $0.name == "trafficCar" }
            .map { CGPoint(x: CGFloat($0.position.x), y: CGFloat(-$0.position.z)) }
        let minimumLaneEdgeClearance = layout.trafficLaneYs
            .map { min($0 - layout.horizontalRoadRect.minY, layout.horizontalRoadRect.maxY - $0) }
            .min() ?? 0

        XCTAssertFalse(treePoints.contains { layout.horizontalRoadRect.insetBy(dx: -0.8, dy: -1.2).contains($0) })
        XCTAssertFalse(treePoints.contains { layout.verticalRoadRect.insetBy(dx: -0.7, dy: -1.0).contains($0) })
        XCTAssertGreaterThanOrEqual(minimumLaneEdgeClearance, (GameConstants.trafficCarMaxWidth / 2) + 0.25)
        XCTAssertFalse(carPoints.isEmpty)
        XCTAssertTrue(carPoints.allSatisfy { point in
            layout.trafficLaneYs.contains { abs($0 - point.y) < 0.001 }
        })
    }

    func testTrafficCarsMoveAfterCrossroadsLoads() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        gameScene.completeNorthRoadTransition()

        let initialCars = allNodes(in: gameScene.scene.rootNode).filter { $0.name == "trafficCar" }
        let initialXPositions = initialCars.map(\.worldPosition.x)

        advance(gameScene, renderer: renderer, frames: 0...45, input: .zero)

        let movedCars = allNodes(in: gameScene.scene.rootNode).filter { $0.name == "trafficCar" }
        let movedXPositions = movedCars.map(\.worldPosition.x)

        XCTAssertEqual(initialXPositions.count, movedXPositions.count)
        XCTAssertNotEqual(initialXPositions, movedXPositions)
    }

    private func allNodes(in rootNode: SCNNode) -> [SCNNode] {
        [rootNode] + rootNode.childNodes.flatMap(allNodes(in:))
    }

    private func advance(
        _ gameScene: GameScene,
        renderer: SCNRenderer,
        frames: ClosedRange<Int>,
        input: CGVector
    ) {
        gameScene.movementInputProvider = { input }
        for frame in frames {
            gameScene.renderer(renderer, updateAtTime: Double(frame) / 30.0)
        }
    }
}
