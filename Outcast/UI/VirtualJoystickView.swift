import UIKit

final class VirtualJoystickView: UIView {
    var onVectorChanged: ((CGVector) -> Void)?

    private let baseView = UIView()
    private let knobView = UIView()
    private var activeTouch: UITouch?
    private var currentVector: CGVector = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        accessibilityIdentifier = "virtualJoystick"
        isAccessibilityElement = true

        baseView.backgroundColor = UIColor(white: 1.0, alpha: 0.08)
        baseView.isUserInteractionEnabled = false
        addSubview(baseView)

        knobView.backgroundColor = UIColor(white: 1.0, alpha: 0.32)
        knobView.isUserInteractionEnabled = false
        addSubview(knobView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        GameConstants.joystickSize
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        baseView.frame = bounds
        baseView.layer.cornerRadius = bounds.width / 2

        let knobDiameter = bounds.width * 0.42
        knobView.bounds = CGRect(x: 0, y: 0, width: knobDiameter, height: knobDiameter)
        knobView.layer.cornerRadius = knobDiameter / 2

        updateKnobPosition(for: currentVector)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first else {
            return
        }

        activeTouch = touch
        updateVector(with: touch)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else {
            return
        }

        updateVector(with: activeTouch)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else {
            return
        }

        reset()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else {
            return
        }

        reset()
    }

    func resetControl() {
        reset()
    }

    private func updateVector(with touch: UITouch) {
        let location = touch.location(in: self)
        let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        let dx = location.x - centerPoint.x
        let dy = centerPoint.y - location.y

        let maxDistance = max((bounds.width / 2) - (knobView.bounds.width / 2) - 8, 1)
        let rawVector = CGVector(dx: dx / maxDistance, dy: dy / maxDistance).clampedToUnit
        currentVector = rawVector
        updateKnobPosition(for: rawVector)
        onVectorChanged?(rawVector)
    }

    private func updateKnobPosition(for vector: CGVector) {
        let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        let maxDistance = max((bounds.width / 2) - (knobView.bounds.width / 2) - 8, 1)
        knobView.center = CGPoint(
            x: centerPoint.x + (vector.dx * maxDistance),
            y: centerPoint.y - (vector.dy * maxDistance)
        )
    }

    private func reset() {
        activeTouch = nil
        currentVector = .zero
        updateKnobPosition(for: .zero)
        onVectorChanged?(.zero)
    }
}
