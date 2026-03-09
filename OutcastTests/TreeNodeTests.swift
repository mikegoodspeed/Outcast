import XCTest
@testable import Outcast

final class TreeNodeTests: XCTestCase {
    func testTreeStartsWithBreezeAnimation() throws {
        let tree = TreeNode(size: GameConstants.frontTreeSize, isBackgroundRow: false, variation: 0.3)
        let swayPivot = try XCTUnwrap(tree.childNode(withName: "treeSwayPivot", recursively: false))

        XCTAssertNotNil(swayPivot.action(forKey: "treeBreeze"))
    }

    func testSmallerTreesSwayMoreThanLargerTrees() {
        let largeTree = TreeNode(size: GameConstants.frontTreeSize, isBackgroundRow: false, variation: 0.2)
        let smallTree = TreeNode(size: GameConstants.backTreeSize, isBackgroundRow: true, variation: 0.2)

        XCTAssertGreaterThan(smallTree.swayAngle, largeTree.swayAngle)
    }

    func testTreesUseNoticeablyStrongerSway() {
        let tree = TreeNode(size: GameConstants.frontTreeSize, isBackgroundRow: false, variation: 0.2)

        XCTAssertGreaterThan(tree.swayAngle, 0.06)
    }
}
