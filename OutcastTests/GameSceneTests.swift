import CoreGraphics
import SceneKit
import UIKit
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

    func testGroundUsesRepeatingTextureMaterial() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let ground = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "worldGround", recursively: true))
        let material = try XCTUnwrap(ground.geometry?.firstMaterial)

        XCTAssertTrue(material.diffuse.contents is UIImage)
        XCTAssertEqual(material.diffuse.wrapS, .repeat)
        XCTAssertEqual(material.diffuse.wrapT, .repeat)
        XCTAssertTrue(material.normal.contents is UIImage)
    }

    func testSpawningAtClearNewsLoadsTraffic3InsideBuilding() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))

        gameScene.spawn(at: .clearNews)

        let building = gameScene.scene.rootNode.childNode(withName: "clearNewsBuilding", recursively: true)
        let house = gameScene.scene.rootNode.childNode(withName: "house", recursively: true)

        XCTAssertEqual(gameScene.currentAreaIdentifier, "traffic3")
        XCTAssertNotNil(building)
        XCTAssertNil(house)
    }

    func testHomesteadAndCrossroadsRoadsSharePavedSurfaceColor() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let northRoad = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "northRoad", recursively: true))
        let northRoadColor = try XCTUnwrap(northRoad.geometry?.firstMaterial?.diffuse.contents as? UIColor)

        gameScene.completeNorthRoadTransition()

        let approachRoad = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "crossroadsApproachRoad", recursively: true))
        let mainRoad = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "crossroadsMainRoad", recursively: true))
        let approachRoadColor = try XCTUnwrap(approachRoad.geometry?.firstMaterial?.diffuse.contents as? UIColor)
        let mainRoadColor = try XCTUnwrap(mainRoad.geometry?.firstMaterial?.diffuse.contents as? UIColor)

        assertColorsEqual(northRoadColor, approachRoadColor)
        assertColorsEqual(northRoadColor, mainRoadColor)
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

        XCTAssertEqual(gameScene.currentAreaIdentifier, "traffic1")
        XCTAssertNotNil(approachRoad)
        XCTAssertNotNil(mainRoad)
        XCTAssertNil(house)
        XCTAssertGreaterThanOrEqual(cars.count, 6)
        XCTAssertGreaterThan(carVariants.count, 1)
    }

    func testCompletingWestRoadTransitionBuildsTraffic2WithoutHomeRoad() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))

        gameScene.completeNorthRoadTransition()
        gameScene.completeWestRoadTransition()

        let approachRoad = gameScene.scene.rootNode.childNode(withName: "crossroadsApproachRoad", recursively: true)
        let mainRoad = gameScene.scene.rootNode.childNode(withName: "crossroadsMainRoad", recursively: true)
        let cars = allNodes(in: gameScene.scene.rootNode).filter { $0.name == "trafficCar" }

        XCTAssertEqual(gameScene.currentAreaIdentifier, "traffic2")
        XCTAssertNil(approachRoad)
        XCTAssertNotNil(mainRoad)
        XCTAssertGreaterThanOrEqual(cars.count, 6)
    }

    func testCompletingSecondWestRoadTransitionBuildsTraffic3WithoutHomeRoad() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))

        gameScene.completeNorthRoadTransition()
        gameScene.completeWestRoadTransition()
        gameScene.completeWestRoadTransition()

        let approachRoad = gameScene.scene.rootNode.childNode(withName: "crossroadsApproachRoad", recursively: true)
        let mainRoad = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "crossroadsMainRoad", recursively: true))
        let cars = allNodes(in: gameScene.scene.rootNode).filter { $0.name == "trafficCar" }
        let mainRoadGeometry = try XCTUnwrap(mainRoad.geometry as? SCNBox)

        XCTAssertEqual(gameScene.currentAreaIdentifier, "traffic3")
        XCTAssertNil(approachRoad)
        XCTAssertNotNil(mainRoad)
        XCTAssertGreaterThanOrEqual(cars.count, 6)
        XCTAssertEqual(
            mainRoadGeometry.width,
            GameConstants.crossroadsLayout.horizontalRoadRect.width * 3,
            accuracy: 0.001
        )
    }

    func testTraffic3BuildsClearNewsShellBuilding() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))

        gameScene.completeNorthRoadTransition()
        gameScene.completeWestRoadTransition()

        XCTAssertNil(gameScene.scene.rootNode.childNode(withName: "clearNewsBuilding", recursively: true))

        gameScene.completeWestRoadTransition()

        let building = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "clearNewsBuilding", recursively: true))
        let floor = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "clearNewsFloor", recursively: true))
        let roof = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "clearNewsRoof", recursively: true))
        let sign = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "clearNewsSign", recursively: true))
        let door = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "clearNewsDoor", recursively: true))
        let counter = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "clearNewsCounter", recursively: true))
        let clerk = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "clearNewsClerk", recursively: true))
        let elevatorRoof = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "clearNewsElevatorRoof", recursively: true))
        let elevatorLeftDoor = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "clearNewsElevatorLeftDoor", recursively: true))
        let elevatorRightDoor = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "clearNewsElevatorRightDoor", recursively: true))
        let elevatorWalls = allNodes(in: building).filter { $0.name?.hasPrefix("clearNewsElevatorWall") == true }
        let walls = allNodes(in: building).filter { $0.name?.hasPrefix("clearNewsWall") == true }
        let wallColor = try XCTUnwrap(walls.first?.geometry?.firstMaterial?.diffuse.contents as? UIColor)

        XCTAssertEqual(gameScene.currentAreaIdentifier, "traffic3")
        XCTAssertEqual(walls.count, GameConstants.clearNewsBuildingLayout.wallRects.count)
        XCTAssertEqual(elevatorWalls.count, GameConstants.clearNewsElevatorLayout.wallRects.count)
        XCTAssertEqual(CGFloat(building.position.x), 0, accuracy: 0.001)
        XCTAssertEqual(CGFloat(building.position.z), 0, accuracy: 0.001)
        XCTAssertNotNil(floor.geometry as? SCNBox)
        XCTAssertNotNil(roof.geometry as? SCNBox)
        XCTAssertNotNil(sign.geometry as? SCNPlane)
        XCTAssertNotNil(door.geometry as? SCNBox)
        XCTAssertNotNil(counter.geometry as? SCNBox)
        XCTAssertNotNil(elevatorRoof.geometry as? SCNBox)
        XCTAssertNotNil(elevatorLeftDoor.geometry as? SCNBox)
        XCTAssertNotNil(elevatorRightDoor.geometry as? SCNBox)
        XCTAssertTrue(clerk is PlayerNode)
        XCTAssertEqual(CGFloat(clerk.position.x), CGFloat(counter.position.x), accuracy: 0.001)
        XCTAssertGreaterThan(CGFloat(counter.position.z), CGFloat(clerk.position.z))
        XCTAssertGreaterThan(CGFloat(counter.position.x), GameConstants.clearNewsBuildingLayout.interiorRect.minX)
        XCTAssertGreaterThan(CGFloat(elevatorLeftDoor.position.x), CGFloat(counter.position.x))
        XCTAssertLessThan(CGFloat(sign.position.y), CGFloat(roof.position.y))
        XCTAssertGreaterThan(CGFloat(sign.position.z), CGFloat(roof.position.z))
        assertColorsEqual(
            wallColor,
            UIColor(red: 0.2, green: 0.56, blue: 0.26, alpha: 1.0)
        )
    }

    func testPlayerCanEnterClearNewsAndHideRoof() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        gameScene.completeNorthRoadTransition()
        gameScene.completeWestRoadTransition()
        gameScene.completeWestRoadTransition()

        let roof = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "clearNewsRoof", recursively: true))
        let doorPivot = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "clearNewsDoorPivot", recursively: true))

        XCTAssertFalse(roof.isHidden)
        XCTAssertEqual(doorPivot.eulerAngles.y, 0, accuracy: 0.001)

        advance(gameScene, renderer: renderer, frames: 0...30, input: CGVector(dx: -1, dy: 0))
        advance(gameScene, renderer: renderer, frames: 31...62, input: CGVector(dx: 0, dy: 1))

        XCTAssertNotEqual(doorPivot.eulerAngles.y, 0, accuracy: 0.001)

        advance(gameScene, renderer: renderer, frames: 63...94, input: CGVector(dx: 0, dy: 1))

        XCTAssertTrue(roof.isHidden)
    }

    func testCrossroadsApproachRoadStopsAtTrafficRoadEdge() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let layout = GameConstants.crossroadsLayout

        gameScene.completeNorthRoadTransition()

        let approachRoad = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "crossroadsApproachRoad", recursively: true))
        let approachGeometry = try XCTUnwrap(approachRoad.geometry as? SCNBox)
        let approachMaxY = CGFloat(-approachRoad.position.z) + (approachGeometry.length / 2)

        XCTAssertEqual(approachMaxY, layout.horizontalRoadRect.minY, accuracy: 0.001)
    }

    func testParkedCarOnlyAppearsInCrossroadsAndStaysOffRoad() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let layout = GameConstants.crossroadsLayout

        XCTAssertNil(gameScene.scene.rootNode.childNode(withName: "parkedCar", recursively: true))

        gameScene.completeNorthRoadTransition()

        let parkedCar = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "parkedCar", recursively: true))
        let parkedCarRect = CGRect(
            x: CGFloat(parkedCar.position.x) - (GameConstants.parkedCarWidth / 2),
            y: CGFloat(-parkedCar.position.z) - (GameConstants.parkedCarLength / 2),
            width: GameConstants.parkedCarWidth,
            height: GameConstants.parkedCarLength
        )

        XCTAssertFalse(layout.verticalRoadRect.intersects(parkedCarRect))
        XCTAssertFalse(layout.horizontalRoadRect.intersects(parkedCarRect))
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
        XCTAssertEqual(gameScene.currentAreaIdentifier, "traffic1")
    }

    func testWestRoadExitTriggersSingleTraffic2Signal() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        gameScene.completeNorthRoadTransition()

        var callbackCount = 0
        gameScene.onWestRoadExitReached = {
            callbackCount += 1
        }

        advance(gameScene, renderer: renderer, frames: 0...36, input: CGVector(dx: 0, dy: 1))
        advance(gameScene, renderer: renderer, frames: 37...118, input: CGVector(dx: -1, dy: 0))
        advance(gameScene, renderer: renderer, frames: 119...146, input: CGVector(dx: -1, dy: 0))

        XCTAssertEqual(callbackCount, 1)
        XCTAssertEqual(gameScene.currentAreaIdentifier, "traffic1")
    }

    func testEastRoadExitTriggersSingleReturnToTraffic1Signal() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        gameScene.completeNorthRoadTransition()
        gameScene.completeWestRoadTransition()

        var callbackCount = 0
        gameScene.onEastRoadExitReached = {
            callbackCount += 1
        }

        advance(gameScene, renderer: renderer, frames: 0...80, input: CGVector(dx: 1, dy: 0))
        advance(gameScene, renderer: renderer, frames: 81...108, input: CGVector(dx: 1, dy: 0))

        XCTAssertEqual(callbackCount, 1)
        XCTAssertEqual(gameScene.currentAreaIdentifier, "traffic2")
    }

    func testWestRoadExitTriggersSingleTraffic3Signal() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        gameScene.completeNorthRoadTransition()
        gameScene.completeWestRoadTransition()

        var callbackCount = 0
        gameScene.onWestRoadExitReached = {
            callbackCount += 1
        }

        advance(gameScene, renderer: renderer, frames: 0...150, input: CGVector(dx: -1, dy: 0))
        advance(gameScene, renderer: renderer, frames: 151...190, input: CGVector(dx: -1, dy: 0))

        XCTAssertEqual(callbackCount, 1)
        XCTAssertEqual(gameScene.currentAreaIdentifier, "traffic2")
    }

    func testEastRoadExitTriggersSingleReturnToTraffic2Signal() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        gameScene.completeNorthRoadTransition()
        gameScene.completeWestRoadTransition()
        gameScene.completeWestRoadTransition()

        var callbackCount = 0
        gameScene.onEastRoadExitReached = {
            callbackCount += 1
        }

        advance(gameScene, renderer: renderer, frames: 0...80, input: CGVector(dx: 1, dy: 0))
        advance(gameScene, renderer: renderer, frames: 81...108, input: CGVector(dx: 1, dy: 0))

        XCTAssertEqual(callbackCount, 1)
        XCTAssertEqual(gameScene.currentAreaIdentifier, "traffic3")
    }

    func testTraffic2CannotTriggerHomeRoadReturnSignal() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        gameScene.completeNorthRoadTransition()
        gameScene.completeWestRoadTransition()

        var callbackCount = 0
        gameScene.onSouthRoadExitReached = {
            callbackCount += 1
        }

        advance(gameScene, renderer: renderer, frames: 0...60, input: CGVector(dx: 0, dy: -1))

        XCTAssertEqual(callbackCount, 0)
        XCTAssertEqual(gameScene.currentAreaIdentifier, "traffic2")
    }

    func testTraffic3CannotTriggerHomeRoadReturnSignal() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        gameScene.completeNorthRoadTransition()
        gameScene.completeWestRoadTransition()
        gameScene.completeWestRoadTransition()

        var callbackCount = 0
        gameScene.onSouthRoadExitReached = {
            callbackCount += 1
        }

        advance(gameScene, renderer: renderer, frames: 0...60, input: CGVector(dx: 0, dy: -1))

        XCTAssertEqual(callbackCount, 0)
        XCTAssertEqual(gameScene.currentAreaIdentifier, "traffic3")
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

    func testTrafficCarsDoNotStopWhenPlayerStandsBetweenLanes() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene
        let layout = GameConstants.crossroadsLayout

        gameScene.completeNorthRoadTransition()

        advance(gameScene, renderer: renderer, frames: 0...40, input: CGVector(dx: 0, dy: 1))
        advance(gameScene, renderer: renderer, frames: 41...180, input: .zero)

        let observedCars = allNodes(in: gameScene.scene.rootNode).filter { $0.name == "trafficCar" }
        let observedEastboundApproach = try XCTUnwrap(
            observedCars
                .filter { abs(CGFloat(-$0.position.z) - layout.trafficLaneYs[0]) < 0.001 }
                .min { abs($0.position.x) < abs($1.position.x) }
        )
        let observedWestboundApproach = try XCTUnwrap(
            observedCars
                .filter { abs(CGFloat(-$0.position.z) - layout.trafficLaneYs[1]) < 0.001 }
                .min { abs($0.position.x) < abs($1.position.x) }
        )
        let initialEastboundApproachX = CGFloat(observedEastboundApproach.position.x)
        let initialWestboundApproachX = CGFloat(observedWestboundApproach.position.x)

        advance(gameScene, renderer: renderer, frames: 181...192, input: .zero)

        let movingEastboundApproachX = CGFloat(observedEastboundApproach.position.x)
        let movingWestboundApproachX = CGFloat(observedWestboundApproach.position.x)

        XCTAssertGreaterThan(movingEastboundApproachX, initialEastboundApproachX + 0.2)
        XCTAssertLessThan(movingWestboundApproachX, initialWestboundApproachX - 0.2)
    }

    func testTrafficCarsStopWhilePlayerStandsInLane() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene
        let layout = GameConstants.crossroadsLayout

        gameScene.completeNorthRoadTransition()

        advance(gameScene, renderer: renderer, frames: 0...28, input: CGVector(dx: 0, dy: 1))
        advance(gameScene, renderer: renderer, frames: 29...180, input: .zero)

        let settledCars = allNodes(in: gameScene.scene.rootNode).filter { $0.name == "trafficCar" }
        let settledEastboundApproach = try XCTUnwrap(
            settledCars
                .filter { abs(CGFloat(-$0.position.z) - layout.trafficLaneYs[0]) < 0.001 }
                .min { abs($0.position.x) < abs($1.position.x) }
        )
        let settledWestboundApproach = try XCTUnwrap(
            settledCars
                .filter { abs(CGFloat(-$0.position.z) - layout.trafficLaneYs[1]) < 0.001 }
                .min { abs($0.position.x) < abs($1.position.x) }
        )
        let settledEastboundApproachX = CGFloat(settledEastboundApproach.position.x)
        let settledWestboundApproachX = CGFloat(settledWestboundApproach.position.x)

        advance(gameScene, renderer: renderer, frames: 181...210, input: .zero)

        let stoppedEastboundApproachX = CGFloat(settledEastboundApproach.position.x)
        let stoppedWestboundApproachX = CGFloat(settledWestboundApproach.position.x)

        XCTAssertLessThan(stoppedEastboundApproachX, 0)
        XCTAssertEqual(stoppedEastboundApproachX, settledEastboundApproachX, accuracy: 0.001)
        XCTAssertLessThan(stoppedWestboundApproachX, settledWestboundApproachX - 0.2)
    }

    func testPlayerCanEnterAndDriveParkedCarInCrossroads() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        gameScene.completeNorthRoadTransition()

        advance(gameScene, renderer: renderer, frames: 0...18, input: CGVector(dx: 1, dy: 0))

        let player = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "player", recursively: true))
        let parkedCar = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "parkedCar", recursively: true))
        let initialCarX = parkedCar.position.x

        XCTAssertTrue(gameScene.isPlayerNearParkedCarForInteraction)
        XCTAssertTrue(gameScene.beginDrivingParkedCar())
        XCTAssertTrue(gameScene.isDrivingParkedCar)
        XCTAssertTrue(player.isHidden)

        advance(gameScene, renderer: renderer, frames: 19...42, input: CGVector(dx: 1, dy: 0))

        let drivenCarX = parkedCar.position.x
        let drivenCarZ = parkedCar.position.z

        XCTAssertGreaterThan(drivenCarX, initialCarX + 0.5)
        XCTAssertEqual(parkedCar.eulerAngles.y, 0, accuracy: 0.15)
        XCTAssertTrue(gameScene.endDrivingParkedCar())
        XCTAssertFalse(gameScene.isDrivingParkedCar)
        XCTAssertFalse(player.isHidden)
        XCTAssertEqual(parkedCar.position.x, drivenCarX, accuracy: 0.001)
        XCTAssertEqual(parkedCar.position.z, drivenCarZ, accuracy: 0.001)

        let horizontalSeparation = abs(CGFloat(player.worldPosition.x - parkedCar.position.x))
        let verticalSeparation = abs(CGFloat(player.worldPosition.z - parkedCar.position.z))

        XCTAssertGreaterThan(max(horizontalSeparation, verticalSeparation), 0.9)
    }

    func testParkedCarFacesVerticalTravelDirection() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        gameScene.completeNorthRoadTransition()
        advance(gameScene, renderer: renderer, frames: 0...18, input: CGVector(dx: 1, dy: 0))
        XCTAssertTrue(gameScene.beginDrivingParkedCar())

        let parkedCar = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "parkedCar", recursively: true))

        advance(gameScene, renderer: renderer, frames: 19...36, input: CGVector(dx: 0, dy: 1))
        XCTAssertEqual(parkedCar.eulerAngles.y, .pi / 2, accuracy: 0.15)

        advance(gameScene, renderer: renderer, frames: 37...54, input: CGVector(dx: 0, dy: -1))
        XCTAssertEqual(parkedCar.eulerAngles.y, -.pi / 2, accuracy: 0.15)
    }

    func testDrivingCarTriggersSouthExitAndCarriesIntoHome() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        gameScene.completeNorthRoadTransition()
        advance(gameScene, renderer: renderer, frames: 0...18, input: CGVector(dx: 1, dy: 0))
        XCTAssertTrue(gameScene.beginDrivingParkedCar())

        var callbackCount = 0
        gameScene.onSouthRoadExitReached = {
            callbackCount += 1
        }

        advance(gameScene, renderer: renderer, frames: 19...26, input: CGVector(dx: -1, dy: 0))
        advance(gameScene, renderer: renderer, frames: 27...50, input: CGVector(dx: 0, dy: -1))

        XCTAssertEqual(callbackCount, 1)
        XCTAssertEqual(gameScene.currentAreaIdentifier, "traffic1")

        gameScene.completeSouthRoadTransition()

        let homeCar = gameScene.scene.rootNode.childNode(withName: "parkedCar", recursively: true)

        XCTAssertEqual(gameScene.currentAreaIdentifier, "home")
        XCTAssertTrue(gameScene.isDrivingParkedCar)
        XCTAssertNotNil(homeCar)
    }

    func testDrivingCarCanTravelBackToCrossroads() {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        gameScene.completeNorthRoadTransition()
        advance(gameScene, renderer: renderer, frames: 0...18, input: CGVector(dx: 1, dy: 0))
        XCTAssertTrue(gameScene.beginDrivingParkedCar())

        gameScene.completeSouthRoadTransition()
        let homeCar = gameScene.scene.rootNode.childNode(withName: "parkedCar", recursively: true)

        XCTAssertEqual(gameScene.currentAreaIdentifier, "home")
        XCTAssertTrue(gameScene.isDrivingParkedCar)
        XCTAssertNotNil(homeCar)

        gameScene.completeNorthRoadTransition()
        let crossroadsCar = gameScene.scene.rootNode.childNode(withName: "parkedCar", recursively: true)

        XCTAssertEqual(gameScene.currentAreaIdentifier, "traffic1")
        XCTAssertTrue(gameScene.isDrivingParkedCar)
        XCTAssertNotNil(crossroadsCar)
    }

    func testDrivingCarCannotEnterHouseOrOpenFrontDoor() throws {
        let gameScene = GameScene(size: CGSize(width: 1024, height: 768))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = gameScene.scene

        gameScene.completeNorthRoadTransition()
        advance(gameScene, renderer: renderer, frames: 0...18, input: CGVector(dx: 1, dy: 0))
        XCTAssertTrue(gameScene.beginDrivingParkedCar())
        gameScene.completeSouthRoadTransition()

        let frontDoorPivot = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "frontDoorPivot", recursively: true))
        let parkedCar = try XCTUnwrap(gameScene.scene.rootNode.childNode(withName: "parkedCar", recursively: true))

        advance(gameScene, renderer: renderer, frames: 0...38, input: CGVector(dx: 0, dy: -1))
        advance(gameScene, renderer: renderer, frames: 39...92, input: CGVector(dx: -1, dy: 0))
        advance(gameScene, renderer: renderer, frames: 93...160, input: CGVector(dx: 0, dy: -1))

        let parkedCarX = CGFloat(parkedCar.position.x)
        let parkedCarY = CGFloat(-parkedCar.position.z)

        XCTAssertEqual(frontDoorPivot.eulerAngles.y, 0, accuracy: 0.001)
        XCTAssertLessThan(abs(parkedCarX), GameConstants.spawnHouseLayout.outerRect.width / 2)
        XCTAssertGreaterThanOrEqual(
            parkedCarY,
            GameConstants.spawnHouseLayout.outerRect.maxY + GameConstants.parkedCarMovementRadius - 0.05
        )
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

    private func assertColorsEqual(
        _ left: UIColor,
        _ right: UIColor,
        accuracy: CGFloat = 0.001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let leftComponents = rgbaComponents(for: left)
        let rightComponents = rgbaComponents(for: right)

        XCTAssertEqual(leftComponents.red, rightComponents.red, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(leftComponents.green, rightComponents.green, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(leftComponents.blue, rightComponents.blue, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(leftComponents.alpha, rightComponents.alpha, accuracy: accuracy, file: file, line: line)
    }

    private func rgbaComponents(for color: UIColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        return (red, green, blue, alpha)
    }
}
