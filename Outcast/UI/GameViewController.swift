import SpriteKit
import UIKit

final class GameViewController: UIViewController {
    private let inputController = InputController()
    private let gameView = SKView()
    private let joystickView = VirtualJoystickView()
    private lazy var gameScene = GameScene(size: view.bounds.size)

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        configureGameView()
        configureJoystick()
        configureScene()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if gameScene.size != gameView.bounds.size {
            gameScene.size = gameView.bounds.size
        }
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let handled = handlePresses(presses, isPressed: true)
        if !handled {
            super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let handled = handlePresses(presses, isPressed: false)
        if !handled {
            super.pressesEnded(presses, with: event)
        }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let handled = handlePresses(presses, isPressed: false)
        if !handled {
            super.pressesCancelled(presses, with: event)
        }
    }

    private func configureGameView() {
        gameView.translatesAutoresizingMaskIntoConstraints = false
        gameView.backgroundColor = .black
        gameView.ignoresSiblingOrder = true
        gameView.accessibilityIdentifier = "gameView"
        gameView.isAccessibilityElement = true

        view.addSubview(gameView)
        NSLayoutConstraint.activate([
            gameView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gameView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gameView.topAnchor.constraint(equalTo: view.topAnchor),
            gameView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureJoystick() {
        joystickView.translatesAutoresizingMaskIntoConstraints = false
        joystickView.onVectorChanged = { [weak self] vector in
            self?.inputController.setJoystickVector(vector)
        }

        view.addSubview(joystickView)
        NSLayoutConstraint.activate([
            joystickView.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: GameConstants.joystickMargin
            ),
            joystickView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -GameConstants.joystickMargin
            ),
            joystickView.widthAnchor.constraint(equalToConstant: GameConstants.joystickSize.width),
            joystickView.heightAnchor.constraint(equalToConstant: GameConstants.joystickSize.height)
        ])
    }

    private func configureScene() {
        gameScene.movementInputProvider = { [weak self] in
            self?.inputController.currentMovementVector() ?? .zero
        }
        gameView.presentScene(gameScene)
    }

    private func handlePresses(_ presses: Set<UIPress>, isPressed: Bool) -> Bool {
        var handled = false

        for press in presses {
            guard
                let key = press.key,
                let directionKey = DirectionKey(keyCode: key.keyCode)
            else {
                continue
            }

            inputController.setKey(directionKey, isPressed: isPressed)
            handled = true
        }

        return handled
    }
}

private extension DirectionKey {
    init?(keyCode: UIKeyboardHIDUsage) {
        switch keyCode {
        case .keyboardUpArrow, .keyboardW:
            self = .up
        case .keyboardDownArrow, .keyboardS:
            self = .down
        case .keyboardLeftArrow, .keyboardA:
            self = .left
        case .keyboardRightArrow, .keyboardD:
            self = .right
        default:
            return nil
        }
    }
}

