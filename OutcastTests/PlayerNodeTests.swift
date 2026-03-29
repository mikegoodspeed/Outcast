import SceneKit
import XCTest
@testable import Outcast

final class PlayerNodeTests: XCTestCase {
    func testSleepPoseFitsWithinBedAndRestsNearMattressTop() {
        let player = PlayerNode(radius: GameConstants.playerRadius)
        let layout = GameConstants.spawnHouseLayout
        let foundationHeight = GameConstants.houseWallHeight * 0.12
        let floorHeight = GameConstants.houseWallHeight * 0.06
        let frameHeight = GameConstants.houseWallHeight * 0.08
        let mattressHeight = GameConstants.houseWallHeight * 0.09

        player.position = SCNVector3(0, Float(foundationHeight + floorHeight), 0)
        player.setSleepPose(lieProgress: 1, coverProgress: 1)

        let boundingBox = player.boundingBox
        let bodyFootEdge = layout.bedSleepPoint.y - CGFloat(boundingBox.max.z)
        let bodyHeadEdge = layout.bedSleepPoint.y - CGFloat(boundingBox.min.z)
        let bodyBottom = CGFloat(player.position.y) + CGFloat(boundingBox.min.y)
        let mattressTop = foundationHeight + floorHeight + frameHeight + mattressHeight
        let visibleMargin: CGFloat = 0.34

        XCTAssertGreaterThanOrEqual(bodyFootEdge, layout.bedRect.minY + visibleMargin)
        XCTAssertLessThanOrEqual(bodyHeadEdge, layout.bedRect.maxY - visibleMargin)
        XCTAssertGreaterThanOrEqual(bodyBottom, mattressTop - 0.08)
    }
}
