import CoreGraphics

enum GameConstants {
    static let playerRadius: CGFloat = 0.48
    static let walkInputThreshold: CGFloat = 0.7
    static let walkSpeed: CGFloat = 5.2
    static let runSpeed: CGFloat = 9.0
    static let worldWidth: CGFloat = 91.2
    static let worldHeight: CGFloat = 76.8
    static let roomInteriorMargin: CGFloat = 4.2
    static let roomCornerRadius: CGFloat = 0.6
    static let treeBarrierDepth: CGFloat = 14
    static let frontTreeSize: CGFloat = 1.8
    static let backTreeSize: CGFloat = 1.55
    static let treeSpacing: CGFloat = 2.04
    static let treeRowOffset: CGFloat = 1.92
    static let houseWidth: CGFloat = 6.8
    static let houseDepth: CGFloat = 5.6
    static let houseWallHeight: CGFloat = 3.9
    static let houseDoorY: CGFloat = 4.4
    static let houseExteriorWallThickness: CGFloat = 0.34
    static let houseFrontDoorWidth: CGFloat = 2.1
    static let doorInteractionReach: CGFloat = 0.9
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
}
