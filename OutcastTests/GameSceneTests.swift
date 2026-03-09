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

    private func allNodes(in rootNode: SCNNode) -> [SCNNode] {
        [rootNode] + rootNode.childNodes.flatMap(allNodes(in:))
    }
}
