import CoreGraphics
import SceneKit
import UIKit

final class PlayerNode: SCNNode {
    enum MovementState {
        case idle
        case walking
        case running
    }

    private enum AnimationKey {
        static let leftLeg = "leftLegSwing"
        static let rightLeg = "rightLegSwing"
        static let leftArm = "leftArmSwing"
        static let rightArm = "rightArmSwing"
        static let bob = "bodyBob"
    }

    private let rigNode = SCNNode()
    private let leftLegPivot = SCNNode()
    private let rightLegPivot = SCNNode()
    private let leftArmPivot = SCNNode()
    private let rightArmPivot = SCNNode()
    private var movementState: MovementState = .idle

    init(radius: CGFloat) {
        super.init()
        name = "player"
        buildModel(radius: radius)
        resetLimbPose()
    }

    func setFacing(vector: CGVector) {
        guard vector != .zero else {
            return
        }

        let yaw = atan2(Float(vector.dx), Float(-vector.dy))
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.12
        rigNode.eulerAngles.y = yaw
        SCNTransaction.commit()
    }

    func setMovementState(_ state: MovementState) {
        guard state != movementState else {
            return
        }

        movementState = state
        rigNode.removeAction(forKey: AnimationKey.bob)
        leftLegPivot.removeAction(forKey: AnimationKey.leftLeg)
        rightLegPivot.removeAction(forKey: AnimationKey.rightLeg)
        leftArmPivot.removeAction(forKey: AnimationKey.leftArm)
        rightArmPivot.removeAction(forKey: AnimationKey.rightArm)

        switch state {
        case .idle:
            resetLimbPose()
        case .walking:
            applyMovementAnimation(swingAngle: 0.45, duration: 0.42, bodyBob: 0.05)
        case .running:
            applyMovementAnimation(swingAngle: 0.78, duration: 0.24, bodyBob: 0.1)
        }
    }

    private func buildModel(radius: CGFloat) {
        let skin = Self.material(
            diffuse: UIColor(red: 0.95, green: 0.8, blue: 0.69, alpha: 1.0),
            metalness: 0.0,
            roughness: 0.88
        )
        let shirt = Self.material(
            diffuse: UIColor(red: 0.74, green: 0.34, blue: 0.23, alpha: 1.0),
            metalness: 0.0,
            roughness: 0.78
        )
        let pants = Self.material(
            diffuse: UIColor(red: 0.23, green: 0.33, blue: 0.53, alpha: 1.0),
            metalness: 0.0,
            roughness: 0.8
        )
        let shoes = Self.material(
            diffuse: UIColor(red: 0.85, green: 0.88, blue: 0.93, alpha: 1.0),
            metalness: 0.0,
            roughness: 0.6
        )
        let hair = Self.material(
            diffuse: UIColor(red: 0.18, green: 0.12, blue: 0.08, alpha: 1.0),
            metalness: 0.0,
            roughness: 0.95
        )
        let eye = Self.material(
            diffuse: UIColor(red: 0.06, green: 0.08, blue: 0.1, alpha: 1.0),
            metalness: 0.0,
            roughness: 0.35
        )
        let sclera = Self.material(
            diffuse: UIColor(red: 0.97, green: 0.98, blue: 1.0, alpha: 1.0),
            metalness: 0.0,
            roughness: 0.3
        )

        let shadow = SCNNode(geometry: SCNCylinder(radius: radius * 0.85, height: 0.02))
        shadow.geometry?.firstMaterial = Self.material(
            diffuse: UIColor(white: 0.0, alpha: 0.22),
            metalness: 0.0,
            roughness: 1.0
        )
        shadow.position = SCNVector3(0, 0.01, 0)
        addChildNode(shadow)

        addChildNode(rigNode)

        let torsoNode = SCNNode(
            geometry: SCNCapsule(capRadius: radius * 0.55, height: radius * 2.2)
        )
        torsoNode.geometry?.firstMaterial = shirt
        torsoNode.position = SCNVector3(0, Float(radius * 2.0), 0)
        rigNode.addChildNode(torsoNode)

        let hipsNode = SCNNode(
            geometry: SCNBox(
                width: radius * 1.0,
                height: radius * 0.7,
                length: radius * 0.62,
                chamferRadius: radius * 0.16
            )
        )
        hipsNode.geometry?.firstMaterial = pants
        hipsNode.position = SCNVector3(0, Float(radius * 1.15), 0)
        rigNode.addChildNode(hipsNode)

        let neckNode = SCNNode(geometry: SCNCylinder(radius: radius * 0.18, height: radius * 0.38))
        neckNode.geometry?.firstMaterial = skin
        neckNode.position = SCNVector3(0, Float(radius * 2.7), Float(radius * 0.04))
        rigNode.addChildNode(neckNode)

        let headNode = SCNNode(geometry: SCNSphere(radius: radius * 0.58))
        headNode.geometry?.firstMaterial = skin
        headNode.position = SCNVector3(0, Float(radius * 3.45), Float(radius * 0.02))
        rigNode.addChildNode(headNode)

        let hairCap = SCNNode(geometry: SCNSphere(radius: radius * 0.63))
        hairCap.geometry?.firstMaterial = hair
        hairCap.scale = SCNVector3(1.02, 0.72, 1.04)
        hairCap.position = SCNVector3(0, Float(radius * 3.7), Float(radius * 0.02))
        rigNode.addChildNode(hairCap)

        let hairBack = SCNNode(
            geometry: SCNBox(
                width: radius * 0.92,
                height: radius * 0.42,
                length: radius * 0.28,
                chamferRadius: radius * 0.08
            )
        )
        hairBack.geometry?.firstMaterial = hair
        hairBack.position = SCNVector3(0, Float(radius * 3.45), Float(radius * -0.32))
        rigNode.addChildNode(hairBack)

        let leftEyeWhite = SCNNode(geometry: SCNSphere(radius: radius * 0.155))
        leftEyeWhite.geometry?.firstMaterial = sclera
        leftEyeWhite.scale = SCNVector3(1.02, 0.86, 0.68)
        leftEyeWhite.position = SCNVector3(Float(radius * -0.2), Float(radius * 3.5), Float(radius * 0.56))
        rigNode.addChildNode(leftEyeWhite)

        let rightEyeWhite = SCNNode(geometry: SCNSphere(radius: radius * 0.155))
        rightEyeWhite.geometry?.firstMaterial = sclera
        rightEyeWhite.scale = SCNVector3(1.02, 0.86, 0.68)
        rightEyeWhite.position = SCNVector3(Float(radius * 0.2), Float(radius * 3.5), Float(radius * 0.56))
        rigNode.addChildNode(rightEyeWhite)

        let leftEye = SCNNode(geometry: SCNSphere(radius: radius * 0.072))
        leftEye.geometry?.firstMaterial = eye
        leftEye.position = SCNVector3(Float(radius * -0.2), Float(radius * 3.48), Float(radius * 0.69))
        rigNode.addChildNode(leftEye)

        let rightEye = SCNNode(geometry: SCNSphere(radius: radius * 0.072))
        rightEye.geometry?.firstMaterial = eye
        rightEye.position = SCNVector3(Float(radius * 0.2), Float(radius * 3.48), Float(radius * 0.69))
        rigNode.addChildNode(rightEye)

        let leftBrow = SCNNode(
            geometry: SCNBox(
                width: radius * 0.22,
                height: radius * 0.04,
                length: radius * 0.08,
                chamferRadius: radius * 0.02
            )
        )
        leftBrow.geometry?.firstMaterial = hair
        leftBrow.position = SCNVector3(Float(radius * -0.19), Float(radius * 3.67), Float(radius * 0.52))
        leftBrow.eulerAngles.z = 0.14
        rigNode.addChildNode(leftBrow)

        let rightBrow = SCNNode(
            geometry: SCNBox(
                width: radius * 0.22,
                height: radius * 0.04,
                length: radius * 0.08,
                chamferRadius: radius * 0.02
            )
        )
        rightBrow.geometry?.firstMaterial = hair
        rightBrow.position = SCNVector3(Float(radius * 0.19), Float(radius * 3.67), Float(radius * 0.52))
        rightBrow.eulerAngles.z = -0.14
        rigNode.addChildNode(rightBrow)

        leftArmPivot.position = SCNVector3(Float(radius * -0.74), Float(radius * 2.74), 0)
        rightArmPivot.position = SCNVector3(Float(radius * 0.74), Float(radius * 2.74), 0)
        rigNode.addChildNode(leftArmPivot)
        rigNode.addChildNode(rightArmPivot)

        let leftArm = limbNode(
            radius: radius * 0.16,
            length: radius * 1.55,
            material: skin,
            endMaterial: nil
        )
        leftArm.position = SCNVector3(0, Float(radius * -0.75), 0)
        leftArmPivot.addChildNode(leftArm)

        let rightArm = limbNode(
            radius: radius * 0.16,
            length: radius * 1.55,
            material: skin,
            endMaterial: nil
        )
        rightArm.position = SCNVector3(0, Float(radius * -0.75), 0)
        rightArmPivot.addChildNode(rightArm)

        leftLegPivot.position = SCNVector3(Float(radius * -0.28), Float(radius * 1.15), 0)
        rightLegPivot.position = SCNVector3(Float(radius * 0.28), Float(radius * 1.15), 0)
        rigNode.addChildNode(leftLegPivot)
        rigNode.addChildNode(rightLegPivot)

        let leftLeg = limbNode(
            radius: radius * 0.19,
            length: radius * 1.68,
            material: pants,
            endMaterial: shoes
        )
        leftLeg.position = SCNVector3(0, Float(radius * -0.82), 0)
        leftLegPivot.addChildNode(leftLeg)

        let rightLeg = limbNode(
            radius: radius * 0.19,
            length: radius * 1.68,
            material: pants,
            endMaterial: shoes
        )
        rightLeg.position = SCNVector3(0, Float(radius * -0.82), 0)
        rightLegPivot.addChildNode(rightLeg)

        scale = SCNVector3(1, 1, 1)
        name = "player"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func limbNode(
        radius: CGFloat,
        length: CGFloat,
        material: SCNMaterial,
        endMaterial: SCNMaterial?
    ) -> SCNNode {
        let root = SCNNode()

        let limb = SCNNode(geometry: SCNCapsule(capRadius: radius, height: length))
        limb.geometry?.firstMaterial = material
        root.addChildNode(limb)

        if let endMaterial {
            let end = SCNNode(
                geometry: SCNBox(
                    width: radius * 2.2,
                    height: radius * 0.8,
                    length: radius * 3.0,
                    chamferRadius: radius * 0.4
                )
            )
            end.geometry?.firstMaterial = endMaterial
            end.position = SCNVector3(0, Float(-(length / 2) - (radius * 0.16)), Float(-(radius * 0.36)))
            root.addChildNode(end)
        }

        return root
    }

    private func applyMovementAnimation(swingAngle: CGFloat, duration: TimeInterval, bodyBob: CGFloat) {
        leftLegPivot.runAction(
            swingAction(forward: swingAngle, backward: -swingAngle, duration: duration),
            forKey: AnimationKey.leftLeg
        )
        rightLegPivot.runAction(
            swingAction(forward: -swingAngle, backward: swingAngle, duration: duration),
            forKey: AnimationKey.rightLeg
        )
        leftArmPivot.runAction(
            swingAction(forward: -swingAngle * 0.7, backward: swingAngle * 0.7, duration: duration),
            forKey: AnimationKey.leftArm
        )
        rightArmPivot.runAction(
            swingAction(forward: swingAngle * 0.7, backward: -swingAngle * 0.7, duration: duration),
            forKey: AnimationKey.rightArm
        )
        rigNode.runAction(
            bobAction(distance: bodyBob, duration: duration),
            forKey: AnimationKey.bob
        )
    }

    private func resetLimbPose() {
        rigNode.position = SCNVector3Zero
        leftLegPivot.eulerAngles = SCNVector3Zero
        rightLegPivot.eulerAngles = SCNVector3Zero
        leftArmPivot.eulerAngles = SCNVector3(0.12, 0, 0)
        rightArmPivot.eulerAngles = SCNVector3(-0.12, 0, 0)
    }

    private func swingAction(forward: CGFloat, backward: CGFloat, duration: TimeInterval) -> SCNAction {
        let a = SCNAction.rotateTo(x: forward, y: 0, z: 0, duration: duration / 2, usesShortestUnitArc: true)
        let b = SCNAction.rotateTo(x: backward, y: 0, z: 0, duration: duration / 2, usesShortestUnitArc: true)
        a.timingMode = .easeInEaseOut
        b.timingMode = .easeInEaseOut
        return .repeatForever(.sequence([a, b]))
    }

    private func bobAction(distance: CGFloat, duration: TimeInterval) -> SCNAction {
        let up = SCNAction.move(to: SCNVector3(0, Float(distance), 0), duration: duration / 2)
        let down = SCNAction.move(to: SCNVector3Zero, duration: duration / 2)
        up.timingMode = SCNActionTimingMode.easeInEaseOut
        down.timingMode = SCNActionTimingMode.easeInEaseOut
        return .repeatForever(.sequence([up, down]))
    }

    private static func material(diffuse: UIColor, metalness: CGFloat, roughness: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = diffuse
        material.metalness.contents = metalness
        material.roughness.contents = roughness
        material.lightingModel = .physicallyBased
        return material
    }
}
