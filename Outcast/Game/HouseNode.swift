import SceneKit
import UIKit

final class HouseNode: SCNNode {
    enum DoorSwingDirection {
        case inward
        case outward
    }

    private let layout: HouseLayout
    private let wallHeight: CGFloat
    private let roofNode = SCNNode()
    private let frontDoorPivot = SCNNode()
    private let bedBlanketNode = SCNNode()
    private var frontDoorIsOpen = false
    private var frontDoorSwingDirection: DoorSwingDirection = .outward
    private var bedBlanketCoveredZ: CGFloat = 0
    private var bedBlanketPulledDownZ: CGFloat = 0
    private var bedBlanketCoveredLength: CGFloat = 0
    private var bedBlanketPulledDownLength: CGFloat = 0
    private var bedBlanketBaseHeight: CGFloat = 0
    private var bedBlanketBaseY: CGFloat = 0

    init(layout: HouseLayout, wallHeight: CGFloat) {
        self.layout = layout
        self.wallHeight = wallHeight
        super.init()
        buildModel()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setRoofHidden(_ hidden: Bool) {
        roofNode.isHidden = hidden
    }

    func setFrontDoorOpen(_ isOpen: Bool, swingDirection: DoorSwingDirection) {
        guard frontDoorIsOpen != isOpen || frontDoorSwingDirection != swingDirection else {
            return
        }

        frontDoorIsOpen = isOpen
        frontDoorSwingDirection = swingDirection
        let openAngle: CGFloat = switch swingDirection {
        case .inward:
            1.22
        case .outward:
            -1.22
        }
        animateDoor(frontDoorPivot, to: isOpen ? openAngle : 0)
    }

    func setBedBlanketState(coverage: CGFloat, occupant: CGFloat) {
        guard let blanket = bedBlanketNode.geometry as? SCNBox else {
            return
        }

        let clampedCoverage = max(0, min(coverage, 1))
        let clampedOccupant = max(0, min(occupant, 1))
        blanket.length = bedBlanketPulledDownLength + ((bedBlanketCoveredLength - bedBlanketPulledDownLength) * clampedCoverage)
        blanket.height = bedBlanketBaseHeight + (wallHeight * 0.05 * clampedOccupant)
        bedBlanketNode.position = SCNVector3(
            0,
            Float(bedBlanketBaseY + (wallHeight * 0.03 * clampedOccupant)),
            Float(bedBlanketPulledDownZ + ((bedBlanketCoveredZ - bedBlanketPulledDownZ) * clampedCoverage))
        )
        bedBlanketNode.eulerAngles.x = Float(-0.08 * clampedOccupant)
    }

    private func buildModel() {
        let foundationHeight = wallHeight * 0.12
        let floorHeight = wallHeight * 0.06
        let roofHeight = wallHeight * 0.75
        let roofThickness = wallHeight * 0.08
        let porchDepth = layout.outerRect.height * 0.16

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
        let ceilingMaterial = Self.material(
            diffuse: UIColor(red: 0.22, green: 0.16, blue: 0.11, alpha: 1.0),
            roughness: 0.9
        )
        let floorMaterial = Self.material(
            diffuse: UIColor(red: 0.41, green: 0.28, blue: 0.18, alpha: 1.0),
            roughness: 0.78
        )
        let beddingMaterial = Self.material(
            diffuse: UIColor(red: 0.29, green: 0.47, blue: 0.84, alpha: 1.0),
            roughness: 0.72
        )
        let blanketMaterial = Self.material(
            diffuse: UIColor(red: 0.22, green: 0.38, blue: 0.73, alpha: 1.0),
            roughness: 0.8
        )
        let pillowMaterial = Self.material(
            diffuse: UIColor(white: 0.97, alpha: 1.0),
            roughness: 0.64
        )
        let windowMaterial = Self.material(
            diffuse: UIColor(red: 0.84, green: 0.91, blue: 0.96, alpha: 0.92),
            roughness: 0.18
        )
        let doorMaterial = Self.material(
            diffuse: UIColor(red: 0.27, green: 0.17, blue: 0.1, alpha: 1.0),
            roughness: 0.84
        )

        name = "house"
        roofNode.name = "houseRoof"

        let foundation = SCNNode(
            geometry: SCNBox(
                width: layout.outerRect.width * 0.98,
                height: foundationHeight,
                length: layout.outerRect.height * 0.98,
                chamferRadius: layout.outerRect.width * 0.04
            )
        )
        foundation.geometry?.firstMaterial = trimMaterial
        foundation.position = SCNVector3(0, Float(foundationHeight / 2), 0)
        addChildNode(foundation)

        let mainFloor = SCNNode(
            geometry: SCNBox(
                width: layout.interiorRect.width,
                height: floorHeight,
                length: layout.interiorRect.height,
                chamferRadius: layout.outerRect.width * 0.02
            )
        )
        mainFloor.geometry?.firstMaterial = floorMaterial
        mainFloor.position = localPosition(for: layout.interiorRect, elevation: foundationHeight + (floorHeight / 2))
        addChildNode(mainFloor)

        addBed(
            floorElevation: foundationHeight + floorHeight,
            frameMaterial: trimMaterial,
            beddingMaterial: beddingMaterial,
            blanketMaterial: blanketMaterial,
            pillowMaterial: pillowMaterial
        )

        let porch = SCNNode(
            geometry: SCNBox(
                width: layout.frontDoorWidth * 1.45,
                height: foundationHeight * 0.58,
                length: porchDepth,
                chamferRadius: layout.outerRect.width * 0.02
            )
        )
        porch.geometry?.firstMaterial = trimMaterial
        porch.position = SCNVector3(
            0,
            Float((foundationHeight * 0.58) / 2),
            Float(-((layout.outerRect.height / 2) + (porchDepth / 2) - (layout.exteriorWallThickness * 0.24)))
        )
        addChildNode(porch)

        for wallRect in layout.exteriorWallRects + layout.interiorWallRects {
            addWall(for: wallRect, height: wallHeight, elevation: foundationHeight, material: timberMaterial)
        }

        addDoorFrame(
            openingRect: layout.frontDoorOpeningRect,
            wallThickness: layout.exteriorWallThickness,
            wallHeight: wallHeight,
            elevation: foundationHeight,
            material: trimMaterial
        )
        addFrontDoor(elevation: foundationHeight, material: doorMaterial, knobMaterial: trimMaterial)

        addWindow(
            center: CGPoint(
                x: layout.outerRect.minX + (layout.outerRect.width * 0.22),
                y: layout.outerRect.minY
            ),
            wallThickness: layout.exteriorWallThickness,
            elevation: foundationHeight + (wallHeight * 0.56),
            frameMaterial: trimMaterial,
            glassMaterial: windowMaterial
        )
        addWindow(
            center: CGPoint(
                x: layout.outerRect.maxX - (layout.outerRect.width * 0.22),
                y: layout.outerRect.minY
            ),
            wallThickness: layout.exteriorWallThickness,
            elevation: foundationHeight + (wallHeight * 0.56),
            frameMaterial: trimMaterial,
            glassMaterial: windowMaterial
        )

        let roofWidth = layout.outerRect.width * 0.68
        let roofLength = layout.outerRect.height * 1.16
        let leftRoof = SCNNode(
            geometry: SCNBox(
                width: roofWidth,
                height: roofThickness,
                length: roofLength,
                chamferRadius: layout.outerRect.width * 0.02
            )
        )
        leftRoof.geometry?.firstMaterial = roofMaterial
        leftRoof.position = SCNVector3(
            Float(layout.outerRect.width * -0.19),
            Float(foundationHeight + wallHeight + (roofHeight * 0.45)),
            0
        )
        leftRoof.eulerAngles.z = 0.56
        roofNode.addChildNode(leftRoof)

        let rightRoof = SCNNode(
            geometry: SCNBox(
                width: roofWidth,
                height: roofThickness,
                length: roofLength,
                chamferRadius: layout.outerRect.width * 0.02
            )
        )
        rightRoof.geometry?.firstMaterial = roofMaterial
        rightRoof.position = SCNVector3(
            Float(layout.outerRect.width * 0.19),
            Float(foundationHeight + wallHeight + (roofHeight * 0.45)),
            0
        )
        rightRoof.eulerAngles.z = -0.56
        roofNode.addChildNode(rightRoof)

        let roofRidge = SCNNode(
            geometry: SCNBox(
                width: layout.outerRect.width * 0.06,
                height: roofThickness * 0.85,
                length: roofLength * 0.98,
                chamferRadius: layout.outerRect.width * 0.01
            )
        )
        roofRidge.geometry?.firstMaterial = trimMaterial
        roofRidge.position = SCNVector3(0, Float(foundationHeight + wallHeight + roofHeight * 0.73), 0)
        roofNode.addChildNode(roofRidge)

        addGablePanel(
            atFront: true,
            baseElevation: foundationHeight + wallHeight,
            height: roofHeight * 0.78,
            thickness: layout.exteriorWallThickness * 0.76,
            material: timberMaterial
        )
        addGablePanel(
            atFront: false,
            baseElevation: foundationHeight + wallHeight,
            height: roofHeight * 0.78,
            thickness: layout.exteriorWallThickness * 0.76,
            material: timberMaterial
        )

        let ceiling = SCNNode(
            geometry: SCNBox(
                width: layout.interiorRect.width + (layout.exteriorWallThickness * 0.25),
                height: wallHeight * 0.04,
                length: layout.interiorRect.height + (layout.exteriorWallThickness * 0.25),
                chamferRadius: layout.outerRect.width * 0.01
            )
        )
        ceiling.geometry?.firstMaterial = ceilingMaterial
        ceiling.name = "houseCeiling"
        ceiling.position = SCNVector3(0, Float(foundationHeight + wallHeight + (wallHeight * 0.02)), 0)
        roofNode.addChildNode(ceiling)

        addChildNode(roofNode)
    }

    private func addGablePanel(
        atFront: Bool,
        baseElevation: CGFloat,
        height: CGFloat,
        thickness: CGFloat,
        material: SCNMaterial
    ) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: -(layout.outerRect.width * 0.47), y: 0))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: layout.outerRect.width * 0.47, y: 0))
        path.close()

        let panel = SCNNode(geometry: SCNShape(path: path, extrusionDepth: thickness))
        panel.geometry?.firstMaterial = material
        panel.pivot = SCNMatrix4MakeTranslation(0, 0, Float(thickness / 2))
        panel.position = SCNVector3(
            0,
            Float(baseElevation),
            Float((atFront ? 1 : -1) * (layout.outerRect.height / 2))
        )
        panel.name = atFront ? "houseFrontGable" : "houseBackGable"
        roofNode.addChildNode(panel)
    }

    private func addFrontDoor(elevation: CGFloat, material: SCNMaterial, knobMaterial: SCNMaterial) {
        let framePostHeight = wallHeight * 0.88
        let doorReveal = layout.exteriorWallThickness * 0.12
        let doorHeight = framePostHeight - doorReveal
        let doorThickness = layout.exteriorWallThickness * 0.48
        let doorWidth = layout.frontDoorOpeningRect.width - (doorReveal * 2)

        frontDoorPivot.position = localPosition(
            for: CGPoint(
                x: layout.frontDoorOpeningRect.minX + doorReveal,
                y: layout.frontDoorOpeningRect.midY
            ),
            elevation: elevation
        )
        frontDoorPivot.name = "frontDoorPivot"

        let door = SCNNode(
            geometry: SCNBox(
                width: doorWidth,
                height: doorHeight,
                length: doorThickness,
                chamferRadius: layout.outerRect.width * 0.015
            )
        )
        door.geometry?.firstMaterial = material
        door.name = "frontDoor"
        door.position = SCNVector3(Float(doorWidth / 2), Float(doorHeight / 2), 0)
        frontDoorPivot.addChildNode(door)

        let knob = SCNNode(geometry: SCNSphere(radius: layout.outerRect.width * 0.018))
        knob.geometry?.firstMaterial = knobMaterial
        knob.position = SCNVector3(Float(doorWidth * 0.78), Float(doorHeight * 0.48), Float(doorThickness * 0.72))
        frontDoorPivot.addChildNode(knob)

        addChildNode(frontDoorPivot)
    }

    private func addBed(
        floorElevation: CGFloat,
        frameMaterial: SCNMaterial,
        beddingMaterial: SCNMaterial,
        blanketMaterial: SCNMaterial,
        pillowMaterial: SCNMaterial
    ) {
        let bed = SCNNode()
        bed.name = "houseBed"

        let bedRect = layout.bedRect
        let bedWidth = bedRect.width
        let bedLength = bedRect.height
        let frameHeight = wallHeight * 0.08
        let mattressHeight = wallHeight * 0.09
        let headboardHeight = wallHeight * 0.28
        let railThickness = layout.exteriorWallThickness * 0.42
        bed.position = localPosition(for: bedRect, elevation: floorElevation)

        let frameBase = SCNNode(
            geometry: SCNBox(
                width: bedWidth,
                height: frameHeight,
                length: bedLength,
                chamferRadius: bedWidth * 0.08
            )
        )
        frameBase.geometry?.firstMaterial = frameMaterial
        frameBase.position = SCNVector3(0, Float(frameHeight / 2), 0)
        bed.addChildNode(frameBase)

        let mattress = SCNNode(
            geometry: SCNBox(
                width: bedWidth * 0.9,
                height: mattressHeight,
                length: bedLength * 0.92,
                chamferRadius: bedWidth * 0.08
            )
        )
        mattress.geometry?.firstMaterial = beddingMaterial
        mattress.position = SCNVector3(0, Float(frameHeight + (mattressHeight / 2)), 0)
        bed.addChildNode(mattress)

        let pillow = SCNNode(
            geometry: SCNBox(
                width: bedWidth * 0.62,
                height: mattressHeight * 0.55,
                length: bedLength * 0.18,
                chamferRadius: bedWidth * 0.09
            )
        )
        pillow.geometry?.firstMaterial = pillowMaterial
        pillow.position = SCNVector3(
            0,
            Float(frameHeight + mattressHeight + (mattressHeight * 0.28)),
            Float(-(bedLength * 0.28))
        )
        bed.addChildNode(pillow)

        bedBlanketCoveredLength = bedLength * 0.66
        bedBlanketPulledDownLength = bedLength * 0.42
        bedBlanketCoveredZ = bedLength * 0.14
        bedBlanketPulledDownZ = bedLength * 0.48
        bedBlanketBaseHeight = mattressHeight * 0.24
        bedBlanketBaseY = frameHeight + mattressHeight + (bedBlanketBaseHeight / 2)
        bedBlanketNode.geometry = SCNBox(
            width: bedWidth * 0.88,
            height: bedBlanketBaseHeight,
            length: bedBlanketCoveredLength,
            chamferRadius: bedWidth * 0.07
        )
        bedBlanketNode.geometry?.firstMaterial = blanketMaterial
        bedBlanketNode.name = "houseBedBlanket"
        bed.addChildNode(bedBlanketNode)
        setBedBlanketState(coverage: 1, occupant: 0)

        let headboard = SCNNode(
            geometry: SCNBox(
                width: bedWidth,
                height: headboardHeight,
                length: railThickness,
                chamferRadius: railThickness * 0.45
            )
        )
        headboard.geometry?.firstMaterial = frameMaterial
        headboard.position = SCNVector3(
            0,
            Float(frameHeight + (headboardHeight / 2)),
            Float(-(bedLength / 2) + (railThickness / 2))
        )
        bed.addChildNode(headboard)

        let sideRailOffsetX = (bedWidth / 2) - (railThickness / 2)
        let sideRailHeight = mattressHeight * 0.9
        let sideRailLength = bedLength * 0.88
        for direction in [-1 as CGFloat, 1] {
            let rail = SCNNode(
                geometry: SCNBox(
                    width: railThickness,
                    height: sideRailHeight,
                    length: sideRailLength,
                    chamferRadius: railThickness * 0.4
                )
            )
            rail.geometry?.firstMaterial = frameMaterial
            rail.position = SCNVector3(
                Float(direction * sideRailOffsetX),
                Float(frameHeight + (sideRailHeight / 2)),
                0
            )
            bed.addChildNode(rail)
        }

        addChildNode(bed)
    }

    private func addWall(for rect: CGRect, height: CGFloat, elevation: CGFloat, material: SCNMaterial) {
        let wall = SCNNode(
            geometry: SCNBox(
                width: rect.width,
                height: height,
                length: rect.height,
                chamferRadius: min(rect.width, rect.height) * 0.12
            )
        )
        wall.geometry?.firstMaterial = material
        wall.position = localPosition(for: rect, elevation: elevation + (height / 2))
        addChildNode(wall)
    }

    private func addDoorFrame(
        openingRect: CGRect,
        wallThickness: CGFloat,
        wallHeight: CGFloat,
        elevation: CGFloat,
        material: SCNMaterial
    ) {
        let postWidth = wallThickness * 0.58
        let postHeight = wallHeight * 0.88
        let lintelHeight = wallThickness * 0.7
        let baseElevation = elevation + (postHeight / 2)

        if openingRect.width > openingRect.height {
            let leftPostRect = CGRect(
                x: openingRect.minX - postWidth,
                y: openingRect.midY - (wallThickness / 2),
                width: postWidth,
                height: wallThickness
            )
            let rightPostRect = CGRect(
                x: openingRect.maxX,
                y: openingRect.midY - (wallThickness / 2),
                width: postWidth,
                height: wallThickness
            )
            let lintelRect = CGRect(
                x: openingRect.minX - postWidth,
                y: openingRect.midY - (wallThickness / 2),
                width: openingRect.width + (postWidth * 2),
                height: wallThickness * 0.7
            )

            addFramePiece(for: leftPostRect, height: postHeight, elevation: baseElevation, material: material)
            addFramePiece(for: rightPostRect, height: postHeight, elevation: baseElevation, material: material)
            addFramePiece(
                for: lintelRect,
                height: lintelHeight,
                elevation: elevation + postHeight + (lintelHeight / 2),
                material: material
            )
        } else {
            let lowerPostRect = CGRect(
                x: openingRect.midX - (wallThickness / 2),
                y: openingRect.minY - postWidth,
                width: wallThickness,
                height: postWidth
            )
            let upperPostRect = CGRect(
                x: openingRect.midX - (wallThickness / 2),
                y: openingRect.maxY,
                width: wallThickness,
                height: postWidth
            )

            addFramePiece(for: lowerPostRect, height: postHeight, elevation: baseElevation, material: material)
            addFramePiece(for: upperPostRect, height: postHeight, elevation: baseElevation, material: material)
            addFramePiece(
                for: openingRect,
                height: lintelHeight,
                elevation: elevation + postHeight + (lintelHeight / 2),
                material: material
            )
        }
    }

    private func addFramePiece(for rect: CGRect, height: CGFloat, elevation: CGFloat, material: SCNMaterial) {
        let framePiece = SCNNode(
            geometry: SCNBox(
                width: rect.width,
                height: height,
                length: rect.height,
                chamferRadius: min(rect.width, rect.height) * 0.18
            )
        )
        framePiece.geometry?.firstMaterial = material
        framePiece.position = localPosition(for: rect, elevation: elevation)
        addChildNode(framePiece)
    }

    private func addWindow(
        center: CGPoint,
        wallThickness: CGFloat,
        elevation: CGFloat,
        frameMaterial: SCNMaterial,
        glassMaterial: SCNMaterial
    ) {
        let size = CGSize(width: layout.outerRect.width * 0.16, height: wallHeight * 0.22)
        let window = windowNode(size: size, depth: wallThickness, frameMaterial: frameMaterial, glassMaterial: glassMaterial)
        window.position = localPosition(for: center, elevation: elevation)
        window.position.z -= Float(wallThickness * 0.16)
        addChildNode(window)
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
                length: depth * 0.42,
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
        pane.position = SCNVector3(0, 0, Float(depth * 0.14))
        root.addChildNode(pane)

        return root
    }

    private func localPosition(for rect: CGRect, elevation: CGFloat) -> SCNVector3 {
        localPosition(for: CGPoint(x: rect.midX, y: rect.midY), elevation: elevation)
    }

    private func localPosition(for point: CGPoint, elevation: CGFloat) -> SCNVector3 {
        SCNVector3(
            Float(point.x - layout.center.x),
            Float(elevation),
            Float(-(point.y - layout.center.y))
        )
    }

    private func hingePosition(for rect: CGRect, hingedAtMinimumSide: Bool, elevation: CGFloat) -> SCNVector3 {
        if rect.width > rect.height {
            let x = hingedAtMinimumSide ? rect.minX : rect.maxX
            return localPosition(for: CGPoint(x: x, y: rect.midY), elevation: elevation)
        }

        let y = hingedAtMinimumSide ? rect.minY : rect.maxY
        return localPosition(for: CGPoint(x: rect.midX, y: y), elevation: elevation)
    }

    private func animateDoor(_ pivot: SCNNode, to angle: CGFloat) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.16
        pivot.eulerAngles.y = Float(angle)
        SCNTransaction.commit()
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
