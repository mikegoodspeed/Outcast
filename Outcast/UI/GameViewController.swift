import SceneKit
import UIKit

final class GameViewController: UIViewController, UITextFieldDelegate {
    private let inputController = InputController()
    private let gameView = SCNView()
    private let joystickView = VirtualJoystickView()
    private let actionButtonA = UIButton(type: .custom)
    private let actionButtonB = UIButton(type: .custom)
    private let robertDialogueView = UIView()
    private let robertDialogueTitleLabel = UILabel()
    private let robertDialogueBodyLabel = UILabel()
    private let robertNameEntryView = UIView()
    private let robertNameEntryLabel = UILabel()
    private let robertNameTextField = UITextField()
    private let robertNameDoneButton = UIButton(type: .system)
    private let elevatorControlPanelView = UIView()
    private let elevatorControlPanelTitleLabel = UILabel()
    private let elevatorFloorBLButton = UIButton(type: .system)
    private let elevatorFloor1Button = UIButton(type: .system)
    private let elevatorFloor2Button = UIButton(type: .system)
    private let elevatorFloor3Button = UIButton(type: .system)
    private let spawnPromptView = UIView()
    private let spawnPromptLabel = UILabel()
    private let spawnHomeButton = UIButton(type: .system)
    private let spawnClearNewsButton = UIButton(type: .system)
    private let bedPromptView = UIView()
    private let bedPromptLabel = UILabel()
    private let bedPromptConfirmButton = UIButton(type: .system)
    private let bedPromptCancelButton = UIButton(type: .system)
    private let sleepFadeView = UIView()
    private lazy var gameScene = GameScene(size: view.bounds.size)
    private var actionButtonBStackConstraint: NSLayoutConstraint?
    private var actionButtonBDialogueConstraint: NSLayoutConstraint?
    private var isSpawnPromptVisible = true
    private var isBedPromptVisible = false
    private var areControlsLocked = false
    private var robertConversationState: RobertConversationState = .hidden
    private var elevatorPanelState: ElevatorPanelState = .hidden

    private var isRobertDialogueVisible: Bool {
        switch robertConversationState {
        case .intro, .followUp, .final:
            return true
        case .hidden, .enteringName:
            return false
        }
    }

    private var isRobertNameEntryVisible: Bool {
        if case .enteringName = robertConversationState {
            return true
        }
        return false
    }

    private var isRobertConversationModal: Bool {
        robertConversationState != .hidden
    }

    private var isElevatorSequenceModal: Bool {
        elevatorPanelState != .hidden
    }

    private var isElevatorControlPanelVisible: Bool {
        elevatorPanelState == .panelVisible
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        configureGameView()
        configureJoystick()
        configureActionButtons()
        configureRobertDialogue()
        configureRobertNameEntry()
        configureElevatorControlPanel()
        configureSpawnPrompt()
        configureBedPrompt()
        configureSleepFadeView()
        configureScene()
        refreshControlState()
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

    private func configureActionButtons() {
        configureActionButton(
            actionButtonA,
            title: "A",
            accessibilityIdentifier: "actionButtonA",
            action: #selector(handlePrimaryActionButtonTap)
        )
        configureActionButton(
            actionButtonB,
            title: "B",
            accessibilityIdentifier: "actionButtonB",
            action: #selector(handleSecondaryActionButtonTap)
        )

        view.addSubview(actionButtonA)
        view.addSubview(actionButtonB)

        let buttonSpacing: CGFloat = 14
        let actionButtonBStackConstraint = actionButtonB.bottomAnchor.constraint(
            equalTo: actionButtonA.topAnchor,
            constant: -buttonSpacing
        )
        self.actionButtonBStackConstraint = actionButtonBStackConstraint

        NSLayoutConstraint.activate([
            actionButtonA.widthAnchor.constraint(equalToConstant: GameConstants.actionButtonSize.width),
            actionButtonA.heightAnchor.constraint(equalToConstant: GameConstants.actionButtonSize.height),
            actionButtonA.centerXAnchor.constraint(
                equalTo: joystickView.centerXAnchor,
                constant: GameConstants.actionButtonOffset.x
            ),
            actionButtonA.centerYAnchor.constraint(
                equalTo: joystickView.centerYAnchor,
                constant: GameConstants.actionButtonOffset.y
            ),
            actionButtonB.widthAnchor.constraint(equalTo: actionButtonA.widthAnchor),
            actionButtonB.heightAnchor.constraint(equalTo: actionButtonA.heightAnchor),
            actionButtonB.centerXAnchor.constraint(equalTo: actionButtonA.centerXAnchor),
            actionButtonBStackConstraint
        ])
    }

    private func configureActionButton(
        _ button: UIButton,
        title: String,
        accessibilityIdentifier: String,
        action: Selector?
    ) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
        button.backgroundColor = UIColor(white: 1.0, alpha: 0.14)
        button.layer.cornerRadius = GameConstants.actionButtonSize.width / 2
        button.clipsToBounds = true
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.2).cgColor
        button.accessibilityIdentifier = accessibilityIdentifier
        if let action {
            button.addTarget(self, action: action, for: .touchUpInside)
        }
    }

    private func configureRobertDialogue() {
        robertDialogueView.translatesAutoresizingMaskIntoConstraints = false
        robertDialogueView.backgroundColor = UIColor(white: 0.12, alpha: 0.96)
        robertDialogueView.layer.cornerRadius = GameConstants.interactionPromptCornerRadius
        robertDialogueView.layer.borderWidth = 1
        robertDialogueView.layer.borderColor = UIColor(white: 1.0, alpha: 0.08).cgColor
        robertDialogueView.alpha = 0
        robertDialogueView.isHidden = true
        robertDialogueView.accessibilityIdentifier = "robertDialogue"

        robertDialogueTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        robertDialogueTitleLabel.text = "Robert"
        robertDialogueTitleLabel.textColor = .white
        robertDialogueTitleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        robertDialogueTitleLabel.accessibilityIdentifier = "robertDialogueTitle"

        robertDialogueBodyLabel.translatesAutoresizingMaskIntoConstraints = false
        robertDialogueBodyLabel.textColor = UIColor(white: 0.96, alpha: 1.0)
        robertDialogueBodyLabel.font = .systemFont(ofSize: 18, weight: .medium)
        robertDialogueBodyLabel.numberOfLines = 0
        robertDialogueBodyLabel.accessibilityIdentifier = "robertDialogueBody"

        let contentStack = UIStackView(arrangedSubviews: [robertDialogueTitleLabel, robertDialogueBodyLabel])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 8

        view.addSubview(robertDialogueView)
        robertDialogueView.addSubview(contentStack)

        actionButtonBDialogueConstraint = actionButtonB.bottomAnchor.constraint(
            equalTo: robertDialogueView.topAnchor,
            constant: -12
        )

        NSLayoutConstraint.activate([
            robertDialogueView.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: GameConstants.interactionPromptHorizontalInset
            ),
            robertDialogueView.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -GameConstants.interactionPromptHorizontalInset
            ),
            robertDialogueView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -GameConstants.interactionPromptBottomInset
            ),
            robertDialogueView.heightAnchor.constraint(
                greaterThanOrEqualToConstant: 110
            ),

            contentStack.leadingAnchor.constraint(equalTo: robertDialogueView.leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: robertDialogueView.trailingAnchor, constant: -18),
            contentStack.topAnchor.constraint(equalTo: robertDialogueView.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: robertDialogueView.bottomAnchor, constant: -16)
        ])
    }

    private func configureRobertNameEntry() {
        robertNameEntryView.translatesAutoresizingMaskIntoConstraints = false
        robertNameEntryView.backgroundColor = UIColor(white: 0.12, alpha: 0.96)
        robertNameEntryView.layer.cornerRadius = GameConstants.interactionPromptCornerRadius
        robertNameEntryView.layer.borderWidth = 1
        robertNameEntryView.layer.borderColor = UIColor(white: 1.0, alpha: 0.08).cgColor
        robertNameEntryView.alpha = 0
        robertNameEntryView.isHidden = true
        robertNameEntryView.accessibilityIdentifier = "robertNameEntry"

        robertNameEntryLabel.translatesAutoresizingMaskIntoConstraints = false
        robertNameEntryLabel.text = "What should Robert call you?"
        robertNameEntryLabel.textColor = .white
        robertNameEntryLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        robertNameEntryLabel.numberOfLines = 2

        robertNameTextField.translatesAutoresizingMaskIntoConstraints = false
        robertNameTextField.textColor = .white
        robertNameTextField.tintColor = .white
        robertNameTextField.font = .systemFont(ofSize: 19, weight: .medium)
        robertNameTextField.placeholder = "Type your name"
        robertNameTextField.attributedPlaceholder = NSAttributedString(
            string: "Type your name",
            attributes: [.foregroundColor: UIColor(white: 1.0, alpha: 0.42)]
        )
        robertNameTextField.backgroundColor = UIColor(white: 1.0, alpha: 0.08)
        robertNameTextField.layer.cornerRadius = 12
        robertNameTextField.layer.borderWidth = 1
        robertNameTextField.layer.borderColor = UIColor(white: 1.0, alpha: 0.12).cgColor
        robertNameTextField.autocorrectionType = .no
        robertNameTextField.autocapitalizationType = .words
        robertNameTextField.clearButtonMode = .whileEditing
        robertNameTextField.returnKeyType = .done
        robertNameTextField.textContentType = .givenName
        robertNameTextField.delegate = self
        robertNameTextField.accessibilityIdentifier = "robertNameField"
        robertNameTextField.addTarget(self, action: #selector(handleRobertNameTextChanged), for: .editingChanged)
        robertNameTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        robertNameTextField.leftViewMode = .always
        robertNameTextField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 1))
        robertNameTextField.rightViewMode = .always

        configureSpawnButton(
            robertNameDoneButton,
            title: "Done",
            accessibilityIdentifier: "robertNameDoneButton",
            action: #selector(handleRobertNameDoneButtonTap)
        )

        let contentStack = UIStackView(arrangedSubviews: [
            robertNameEntryLabel,
            robertNameTextField,
            robertNameDoneButton
        ])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 14

        view.addSubview(robertNameEntryView)
        robertNameEntryView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            robertNameEntryView.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: GameConstants.interactionPromptHorizontalInset
            ),
            robertNameEntryView.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -GameConstants.interactionPromptHorizontalInset
            ),
            robertNameEntryView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -GameConstants.interactionPromptBottomInset
            ),

            contentStack.leadingAnchor.constraint(equalTo: robertNameEntryView.leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: robertNameEntryView.trailingAnchor, constant: -18),
            contentStack.topAnchor.constraint(equalTo: robertNameEntryView.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: robertNameEntryView.bottomAnchor, constant: -16),

            robertNameTextField.heightAnchor.constraint(equalToConstant: 48),
            robertNameDoneButton.heightAnchor.constraint(equalToConstant: 52)
        ])

        refreshRobertNameDoneButtonState()
    }

    private func configureElevatorControlPanel() {
        elevatorControlPanelView.translatesAutoresizingMaskIntoConstraints = false
        elevatorControlPanelView.backgroundColor = UIColor(red: 0.18, green: 0.2, blue: 0.22, alpha: 0.96)
        elevatorControlPanelView.layer.cornerRadius = 18
        elevatorControlPanelView.layer.borderWidth = 1
        elevatorControlPanelView.layer.borderColor = UIColor(white: 1.0, alpha: 0.12).cgColor
        elevatorControlPanelView.alpha = 0
        elevatorControlPanelView.isHidden = true
        elevatorControlPanelView.accessibilityIdentifier = "elevatorControlPanel"

        elevatorControlPanelTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        elevatorControlPanelTitleLabel.text = "Panel"
        elevatorControlPanelTitleLabel.textColor = UIColor(white: 0.94, alpha: 1.0)
        elevatorControlPanelTitleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        elevatorControlPanelTitleLabel.textAlignment = .center

        configureElevatorFloorButton(
            elevatorFloorBLButton,
            title: "BL",
            accessibilityIdentifier: "elevatorFloorBLButton",
            isEnabled: false
        )
        configureElevatorFloorButton(
            elevatorFloor1Button,
            title: "1",
            accessibilityIdentifier: "elevatorFloor1Button",
            isEnabled: false
        )
        configureElevatorFloorButton(
            elevatorFloor2Button,
            title: "2",
            accessibilityIdentifier: "elevatorFloor2Button",
            isEnabled: false
        )
        configureElevatorFloorButton(
            elevatorFloor3Button,
            title: "3",
            accessibilityIdentifier: "elevatorFloor3Button",
            isEnabled: true
        )

        let buttonStack = UIStackView(arrangedSubviews: [
            elevatorFloorBLButton,
            elevatorFloor1Button,
            elevatorFloor2Button,
            elevatorFloor3Button
        ])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .vertical
        buttonStack.spacing = 10

        let contentStack = UIStackView(arrangedSubviews: [elevatorControlPanelTitleLabel, buttonStack])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 12

        view.addSubview(elevatorControlPanelView)
        elevatorControlPanelView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            elevatorControlPanelView.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -16
            ),
            elevatorControlPanelView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            elevatorControlPanelView.widthAnchor.constraint(equalToConstant: 96),

            contentStack.leadingAnchor.constraint(equalTo: elevatorControlPanelView.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: elevatorControlPanelView.trailingAnchor, constant: -12),
            contentStack.topAnchor.constraint(equalTo: elevatorControlPanelView.topAnchor, constant: 14),
            contentStack.bottomAnchor.constraint(equalTo: elevatorControlPanelView.bottomAnchor, constant: -14),

            elevatorFloorBLButton.heightAnchor.constraint(equalToConstant: 44),
            elevatorFloor1Button.heightAnchor.constraint(equalTo: elevatorFloorBLButton.heightAnchor),
            elevatorFloor2Button.heightAnchor.constraint(equalTo: elevatorFloorBLButton.heightAnchor),
            elevatorFloor3Button.heightAnchor.constraint(equalTo: elevatorFloorBLButton.heightAnchor)
        ])

        refreshElevatorFloorButtonStates()
    }

    private func configureElevatorFloorButton(
        _ button: UIButton,
        title: String,
        accessibilityIdentifier: String,
        isEnabled: Bool
    ) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.12).cgColor
        button.accessibilityIdentifier = accessibilityIdentifier
        button.addTarget(self, action: #selector(handleElevatorFloorButtonTap(_:)), for: .touchUpInside)
        button.isEnabled = isEnabled
    }

    private func configureSpawnPrompt() {
        spawnPromptView.translatesAutoresizingMaskIntoConstraints = false
        spawnPromptView.backgroundColor = UIColor(white: 0.12, alpha: 0.96)
        spawnPromptView.layer.cornerRadius = 24
        spawnPromptView.layer.borderWidth = 1
        spawnPromptView.layer.borderColor = UIColor(white: 1.0, alpha: 0.08).cgColor
        spawnPromptView.accessibilityIdentifier = "spawnPrompt"

        spawnPromptLabel.translatesAutoresizingMaskIntoConstraints = false
        spawnPromptLabel.text = "Spawn where?"
        spawnPromptLabel.textColor = .white
        spawnPromptLabel.font = .systemFont(ofSize: 24, weight: .bold)
        spawnPromptLabel.textAlignment = .center
        spawnPromptLabel.accessibilityIdentifier = "spawnPromptText"

        configureSpawnButton(
            spawnHomeButton,
            title: "Home",
            accessibilityIdentifier: "spawnHomeButton",
            action: #selector(handleSpawnHomeButtonTap)
        )
        configureSpawnButton(
            spawnClearNewsButton,
            title: "Clear News",
            accessibilityIdentifier: "spawnClearNewsButton",
            action: #selector(handleSpawnClearNewsButtonTap)
        )

        let buttonStack = UIStackView(arrangedSubviews: [spawnHomeButton, spawnClearNewsButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .vertical
        buttonStack.spacing = 14

        let contentStack = UIStackView(arrangedSubviews: [spawnPromptLabel, buttonStack])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.alignment = .center

        view.addSubview(spawnPromptView)
        spawnPromptView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            spawnPromptView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spawnPromptView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            spawnPromptView.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            spawnPromptView.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),

            contentStack.leadingAnchor.constraint(equalTo: spawnPromptView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: spawnPromptView.trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(equalTo: spawnPromptView.topAnchor, constant: 24),
            contentStack.bottomAnchor.constraint(equalTo: spawnPromptView.bottomAnchor, constant: -24),

            spawnHomeButton.widthAnchor.constraint(equalToConstant: 220),
            spawnClearNewsButton.widthAnchor.constraint(equalToConstant: 220),
            spawnHomeButton.heightAnchor.constraint(equalToConstant: 52),
            spawnClearNewsButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    private func configureScene() {
        gameScene.movementInputProvider = { [weak self] in
            guard
                let self,
                !self.isSpawnPromptVisible,
                !self.isBedPromptVisible,
                !self.areControlsLocked,
                !self.isRobertConversationModal,
                !self.isElevatorSequenceModal
            else {
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
        gameScene.onClearNewsElevatorSealed = { [weak self] in
            DispatchQueue.main.async {
                self?.beginClearNewsElevatorArrivalSequence()
            }
        }
    }

    @objc
    private func handlePrimaryActionButtonTap() {
        handleInteractionAction(.primaryAction)
    }

    @objc
    private func handleSecondaryActionButtonTap() {
        handleInteractionAction(.secondaryAction)
    }

    private func handlePresses(_ presses: Set<UIPress>, isPressed: Bool) -> Bool {
        if isRobertNameEntryVisible {
            return false
        }

        if isElevatorSequenceModal {
            return true
        }

        var handled = false

        for press in presses {
            guard let key = press.key else {
                continue
            }

            if areControlsLocked {
                handled = true
                continue
            }

            if isSpawnPromptVisible {
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

            if isRobertDialogueVisible {
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

    private func handleInteractionAction(_ action: InteractionKeyAction) {
        guard !areControlsLocked, !isElevatorSequenceModal else {
            return
        }

        if isRobertDialogueVisible {
            guard action == .secondaryAction else {
                return
            }
            advanceRobertConversation()
            return
        }

        if isRobertNameEntryVisible {
            if action == .confirmPrompt {
                handleRobertNameSubmission()
            }
            return
        }

        switch action {
        case .primaryAction:
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

            if gameScene.isPlayerNearClearNewsElevatorForInteraction {
                startRobertConversation()
                return
            }

            guard gameScene.isPlayerNearParkedCarForInteraction else {
                return
            }
            inputController.reset()
            joystickView.resetControl()
            _ = gameScene.beginDrivingParkedCar()
            refreshControlState()
        case .secondaryAction:
            return
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

    private func startRobertConversation() {
        guard gameScene.beginClearNewsReceptionConversation() else {
            return
        }

        inputController.reset()
        joystickView.resetControl()
        robertConversationState = .intro
        refreshControlState()
        refreshRobertConversationPresentation(animated: true)
    }

    private func advanceRobertConversation() {
        switch robertConversationState {
        case .intro:
            robertConversationState = .followUp
        case .followUp:
            robertConversationState = .enteringName
            robertNameTextField.text = ""
            refreshRobertNameDoneButtonState()
        case .final(let name):
            gameScene.completeClearNewsReceptionConversation(named: name)
            robertConversationState = .hidden
        case .hidden, .enteringName:
            return
        }

        inputController.reset()
        joystickView.resetControl()
        refreshControlState()
        refreshRobertConversationPresentation(animated: true)

        if robertConversationState == .hidden {
            becomeFirstResponder()
        }
    }

    private func handleRobertNameSubmission() {
        guard case .enteringName = robertConversationState else {
            return
        }

        let trimmedName = (robertNameTextField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        robertConversationState = .final(trimmedName)
        refreshControlState()
        refreshRobertConversationPresentation(animated: true)
        becomeFirstResponder()
    }

    private func refreshRobertConversationPresentation(animated: Bool) {
        let dialogueText = robertDialogueText(for: robertConversationState)
        let shouldShowDialogue = dialogueText != nil
        let shouldShowNameEntry = isRobertNameEntryVisible

        if let dialogueText {
            if robertDialogueBodyLabel.text != dialogueText {
                if animated && !robertDialogueView.isHidden {
                    UIView.transition(
                        with: robertDialogueBodyLabel,
                        duration: 0.18,
                        options: [.transitionCrossDissolve, .allowUserInteraction],
                        animations: {
                            self.robertDialogueBodyLabel.text = dialogueText
                        }
                    )
                } else {
                    robertDialogueBodyLabel.text = dialogueText
                }
            }
        }

        setPromptView(robertDialogueView, visible: shouldShowDialogue, animated: animated)
        setPromptView(robertNameEntryView, visible: shouldShowNameEntry, animated: animated)

        if shouldShowNameEntry {
            DispatchQueue.main.async {
                self.robertNameTextField.becomeFirstResponder()
            }
        } else {
            robertNameTextField.resignFirstResponder()
        }
    }

    private func robertDialogueText(for state: RobertConversationState) -> String? {
        switch state {
        case .hidden, .enteringName:
            return nil
        case .intro:
            return "Where do you think you're going? Hey, I havent seen you before..."
        case .followUp:
            return "Eh, I dont have that much of a photographic memory anyways. My name is Robert. You are...?"
        case .final(let name):
            return "Nice to meet you, \(name)! I'm assuming you're here for a job interview, so go on ahead to the third floor. Mr. Johnson works up there."
        }
    }

    private func refreshRobertNameDoneButtonState() {
        let hasName = !(robertNameTextField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        robertNameDoneButton.isEnabled = hasName
        robertNameDoneButton.alpha = hasName ? 1 : 0.55
    }

    private func setPromptView(_ promptView: UIView, visible: Bool, animated: Bool) {
        guard promptView.isHidden == visible || (visible && promptView.alpha < 1) || (!visible && promptView.alpha > 0) else {
            return
        }

        if visible {
            promptView.isHidden = false
            promptView.transform = CGAffineTransform(translationX: 0, y: 16)
            let animations = {
                promptView.alpha = 1
                promptView.transform = .identity
            }
            if animated {
                UIView.animate(withDuration: 0.18, animations: animations)
            } else {
                animations()
            }
            return
        }

        let animations = {
            promptView.alpha = 0
            promptView.transform = CGAffineTransform(translationX: 0, y: 12)
        }
        let completion: (Bool) -> Void = { _ in
            promptView.isHidden = true
            promptView.transform = .identity
        }
        if animated {
            UIView.animate(withDuration: 0.18, animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
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

    private func configureSpawnButton(
        _ button: UIButton,
        title: String,
        accessibilityIdentifier: String,
        action: Selector
    ) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        button.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.14).cgColor
        button.accessibilityIdentifier = accessibilityIdentifier
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func refreshElevatorFloorButtonStates() {
        let buttons = [
            (button: elevatorFloorBLButton, isEnabled: false),
            (button: elevatorFloor1Button, isEnabled: false),
            (button: elevatorFloor2Button, isEnabled: false),
            (button: elevatorFloor3Button, isEnabled: elevatorPanelState == .panelVisible)
        ]

        for entry in buttons {
            entry.button.isEnabled = entry.isEnabled
            entry.button.alpha = entry.isEnabled ? 1 : 0.42
            entry.button.backgroundColor = entry.isEnabled
                ? UIColor(red: 0.15, green: 0.4, blue: 0.26, alpha: 0.95)
                : UIColor(white: 1.0, alpha: 0.08)
            let titleColor = entry.isEnabled ? UIColor.white : UIColor(white: 0.76, alpha: 1.0)
            entry.button.setTitleColor(titleColor, for: .normal)
            entry.button.setTitleColor(titleColor, for: .disabled)
        }
    }

    private func beginClearNewsElevatorArrivalSequence() {
        guard elevatorPanelState == .hidden else {
            return
        }

        inputController.reset()
        joystickView.resetControl()
        elevatorPanelState = .panelVisible
        refreshElevatorFloorButtonStates()
        elevatorControlPanelView.isHidden = false
        elevatorControlPanelView.alpha = 1
        view.bringSubviewToFront(elevatorControlPanelView)
        refreshControlState()
        becomeFirstResponder()
    }

    private func presentClearNewsElevatorTravelFade() {
        guard elevatorPanelState == .panelVisible else {
            return
        }

        inputController.reset()
        joystickView.resetControl()
        elevatorPanelState = .traveling
        refreshElevatorFloorButtonStates()
        refreshControlState()
        view.bringSubviewToFront(sleepFadeView)
        sleepFadeView.isHidden = false
        UIView.animate(
            withDuration: GameConstants.clearNewsElevatorFadeDuration,
            animations: {
                self.sleepFadeView.alpha = 1
            },
            completion: { _ in
                self.elevatorControlPanelView.alpha = 0
                self.elevatorControlPanelView.isHidden = true
            }
        )
    }

    private func resetElevatorSequencePresentation() {
        elevatorPanelState = .hidden
        elevatorControlPanelView.alpha = 0
        elevatorControlPanelView.isHidden = true
        refreshElevatorFloorButtonStates()
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
        joystickView.isUserInteractionEnabled = !isSpawnPromptVisible
            && !isBedPromptVisible
            && !areControlsLocked
            && !isRobertConversationModal
            && !isElevatorSequenceModal
        joystickView.alpha = (isSpawnPromptVisible || isRobertConversationModal || isElevatorSequenceModal) ? 0.35 : 1
        let areActionButtonsHidden = areControlsLocked
            || isSpawnPromptVisible
            || isRobertNameEntryVisible
            || isElevatorSequenceModal
        let shouldFloatBAboveDialogue = isRobertDialogueVisible && !areActionButtonsHidden
        actionButtonBStackConstraint?.isActive = !shouldFloatBAboveDialogue
        actionButtonBDialogueConstraint?.isActive = shouldFloatBAboveDialogue

        actionButtonA.isHidden = areActionButtonsHidden || isRobertDialogueVisible
        actionButtonB.isHidden = areActionButtonsHidden
        if isRobertDialogueVisible {
            actionButtonB.alpha = 1
            view.bringSubviewToFront(robertDialogueView)
            view.bringSubviewToFront(actionButtonB)
        } else {
            let actionButtonsAlpha: CGFloat = isBedPromptVisible ? 0.45 : 1
            actionButtonA.alpha = actionButtonsAlpha
            actionButtonB.alpha = actionButtonsAlpha
        }
        spawnPromptView.isHidden = !isSpawnPromptVisible
        if isElevatorControlPanelVisible {
            view.bringSubviewToFront(elevatorControlPanelView)
        }
        view.layoutIfNeeded()
    }

    private func lockControlsForTransition() {
        setBedPromptVisible(false)
        if isRobertConversationModal {
            robertConversationState = .hidden
            refreshRobertConversationPresentation(animated: false)
        }
        resetElevatorSequencePresentation()
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

    @objc
    private func handleRobertNameDoneButtonTap() {
        handleRobertNameSubmission()
    }

    @objc
    private func handleRobertNameTextChanged() {
        refreshRobertNameDoneButtonState()
    }

    @objc
    private func handleElevatorFloorButtonTap(_ sender: UIButton) {
        guard sender === elevatorFloor3Button else {
            return
        }

        presentClearNewsElevatorTravelFade()
    }

    @objc
    private func handleSpawnHomeButtonTap() {
        chooseSpawnLocation(.home)
    }

    @objc
    private func handleSpawnClearNewsButtonTap() {
        chooseSpawnLocation(.clearNews)
    }

    private func chooseSpawnLocation(_ location: GameScene.SpawnLocation) {
        isSpawnPromptVisible = false
        areControlsLocked = false
        robertConversationState = .hidden
        resetElevatorSequencePresentation()
        inputController.reset()
        joystickView.resetControl()
        gameScene.spawn(at: location)
        refreshControlState()
        refreshRobertConversationPresentation(animated: false)
        becomeFirstResponder()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard textField === robertNameTextField else {
            return true
        }

        handleRobertNameSubmission()
        return false
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
    case primaryAction
    case secondaryAction
    case confirmPrompt
    case cancelPrompt
}

private extension InteractionKeyAction {
    init?(keyCode: UIKeyboardHIDUsage) {
        switch keyCode {
        case .keyboardX:
            self = .primaryAction
        case .keyboardB:
            self = .secondaryAction
        case .keyboardReturnOrEnter:
            self = .confirmPrompt
        case .keyboardEscape:
            self = .cancelPrompt
        default:
            return nil
        }
    }
}

private enum RobertConversationState: Equatable {
    case hidden
    case intro
    case followUp
    case enteringName
    case final(String)
}

private enum ElevatorPanelState: Equatable {
    case hidden
    case panelVisible
    case traveling
}
