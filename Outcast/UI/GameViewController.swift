import SceneKit
import UIKit

final class GameViewController: UIViewController {
    private let inputController = InputController()
    private let gameView = SCNView()
    private let joystickView = VirtualJoystickView()
    private let actionButton = UIButton(type: .custom)
    private let bedPromptView = UIView()
    private let bedPromptLabel = UILabel()
    private let bedPromptConfirmButton = UIButton(type: .system)
    private let bedPromptCancelButton = UIButton(type: .system)
    private let sleepFadeView = UIView()
    private lazy var gameScene = GameScene(size: view.bounds.size)
    private var isBedPromptVisible = false
    private var areControlsLocked = false

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        configureGameView()
        configureJoystick()
        configureActionButton()
        configureBedPrompt()
        configureSleepFadeView()
        configureScene()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gameScene.updateViewportSize(gameView.bounds.size)
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
        gameView.antialiasingMode = .multisampling4X
        gameView.preferredFramesPerSecond = 60
        gameView.rendersContinuously = true
        gameView.isPlaying = true
        gameView.scene = gameScene.scene
        gameView.delegate = gameScene
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

    private func configureActionButton() {
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.setTitle("X", for: .normal)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
        actionButton.backgroundColor = UIColor(white: 1.0, alpha: 0.14)
        actionButton.layer.cornerRadius = GameConstants.actionButtonSize.width / 2
        actionButton.clipsToBounds = true
        actionButton.layer.borderWidth = 1
        actionButton.layer.borderColor = UIColor(white: 1.0, alpha: 0.2).cgColor
        actionButton.accessibilityIdentifier = "actionButtonX"
        actionButton.addTarget(self, action: #selector(handleActionButtonTap), for: .touchUpInside)

        view.addSubview(actionButton)
        NSLayoutConstraint.activate([
            actionButton.widthAnchor.constraint(equalToConstant: GameConstants.actionButtonSize.width),
            actionButton.heightAnchor.constraint(equalToConstant: GameConstants.actionButtonSize.height),
            actionButton.centerXAnchor.constraint(
                equalTo: joystickView.centerXAnchor,
                constant: GameConstants.actionButtonOffset.x
            ),
            actionButton.centerYAnchor.constraint(
                equalTo: joystickView.centerYAnchor,
                constant: GameConstants.actionButtonOffset.y
            )
        ])
    }

    private func configureScene() {
        gameScene.movementInputProvider = { [weak self] in
            guard let self, !self.isBedPromptVisible, !self.areControlsLocked else {
                return .zero
            }
            return self.inputController.currentMovementVector()
        }
        gameScene.onBedSequenceFinished = { [weak self] in
            DispatchQueue.main.async {
                self?.presentSleepFade()
            }
        }
        gameScene.onNorthRoadExitReached = { [weak self] in
            DispatchQueue.main.async {
                self?.presentAreaTransitionFade {
                    self?.gameScene.completeNorthRoadTransition()
                }
            }
        }
        gameScene.onSouthRoadExitReached = { [weak self] in
            DispatchQueue.main.async {
                self?.presentAreaTransitionFade {
                    self?.gameScene.completeSouthRoadTransition()
                }
            }
        }
        gameScene.onWestRoadExitReached = { [weak self] in
            DispatchQueue.main.async {
                self?.presentAreaTransitionFade {
                    self?.gameScene.completeWestRoadTransition()
                }
            }
        }
        gameScene.onEastRoadExitReached = { [weak self] in
            DispatchQueue.main.async {
                self?.presentAreaTransitionFade {
                    self?.gameScene.completeEastRoadTransition()
                }
            }
        }
    }

    @objc
    private func handleActionButtonTap() {
        handleInteractionAction(.togglePrompt)
    }

    private func handlePresses(_ presses: Set<UIPress>, isPressed: Bool) -> Bool {
        var handled = false

        for press in presses {
            guard let key = press.key else {
                continue
            }

            if areControlsLocked {
                handled = true
                continue
            }

            if
                isPressed,
                let interactionAction = InteractionKeyAction(keyCode: key.keyCode)
            {
                handleInteractionAction(interactionAction)
                handled = true
                continue
            }

            guard let directionKey = DirectionKey(keyCode: key.keyCode) else {
                continue
            }

            if isBedPromptVisible {
                handled = true
                continue
            }

            inputController.setKey(directionKey, isPressed: isPressed)
            handled = true
        }

        return handled
    }

    private func configureSleepFadeView() {
        sleepFadeView.translatesAutoresizingMaskIntoConstraints = false
        sleepFadeView.backgroundColor = .black
        sleepFadeView.alpha = 0
        sleepFadeView.isHidden = true
        sleepFadeView.accessibilityIdentifier = "sleepFadeView"

        view.addSubview(sleepFadeView)
        NSLayoutConstraint.activate([
            sleepFadeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sleepFadeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sleepFadeView.topAnchor.constraint(equalTo: view.topAnchor),
            sleepFadeView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureBedPrompt() {
        bedPromptView.translatesAutoresizingMaskIntoConstraints = false
        bedPromptView.backgroundColor = UIColor(white: 0.18, alpha: 0.96)
        bedPromptView.layer.cornerRadius = GameConstants.interactionPromptCornerRadius
        bedPromptView.layer.borderWidth = 1
        bedPromptView.layer.borderColor = UIColor(white: 1.0, alpha: 0.08).cgColor
        bedPromptView.alpha = 0
        bedPromptView.isHidden = true
        bedPromptView.accessibilityIdentifier = "bedPrompt"

        bedPromptLabel.translatesAutoresizingMaskIntoConstraints = false
        bedPromptLabel.text = "Do you want to go to bed?"
        bedPromptLabel.textColor = .white
        bedPromptLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        bedPromptLabel.textAlignment = .center
        bedPromptLabel.numberOfLines = 2
        bedPromptLabel.accessibilityIdentifier = "bedPromptText"

        configurePromptButton(
            bedPromptConfirmButton,
            symbolName: "checkmark",
            accessibilityIdentifier: "bedPromptConfirmButton",
            action: #selector(handleBedPromptConfirmButtonTap)
        )
        configurePromptButton(
            bedPromptCancelButton,
            symbolName: "xmark",
            accessibilityIdentifier: "bedPromptCancelButton",
            action: #selector(handleBedPromptCancelButtonTap)
        )

        let contentStack = UIStackView(arrangedSubviews: [
            bedPromptConfirmButton,
            bedPromptLabel,
            bedPromptCancelButton
        ])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 16

        view.addSubview(bedPromptView)
        bedPromptView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            bedPromptView.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: GameConstants.interactionPromptHorizontalInset
            ),
            bedPromptView.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -GameConstants.interactionPromptHorizontalInset
            ),
            bedPromptView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -GameConstants.interactionPromptBottomInset
            ),
            bedPromptView.heightAnchor.constraint(
                greaterThanOrEqualToConstant: GameConstants.interactionPromptMinHeight
            ),

            contentStack.leadingAnchor.constraint(equalTo: bedPromptView.leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: bedPromptView.trailingAnchor, constant: -18),
            contentStack.topAnchor.constraint(equalTo: bedPromptView.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: bedPromptView.bottomAnchor, constant: -16),

            bedPromptConfirmButton.widthAnchor.constraint(
                equalToConstant: GameConstants.interactionPromptButtonSize
            ),
            bedPromptConfirmButton.heightAnchor.constraint(
                equalToConstant: GameConstants.interactionPromptButtonSize
            ),
            bedPromptCancelButton.widthAnchor.constraint(
                equalToConstant: GameConstants.interactionPromptButtonSize
            ),
            bedPromptCancelButton.heightAnchor.constraint(
                equalToConstant: GameConstants.interactionPromptButtonSize
            )
        ])
    }

    private func configurePromptButton(
        _ button: UIButton,
        symbolName: String,
        accessibilityIdentifier: String,
        action: Selector
    ) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .white
        button.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
        button.layer.cornerRadius = GameConstants.interactionPromptButtonSize / 2
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.18).cgColor
        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 18, weight: .bold),
            forImageIn: .normal
        )
        button.setImage(UIImage(systemName: symbolName), for: .normal)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func handleInteractionAction(_ action: InteractionKeyAction) {
        guard !areControlsLocked else {
            return
        }

        switch action {
        case .togglePrompt:
            if gameScene.isDrivingParkedCar {
                inputController.reset()
                joystickView.resetControl()
                _ = gameScene.endDrivingParkedCar()
                refreshControlState()
                return
            }

            if gameScene.isPlayerNearBedForInteraction || isBedPromptVisible {
                setBedPromptVisible(!isBedPromptVisible)
                return
            }

            guard gameScene.isPlayerNearParkedCarForInteraction else {
                return
            }
            inputController.reset()
            joystickView.resetControl()
            _ = gameScene.beginDrivingParkedCar()
            refreshControlState()
        case .confirmPrompt:
            guard isBedPromptVisible else {
                return
            }
            handleBedPromptConfirmation()
        case .cancelPrompt:
            guard isBedPromptVisible else {
                return
            }
            setBedPromptVisible(false)
        }
    }

    private func setBedPromptVisible(_ isVisible: Bool) {
        guard isBedPromptVisible != isVisible else {
            return
        }

        isBedPromptVisible = isVisible
        inputController.reset()
        joystickView.resetControl()
        refreshControlState()

        if isVisible {
            bedPromptView.isHidden = false
            bedPromptView.transform = CGAffineTransform(translationX: 0, y: 20)
            UIView.animate(withDuration: 0.18) {
                self.bedPromptView.alpha = 1
                self.bedPromptView.transform = .identity
            }
            return
        }

        UIView.animate(
            withDuration: 0.18,
            animations: {
                self.bedPromptView.alpha = 0
                self.bedPromptView.transform = CGAffineTransform(translationX: 0, y: 16)
            },
            completion: { _ in
                self.bedPromptView.isHidden = true
                self.bedPromptView.transform = .identity
            }
        )
    }

    private func handleBedPromptConfirmation() {
        setBedPromptVisible(false)
        guard gameScene.beginBedSequence() else {
            return
        }
        areControlsLocked = true
        refreshControlState()
    }

    private func refreshControlState() {
        joystickView.isUserInteractionEnabled = !isBedPromptVisible && !areControlsLocked
        actionButton.isHidden = areControlsLocked
        actionButton.alpha = isBedPromptVisible ? 0.45 : 1
    }

    private func lockControlsForTransition() {
        setBedPromptVisible(false)
        areControlsLocked = true
        inputController.reset()
        joystickView.resetControl()
        refreshControlState()
    }

    private func presentSleepFade() {
        sleepFadeView.isHidden = false
        UIView.animate(
            withDuration: GameConstants.sleepFadeDuration,
            animations: {
                self.sleepFadeView.alpha = 1
            },
            completion: { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + GameConstants.sleepBlackoutDuration) {
                    self.finishSleepTransition()
                }
            }
        )
    }

    private func finishSleepTransition() {
        gameScene.wakeFromBed()
        UIView.animate(
            withDuration: GameConstants.sleepFadeDuration,
            animations: {
                self.sleepFadeView.alpha = 0
            },
            completion: { _ in
                self.sleepFadeView.isHidden = true
                self.areControlsLocked = false
                self.refreshControlState()
                self.becomeFirstResponder()
            }
        )
    }

    private func presentAreaTransitionFade(transition: @escaping () -> Void) {
        lockControlsForTransition()
        sleepFadeView.isHidden = false
        UIView.animate(
            withDuration: GameConstants.areaTransitionFadeDuration,
            animations: {
                self.sleepFadeView.alpha = 1
            },
            completion: { _ in
                self.finishAreaTransition(transition: transition)
            }
        )
    }

    private func finishAreaTransition(transition: @escaping () -> Void) {
        transition()
        UIView.animate(
            withDuration: GameConstants.areaTransitionFadeDuration,
            animations: {
                self.sleepFadeView.alpha = 0
            },
            completion: { _ in
                self.sleepFadeView.isHidden = true
                self.areControlsLocked = false
                self.refreshControlState()
                self.becomeFirstResponder()
            }
        )
    }

    @objc
    private func handleBedPromptConfirmButtonTap() {
        handleBedPromptConfirmation()
    }

    @objc
    private func handleBedPromptCancelButtonTap() {
        setBedPromptVisible(false)
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

private enum InteractionKeyAction {
    case togglePrompt
    case confirmPrompt
    case cancelPrompt
}

private extension InteractionKeyAction {
    init?(keyCode: UIKeyboardHIDUsage) {
        switch keyCode {
        case .keyboardX:
            self = .togglePrompt
        case .keyboardReturnOrEnter:
            self = .confirmPrompt
        case .keyboardEscape:
            self = .cancelPrompt
        default:
            return nil
        }
    }
}
