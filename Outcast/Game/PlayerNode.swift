import SpriteKit

final class PlayerNode: SKNode {
    init(radius: CGFloat) {
        super.init()

        let body = SKShapeNode(ellipseOf: CGSize(width: radius * 1.3, height: radius * 1.8))
        body.fillColor = UIColor(white: 0.92, alpha: 1.0)
        body.strokeColor = UIColor(white: 0.2, alpha: 0.15)
        body.lineWidth = 1
        body.position = CGPoint(x: 0, y: -(radius * 0.2))
        addChild(body)

        let head = SKShapeNode(circleOfRadius: radius * 0.45)
        head.fillColor = UIColor(white: 0.98, alpha: 1.0)
        head.strokeColor = UIColor.clear
        head.position = CGPoint(x: 0, y: radius * 0.9)
        addChild(head)

        let feet = SKShapeNode(ellipseOf: CGSize(width: radius, height: radius * 0.45))
        feet.fillColor = UIColor(white: 0.82, alpha: 0.9)
        feet.strokeColor = UIColor.clear
        feet.position = CGPoint(x: 0, y: -(radius * 1.1))
        addChild(feet)

        zPosition = 10
        name = "player"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

