import SceneKit
import UIKit

final class TreeNode: SCNNode {
    let swayAngle: CGFloat
    let swayDuration: TimeInterval

    init(size: CGFloat, isBackgroundRow: Bool, variation: CGFloat) {
        let sizeScale = 0.88 + (variation * 0.28)
        let treeSize = size * sizeScale
        swayAngle = 0.055 + max(0, (2.2 - treeSize) * 0.04) + (variation * 0.015)
        swayDuration = 2.35 + ((1 - min(treeSize / 2.2, 1)) * 0.55) + (variation * 0.45)

        super.init()

        let barkTone = 0.32 + (variation * 0.1)
        let foliageTone = 0.28 + (variation * 0.16)
        let trunkHeight = treeSize * (1.45 + (variation * 0.4))
        let trunkRadius = treeSize * (0.1 + (variation * 0.035))

        let trunkMaterial = Self.material(
            diffuse: isBackgroundRow
                ? UIColor(red: barkTone - 0.05, green: 0.22, blue: 0.14, alpha: 1.0)
                : UIColor(red: barkTone, green: 0.27, blue: 0.16, alpha: 1.0),
            roughness: 0.92
        )
        let foliageMaterial = Self.material(
            diffuse: isBackgroundRow
                ? UIColor(red: 0.15, green: foliageTone - 0.06, blue: 0.13, alpha: 1.0)
                : UIColor(red: 0.17, green: foliageTone, blue: 0.14, alpha: 1.0),
            roughness: 0.85
        )
        opacity = isBackgroundRow ? 0.82 : 1.0
        scale = SCNVector3(1, 1, 1)

        let swayPivot = SCNNode()
        swayPivot.name = "treeSwayPivot"
        addChildNode(swayPivot)

        let trunkPivot = SCNNode()
        trunkPivot.position = SCNVector3Zero
        trunkPivot.eulerAngles = SCNVector3(Float((variation - 0.5) * 0.08), 0, Float((variation - 0.5) * -0.11))
        swayPivot.addChildNode(trunkPivot)

        let trunk = SCNNode(geometry: SCNCylinder(radius: trunkRadius, height: trunkHeight))
        trunk.geometry?.firstMaterial = trunkMaterial
        trunk.position = SCNVector3(0, Float(trunkHeight / 2), 0)
        trunkPivot.addChildNode(trunk)

        let rootOffsets: [(CGFloat, CGFloat)] = [
            (treeSize * 0.12, treeSize * 0.08),
            (-treeSize * 0.1, treeSize * 0.06),
            (0, -treeSize * 0.1)
        ]
        for (x, z) in rootOffsets {
            let rootNode = SCNNode(
                geometry: SCNBox(
                    width: treeSize * 0.2,
                    height: treeSize * 0.08,
                    length: treeSize * 0.28,
                    chamferRadius: treeSize * 0.04
                )
            )
            rootNode.geometry?.firstMaterial = trunkMaterial
            rootNode.position = SCNVector3(Float(x), Float(treeSize * 0.04), Float(z))
            rootNode.eulerAngles.y = Float((x + z) * 0.3)
            addChildNode(rootNode)
        }

        let branchHeights: [CGFloat] = [0.58, 0.76]
        for (index, heightFactor) in branchHeights.enumerated() {
            let branch = SCNNode(
                geometry: SCNCone(
                    topRadius: treeSize * 0.04,
                    bottomRadius: treeSize * (0.16 + (variation * 0.03)),
                    height: treeSize * (0.55 + (CGFloat(index) * 0.08))
                )
            )
            branch.geometry?.firstMaterial = trunkMaterial
            branch.position = SCNVector3(
                Float((variation - 0.5) * treeSize * (0.35 + (CGFloat(index) * 0.08))),
                Float(trunkHeight * heightFactor),
                Float((0.12 - variation) * treeSize * 0.3)
            )
            branch.eulerAngles.z = Float((variation - 0.5) * 0.5)
            swayPivot.addChildNode(branch)
        }

        let canopyBaseHeight = trunkHeight - (treeSize * 0.18)
        let foliageOffsets: [(CGFloat, CGFloat, CGFloat)] = [
            (0, canopyBaseHeight + (treeSize * 0.76), 0),
            (treeSize * (0.28 + (variation * 0.08)), canopyBaseHeight + (treeSize * 0.56), treeSize * 0.12),
            (-treeSize * (0.25 + (variation * 0.12)), canopyBaseHeight + (treeSize * 0.52), -treeSize * 0.18),
            (treeSize * 0.08, canopyBaseHeight + (treeSize * 0.38), -treeSize * (0.24 + (variation * 0.05))),
            (-treeSize * 0.12, canopyBaseHeight + (treeSize * 0.7), treeSize * (0.19 + (variation * 0.08)))
        ]

        for (x, y, z) in foliageOffsets {
            let foliage = SCNNode(geometry: SCNSphere(radius: treeSize * (0.44 + (variation * 0.05))))
            foliage.geometry?.firstMaterial = foliageMaterial
            foliage.position = SCNVector3(Float(x), Float(y), Float(z))
            swayPivot.addChildNode(foliage)
        }

        applyBreeze(to: swayPivot, variation: variation)
        eulerAngles.y = Float((variation - 0.5) * 1.4)

        name = "tree"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func material(diffuse: UIColor, roughness: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = diffuse
        material.metalness.contents = 0.0
        material.roughness.contents = roughness
        material.lightingModel = .physicallyBased
        return material
    }

    private func applyBreeze(to swayPivot: SCNNode, variation: CGFloat) {
        let xAmount = swayAngle * (0.72 + (variation * 0.2))
        let zAmount = swayAngle * (0.92 + (variation * 0.22))
        let swayForward = SCNAction.rotateBy(
            x: CGFloat(xAmount),
            y: 0,
            z: CGFloat(-zAmount),
            duration: swayDuration
        )
        swayForward.timingMode = .easeInEaseOut

        let swayBackward = SCNAction.rotateBy(
            x: CGFloat(-xAmount * 1.1),
            y: 0,
            z: CGFloat(zAmount * 1.18),
            duration: swayDuration * 1.08
        )
        swayBackward.timingMode = .easeInEaseOut

        let settle = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: swayDuration * 0.7, usesShortestUnitArc: true)
        settle.timingMode = .easeInEaseOut

        swayPivot.runAction(
            .repeatForever(.sequence([swayForward, swayBackward, settle])),
            forKey: "treeBreeze"
        )
    }
}
