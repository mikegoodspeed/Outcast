import SceneKit
import UIKit

final class HouseNode: SCNNode {
    init(width: CGFloat, depth: CGFloat, wallHeight: CGFloat) {
        super.init()

        let foundationHeight = wallHeight * 0.12
        let wallThickness = width * 0.06
        let roofHeight = wallHeight * 0.75
        let roofThickness = wallHeight * 0.08
        let doorWidth = width * 0.22
        let doorHeight = wallHeight * 0.64
        let porchDepth = depth * 0.2

        let timberMaterial = Self.material(
            diffuse: UIColor(red: 0.52, green: 0.34, blue: 0.2, alpha: 1.0),
            roughness: 0.88
        )
        let trimMaterial = Self.material(
            diffuse: UIColor(red: 0.34, green: 0.2, blue: 0.11, alpha: 1.0),
            roughness: 0.92
        )
        let roofMaterial = Self.material(
            diffuse: UIColor(red: 0.26, green: 0.18, blue: 0.14, alpha: 1.0),
            roughness: 0.84
        )
        let doorMaterial = Self.material(
            diffuse: UIColor(red: 0.23, green: 0.14, blue: 0.08, alpha: 1.0),
            roughness: 0.9
        )
        let windowMaterial = Self.material(
            diffuse: UIColor(red: 0.84, green: 0.91, blue: 0.96, alpha: 0.92),
            roughness: 0.18
        )

        let foundation = SCNNode(
            geometry: SCNBox(
                width: width * 0.96,
                height: foundationHeight,
                length: depth * 0.96,
                chamferRadius: width * 0.04
            )
        )
        foundation.geometry?.firstMaterial = trimMaterial
        foundation.position = SCNVector3(0, Float(foundationHeight / 2), 0)
        addChildNode(foundation)

        let houseBody = SCNNode(
            geometry: SCNBox(
                width: width,
                height: wallHeight,
                length: depth,
                chamferRadius: width * 0.05
            )
        )
        houseBody.geometry?.firstMaterial = timberMaterial
        houseBody.position = SCNVector3(0, Float(foundationHeight + (wallHeight / 2)), 0)
        addChildNode(houseBody)

        let porch = SCNNode(
            geometry: SCNBox(
                width: doorWidth * 1.9,
                height: foundationHeight * 0.55,
                length: porchDepth,
                chamferRadius: width * 0.02
            )
        )
        porch.geometry?.firstMaterial = trimMaterial
        porch.position = SCNVector3(
            0,
            Float((foundationHeight * 0.55) / 2),
            Float((depth / 2) + (porchDepth / 2) - (wallThickness * 0.2))
        )
        addChildNode(porch)

        let door = SCNNode(
            geometry: SCNBox(
                width: doorWidth,
                height: doorHeight,
                length: wallThickness * 0.8,
                chamferRadius: width * 0.015
            )
        )
        door.geometry?.firstMaterial = doorMaterial
        door.position = SCNVector3(
            0,
            Float(foundationHeight + (doorHeight / 2) - (foundationHeight * 0.12)),
            Float((depth / 2) + (wallThickness * 0.1))
        )
        addChildNode(door)

        let doorFrame = SCNNode(
            geometry: SCNBox(
                width: doorWidth * 1.18,
                height: doorHeight * 1.1,
                length: wallThickness * 0.45,
                chamferRadius: width * 0.018
            )
        )
        doorFrame.geometry?.firstMaterial = trimMaterial
        doorFrame.position = SCNVector3(
            0,
            Float(foundationHeight + (doorHeight / 2) - (foundationHeight * 0.06)),
            Float((depth / 2) + (wallThickness * 0.36))
        )
        addChildNode(doorFrame)

        let doorKnob = SCNNode(geometry: SCNSphere(radius: width * 0.018))
        doorKnob.geometry?.firstMaterial = Self.material(
            diffuse: UIColor(red: 0.86, green: 0.72, blue: 0.42, alpha: 1.0),
            roughness: 0.32
        )
        doorKnob.position = SCNVector3(
            Float(doorWidth * 0.26),
            Float(foundationHeight + (doorHeight * 0.42)),
            Float((depth / 2) + (wallThickness * 0.52))
        )
        addChildNode(doorKnob)

        let roofWidth = width * 0.68
        let roofLength = depth * 1.16
        let leftRoof = SCNNode(
            geometry: SCNBox(
                width: roofWidth,
                height: roofThickness,
                length: roofLength,
                chamferRadius: width * 0.02
            )
        )
        leftRoof.geometry?.firstMaterial = roofMaterial
        leftRoof.position = SCNVector3(Float(width * -0.19), Float(foundationHeight + wallHeight + (roofHeight * 0.45)), 0)
        leftRoof.eulerAngles.z = 0.56
        addChildNode(leftRoof)

        let rightRoof = SCNNode(
            geometry: SCNBox(
                width: roofWidth,
                height: roofThickness,
                length: roofLength,
                chamferRadius: width * 0.02
            )
        )
        rightRoof.geometry?.firstMaterial = roofMaterial
        rightRoof.position = SCNVector3(Float(width * 0.19), Float(foundationHeight + wallHeight + (roofHeight * 0.45)), 0)
        rightRoof.eulerAngles.z = -0.56
        addChildNode(rightRoof)

        let roofRidge = SCNNode(
            geometry: SCNBox(
                width: width * 0.06,
                height: roofThickness * 0.85,
                length: roofLength * 0.98,
                chamferRadius: width * 0.01
            )
        )
        roofRidge.geometry?.firstMaterial = trimMaterial
        roofRidge.position = SCNVector3(0, Float(foundationHeight + wallHeight + roofHeight * 0.73), 0)
        addChildNode(roofRidge)

        let leftWindow = windowNode(
            size: CGSize(width: width * 0.16, height: wallHeight * 0.22),
            depth: wallThickness,
            frameMaterial: trimMaterial,
            glassMaterial: windowMaterial
        )
        leftWindow.position = SCNVector3(
            Float(width * -0.27),
            Float(foundationHeight + (wallHeight * 0.56)),
            Float((depth / 2) + (wallThickness * 0.16))
        )
        addChildNode(leftWindow)

        let rightWindow = windowNode(
            size: CGSize(width: width * 0.16, height: wallHeight * 0.22),
            depth: wallThickness,
            frameMaterial: trimMaterial,
            glassMaterial: windowMaterial
        )
        rightWindow.position = SCNVector3(
            Float(width * 0.27),
            Float(foundationHeight + (wallHeight * 0.56)),
            Float((depth / 2) + (wallThickness * 0.16))
        )
        addChildNode(rightWindow)

        name = "house"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func windowNode(
        size: CGSize,
        depth: CGFloat,
        frameMaterial: SCNMaterial,
        glassMaterial: SCNMaterial
    ) -> SCNNode {
        let root = SCNNode()

        let frame = SCNNode(
            geometry: SCNBox(
                width: size.width,
                height: size.height,
                length: depth * 0.38,
                chamferRadius: size.width * 0.08
            )
        )
        frame.geometry?.firstMaterial = frameMaterial
        root.addChildNode(frame)

        let pane = SCNNode(
            geometry: SCNBox(
                width: size.width * 0.72,
                height: size.height * 0.72,
                length: depth * 0.22,
                chamferRadius: size.width * 0.04
            )
        )
        pane.geometry?.firstMaterial = glassMaterial
        pane.position = SCNVector3(0, 0, Float(depth * 0.12))
        root.addChildNode(pane)

        return root
    }

    private static func material(diffuse: UIColor, roughness: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = diffuse
        material.metalness.contents = 0.0
        material.roughness.contents = roughness
        material.lightingModel = .physicallyBased
        return material
    }
}
