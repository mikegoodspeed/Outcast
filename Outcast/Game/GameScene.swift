import SpriteKit

final class GameScene: SKScene {
    var movementInputProvider: () -> CGVector = { .zero }

    private let playerNode = PlayerNode(radius: GameConstants.playerRadius)
    private let roomBorderNode = SKShapeNode()
    private let movementSystem = MovementSystem()

    private var roomBounds = RoomBounds(rect: .zero)
    private var lastUpdateTime: TimeInterval?

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .black
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = .black
        anchorPoint = .zero
        configureRoom()

        if playerNode.parent == nil {
            addChild(playerNode)
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        configureRoom()
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }

        guard let lastUpdateTime else {
            return
        }

        let deltaTime = min(max(currentTime - lastUpdateTime, 0), 1.0 / 30.0)
        let nextPosition = movementSystem.move(
            from: playerNode.position,
            inputVector: movementInputProvider(),
            deltaTime: deltaTime,
            speed: GameConstants.playerSpeed,
            radius: GameConstants.playerRadius,
            within: roomBounds
        )
        playerNode.position = nextPosition
    }

    private func configureRoom() {
        let horizontalInset = max(size.width * GameConstants.roomHorizontalInsetRatio, GameConstants.minimumRoomInset)
        let verticalInset = max(size.height * GameConstants.roomVerticalInsetRatio, GameConstants.minimumRoomInset)
        let roomRect = CGRect(
            x: horizontalInset,
            y: verticalInset,
            width: max(size.width - (horizontalInset * 2), GameConstants.playerRadius * 2),
            height: max(size.height - (verticalInset * 2), GameConstants.playerRadius * 2)
        )

        roomBounds = RoomBounds(rect: roomRect)
        roomBorderNode.removeFromParent()
        roomBorderNode.path = CGPath(rect: roomRect, transform: nil)
        roomBorderNode.strokeColor = UIColor(white: 1.0, alpha: 0.22)
        roomBorderNode.fillColor = UIColor(white: 1.0, alpha: 0.02)
        roomBorderNode.lineWidth = GameConstants.borderLineWidth

        if roomBorderNode.parent == nil {
            addChild(roomBorderNode)
        } else {
            roomBorderNode.removeAllActions()
        }

        if playerNode.parent == nil {
            playerNode.position = CGPoint(x: roomRect.midX, y: roomRect.midY)
        } else if playerNode.position == .zero {
            playerNode.position = CGPoint(x: roomRect.midX, y: roomRect.midY)
        } else {
            playerNode.position = roomBounds.clamped(playerNode.position, radius: GameConstants.playerRadius)
        }
    }
}

