import SceneKit
import SwiftUI
import UIKit

struct MagnetSceneView: UIViewRepresentable {
    let snapshot: MagnetSceneSnapshot

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        context.coordinator.configure(view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.render(snapshot, in: uiView)
    }

    final class Coordinator {
        private let scene = SCNScene()
        private var lastSnapshot: MagnetSceneSnapshot?

        func configure(_ view: SCNView) {
            view.scene = scene
            view.backgroundColor = UIColor(red: 0.015, green: 0.018, blue: 0.024, alpha: 1.0)
            view.allowsCameraControl = true
            view.autoenablesDefaultLighting = false
            view.antialiasingMode = .multisampling4X
            view.preferredFramesPerSecond = 60
        }

        func render(_ snapshot: MagnetSceneSnapshot, in view: SCNView) {
            guard snapshot != lastSnapshot || scene.rootNode.childNodes.isEmpty else {
                return
            }

            rebuild(snapshot)
            lastSnapshot = snapshot
            view.pointOfView = scene.rootNode.childNode(withName: "camera", recursively: false)
        }

        private func rebuild(_ snapshot: MagnetSceneSnapshot) {
            scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
            scene.background.contents = UIColor(red: 0.015, green: 0.018, blue: 0.024, alpha: 1.0)

            addCamera()
            addLights()
            addFloor()

            let entities = makeEntities(for: snapshot)
            let fieldSources = entities.filter { $0.contributesToField }

            let magnetsRoot = SCNNode()
            magnetsRoot.name = "magnet-catalog"
            scene.rootNode.addChildNode(magnetsRoot)

            for entity in entities {
                if entity.kind == .magneticGel || entity.kind == .ferrofluid {
                    guard snapshot.showGel else { continue }
                }
                let node = makeNode(for: entity, snapshot: snapshot)
                magnetsRoot.addChildNode(node)
            }

            if snapshot.showFieldLines {
                addFieldLines(for: fieldSources, snapshot: snapshot)
            }

            if snapshot.showCompasses {
                addCompassGrid(for: fieldSources)
            }

            if snapshot.showForces {
                addForceArrows(for: fieldSources)
            }
        }

        private func addCamera() {
            let camera = SCNCamera()
            camera.fieldOfView = 54
            camera.wantsHDR = true
            camera.wantsExposureAdaptation = true

            let node = SCNNode()
            node.name = "camera"
            node.camera = camera
            node.position = SCNVector3(0.0, 7.2, 12.4)
            node.eulerAngles = SCNVector3(-0.56, 0.0, 0.0)
            scene.rootNode.addChildNode(node)
        }

        private func addLights() {
            let key = SCNLight()
            key.type = .omni
            key.intensity = 1050
            key.temperature = 7200

            let keyNode = SCNNode()
            keyNode.light = key
            keyNode.position = SCNVector3(-4.8, 7.8, 6.5)
            scene.rootNode.addChildNode(keyNode)

            let fill = SCNLight()
            fill.type = .omni
            fill.intensity = 460

            let fillNode = SCNNode()
            fillNode.light = fill
            fillNode.position = SCNVector3(4.8, 4.6, -3.5)
            fillNode.eulerAngles = SCNVector3(-0.7, 0.7, 0.0)
            scene.rootNode.addChildNode(fillNode)

            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.intensity = 185
            ambient.color = UIColor(red: 0.35, green: 0.46, blue: 0.62, alpha: 1.0)

            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)
        }

        private func addFloor() {
            let floor = SCNFloor()
            floor.reflectivity = 0.08
            floor.materials = [material(UIColor(red: 0.035, green: 0.045, blue: 0.055, alpha: 1.0), metalness: 0.0, roughness: 0.72)]

            let floorNode = SCNNode(geometry: floor)
            floorNode.position = SCNVector3(0.0, -0.04, 0.0)
            scene.rootNode.addChildNode(floorNode)

            let grid = SCNNode()
            grid.name = "field-grid"
            scene.rootNode.addChildNode(grid)

            for index in -7...7 {
                let xLine = box(width: 14.0, height: 0.008, length: 0.012, color: UIColor.white.withAlphaComponent(index == 0 ? 0.2 : 0.075), chamfer: 0.0)
                xLine.position = SCNVector3(0.0, 0.006, Float(index))
                grid.addChildNode(xLine)

                let zLine = box(width: 0.012, height: 0.008, length: 14.0, color: UIColor.white.withAlphaComponent(index == 0 ? 0.2 : 0.075), chamfer: 0.0)
                zLine.position = SCNVector3(Float(index), 0.007, 0.0)
                grid.addChildNode(zLine)
            }
        }

        private func makeEntities(for snapshot: MagnetSceneSnapshot) -> [MagnetEntity] {
            let strength = Float(snapshot.strength)
            let polarity = Float(snapshot.polarity)
            let current = Float(snapshot.current)

            switch snapshot.scenario {
            case .fullCatalog:
                return [
                    MagnetEntity(kind: .bar, position: SCNVector3(-4.2, 0.42, -2.35), yaw: 0.25, strength: 1.15 * strength, polarity: polarity),
                    MagnetEntity(kind: .horseshoe, position: SCNVector3(-2.15, 0.52, -2.45), yaw: -0.25, strength: 1.05 * strength, polarity: polarity),
                    MagnetEntity(kind: .ring, position: SCNVector3(0.0, 0.62, -2.35), yaw: 0.0, strength: 0.82 * strength, polarity: polarity),
                    MagnetEntity(kind: .disk, position: SCNVector3(2.05, 0.42, -2.35), yaw: 0.35, strength: 0.75 * strength, polarity: polarity),
                    MagnetEntity(kind: .cube, position: SCNVector3(4.0, 0.46, -2.3), yaw: -0.45, strength: 0.8 * strength, polarity: polarity),
                    MagnetEntity(kind: .sphere, position: SCNVector3(-4.2, 0.5, -0.35), yaw: 0.4, strength: 0.68 * strength, polarity: polarity),
                    MagnetEntity(kind: .neodymiumBlock, position: SCNVector3(-2.05, 0.46, -0.28), yaw: -0.1, strength: 1.55 * strength, polarity: polarity),
                    MagnetEntity(kind: .solenoid, position: SCNVector3(0.0, 0.58, -0.25), yaw: 0.05, strength: strength, polarity: polarity, current: current),
                    MagnetEntity(kind: .electromagnet, position: SCNVector3(2.15, 0.62, -0.22), yaw: -0.2, strength: 1.25 * strength, polarity: polarity, current: current),
                    MagnetEntity(kind: .halbachArray, position: SCNVector3(4.08, 0.42, -0.25), yaw: 0.0, strength: 1.1 * strength, polarity: polarity),
                    MagnetEntity(kind: .fridgeSheet, position: SCNVector3(-3.08, 0.2, 1.65), yaw: 0.18, strength: 0.48 * strength, polarity: polarity),
                    MagnetEntity(kind: .compassNeedle, position: SCNVector3(-1.05, 0.18, 1.65), yaw: 0.35, strength: 0.25 * strength, polarity: polarity),
                    MagnetEntity(kind: .ferrofluid, position: SCNVector3(1.25, 0.08, 1.68), yaw: 0.0, strength: 0.22 * strength, polarity: polarity),
                    MagnetEntity(kind: .magneticGel, position: SCNVector3(3.3, 0.28, 1.62), yaw: -0.5, strength: 0.28 * strength, polarity: polarity),
                    MagnetEntity(kind: snapshot.activeKind, position: SCNVector3(0.1, 1.18, 2.95), yaw: -0.42, strength: 1.45 * strength, scale: 1.22, polarity: polarity, current: current)
                ]

            case .gelLab:
                return [
                    MagnetEntity(kind: .neodymiumBlock, position: SCNVector3(-1.8, 0.45, 0.0), yaw: 0.0, strength: 1.7 * strength, polarity: polarity),
                    MagnetEntity(kind: .ring, position: SCNVector3(1.7, 0.58, 0.05), yaw: 0.3, strength: 1.0 * strength, polarity: -polarity),
                    MagnetEntity(kind: .magneticGel, position: SCNVector3(0.0, 0.28, 1.65), yaw: -0.15, strength: 0.4 * strength, scale: 1.45, polarity: polarity),
                    MagnetEntity(kind: .ferrofluid, position: SCNVector3(0.0, 0.08, -1.55), yaw: 0.0, strength: 0.3 * strength, scale: 1.35, polarity: polarity)
                ]

            case .electromagnet:
                return [
                    MagnetEntity(kind: .electromagnet, position: SCNVector3(-1.35, 0.65, 0.0), yaw: 0.0, strength: 1.55 * strength, scale: 1.25, polarity: polarity, current: current),
                    MagnetEntity(kind: .solenoid, position: SCNVector3(1.75, 0.6, 0.0), yaw: 0.05, strength: 1.25 * strength, scale: 1.2, polarity: -polarity, current: current),
                    MagnetEntity(kind: .compassNeedle, position: SCNVector3(0.15, 0.18, 2.0), yaw: 0.0, strength: 0.2 * strength, polarity: polarity)
                ]

            case .halbach:
                return [
                    MagnetEntity(kind: .halbachArray, position: SCNVector3(0.0, 0.45, -0.5), yaw: 0.0, strength: 1.7 * strength, scale: 1.45, polarity: polarity),
                    MagnetEntity(kind: .fridgeSheet, position: SCNVector3(-2.9, 0.18, 1.55), yaw: 0.0, strength: 0.55 * strength, polarity: polarity),
                    MagnetEntity(kind: .bar, position: SCNVector3(2.8, 0.42, 1.55), yaw: 0.0, strength: 0.85 * strength, polarity: -polarity)
                ]

            case .compassRoom:
                return [
                    MagnetEntity(kind: .bar, position: SCNVector3(-1.4, 0.45, -0.65), yaw: 0.55, strength: 1.45 * strength, scale: 1.25, polarity: polarity),
                    MagnetEntity(kind: .horseshoe, position: SCNVector3(1.65, 0.5, 0.75), yaw: -0.35, strength: 1.05 * strength, scale: 1.15, polarity: -polarity)
                ]
            }
        }

        private func makeNode(for entity: MagnetEntity, snapshot: MagnetSceneSnapshot) -> SCNNode {
            let node = SCNNode()
            node.name = entity.kind.rawValue
            node.position = entity.position
            node.eulerAngles.y = entity.yaw
            node.scale = SCNVector3(entity.scale, entity.scale, entity.scale)

            switch entity.kind {
            case .bar:
                addBarMagnet(to: node)
            case .horseshoe:
                addHorseshoeMagnet(to: node)
            case .ring:
                addRingMagnet(to: node)
            case .disk:
                addDiskMagnet(to: node)
            case .cube:
                addCubeMagnet(to: node)
            case .sphere:
                addSphereMagnet(to: node)
            case .neodymiumBlock:
                addNeodymiumBlock(to: node)
            case .solenoid:
                addSolenoid(to: node, current: entity.current)
            case .electromagnet:
                addElectromagnet(to: node, current: entity.current)
            case .halbachArray:
                addHalbachArray(to: node)
            case .fridgeSheet:
                addFridgeSheet(to: node)
            case .compassNeedle:
                addCompassNeedle(to: node, yaw: 0.0, fieldStrength: entity.strength)
            case .ferrofluid:
                addFerrofluid(to: node, snapshot: snapshot)
            case .magneticGel:
                addMagneticGel(to: node, snapshot: snapshot)
            }

            if snapshot.isPaused == false && snapshot.animationSpeed > 0.01 {
                applyMotion(to: node, kind: entity.kind, speed: Float(snapshot.animationSpeed))
            }

            return node
        }

        private func addBarMagnet(to root: SCNNode) {
            let south = box(width: 0.82, height: 0.32, length: 0.36, color: UIColor(red: 0.15, green: 0.42, blue: 1.0, alpha: 1.0), chamfer: 0.04)
            south.position.x = -0.41
            root.addChildNode(south)

            let north = box(width: 0.82, height: 0.32, length: 0.36, color: UIColor(red: 1.0, green: 0.14, blue: 0.23, alpha: 1.0), chamfer: 0.04)
            north.position.x = 0.41
            root.addChildNode(north)

            root.addChildNode(label("S", color: .white, position: SCNVector3(-0.58, 0.22, 0.23), scale: 0.008))
            root.addChildNode(label("N", color: .white, position: SCNVector3(0.28, 0.22, 0.23), scale: 0.008))
        }

        private func addHorseshoeMagnet(to root: SCNNode) {
            let leftLeg = box(width: 0.28, height: 0.3, length: 1.42, color: UIColor(red: 0.13, green: 0.38, blue: 0.98, alpha: 1.0), chamfer: 0.05)
            leftLeg.position = SCNVector3(-0.48, 0.0, 0.0)
            root.addChildNode(leftLeg)

            let rightLeg = box(width: 0.28, height: 0.3, length: 1.42, color: UIColor(red: 1.0, green: 0.12, blue: 0.18, alpha: 1.0), chamfer: 0.05)
            rightLeg.position = SCNVector3(0.48, 0.0, 0.0)
            root.addChildNode(rightLeg)

            let bridge = box(width: 1.22, height: 0.3, length: 0.28, color: UIColor(red: 0.48, green: 0.53, blue: 0.62, alpha: 1.0), metalness: 0.35, chamfer: 0.06)
            bridge.position = SCNVector3(0.0, 0.0, -0.58)
            root.addChildNode(bridge)

            let southCap = sphere(radius: 0.18, color: UIColor(red: 0.13, green: 0.38, blue: 0.98, alpha: 1.0))
            southCap.position = SCNVector3(-0.48, 0.0, 0.72)
            root.addChildNode(southCap)

            let northCap = sphere(radius: 0.18, color: UIColor(red: 1.0, green: 0.12, blue: 0.18, alpha: 1.0))
            northCap.position = SCNVector3(0.48, 0.0, 0.72)
            root.addChildNode(northCap)
        }

        private func addRingMagnet(to root: SCNNode) {
            let ring = SCNTorus(ringRadius: 0.48, pipeRadius: 0.105)
            ring.materials = [
                material(UIColor(red: 0.58, green: 0.63, blue: 0.72, alpha: 1.0), metalness: 0.55, roughness: 0.26)
            ]

            let ringNode = SCNNode(geometry: ring)
            ringNode.eulerAngles.x = Float.pi / 2.0
            root.addChildNode(ringNode)

            let north = sphere(radius: 0.13, color: UIColor(red: 1.0, green: 0.12, blue: 0.2, alpha: 1.0))
            north.position.x = 0.58
            root.addChildNode(north)

            let south = sphere(radius: 0.13, color: UIColor(red: 0.15, green: 0.42, blue: 1.0, alpha: 1.0))
            south.position.x = -0.58
            root.addChildNode(south)
        }

        private func addDiskMagnet(to root: SCNNode) {
            let disk = SCNCylinder(radius: 0.48, height: 0.28)
            disk.radialSegmentCount = 48
            disk.materials = [material(UIColor(red: 0.72, green: 0.76, blue: 0.82, alpha: 1.0), metalness: 0.65, roughness: 0.22)]

            let diskNode = SCNNode(geometry: disk)
            root.addChildNode(diskNode)

            let north = cylinder(radius: 0.5, height: 0.035, color: UIColor(red: 1.0, green: 0.14, blue: 0.22, alpha: 1.0))
            north.position.y = 0.16
            root.addChildNode(north)

            let south = cylinder(radius: 0.5, height: 0.035, color: UIColor(red: 0.14, green: 0.42, blue: 1.0, alpha: 1.0))
            south.position.y = -0.16
            root.addChildNode(south)
        }

        private func addCubeMagnet(to root: SCNNode) {
            let core = box(width: 0.72, height: 0.72, length: 0.72, color: UIColor(red: 0.5, green: 0.55, blue: 0.62, alpha: 1.0), metalness: 0.5, chamfer: 0.055)
            root.addChildNode(core)

            let north = box(width: 0.08, height: 0.74, length: 0.74, color: UIColor(red: 1.0, green: 0.13, blue: 0.22, alpha: 1.0), chamfer: 0.02)
            north.position.x = 0.38
            root.addChildNode(north)

            let south = box(width: 0.08, height: 0.74, length: 0.74, color: UIColor(red: 0.15, green: 0.42, blue: 1.0, alpha: 1.0), chamfer: 0.02)
            south.position.x = -0.38
            root.addChildNode(south)
        }

        private func addSphereMagnet(to root: SCNNode) {
            let shell = SCNSphere(radius: 0.46)
            shell.segmentCount = 48
            shell.materials = [material(UIColor(red: 0.65, green: 0.7, blue: 0.78, alpha: 1.0), metalness: 0.6, roughness: 0.25)]
            root.addChildNode(SCNNode(geometry: shell))

            let north = sphere(radius: 0.16, color: UIColor(red: 1.0, green: 0.13, blue: 0.2, alpha: 1.0))
            north.position.x = 0.42
            root.addChildNode(north)

            let south = sphere(radius: 0.16, color: UIColor(red: 0.14, green: 0.42, blue: 1.0, alpha: 1.0))
            south.position.x = -0.42
            root.addChildNode(south)
        }

        private func addNeodymiumBlock(to root: SCNNode) {
            let block = box(width: 1.0, height: 0.34, length: 0.56, color: UIColor(red: 0.78, green: 0.8, blue: 0.84, alpha: 1.0), metalness: 0.8, roughness: 0.18, chamfer: 0.045)
            root.addChildNode(block)

            let shine = box(width: 0.96, height: 0.012, length: 0.51, color: UIColor.white.withAlphaComponent(0.28), chamfer: 0.01)
            shine.position.y = 0.176
            root.addChildNode(shine)

            let north = box(width: 0.07, height: 0.36, length: 0.57, color: UIColor(red: 1.0, green: 0.11, blue: 0.18, alpha: 1.0), chamfer: 0.015)
            north.position.x = 0.52
            root.addChildNode(north)

            let south = box(width: 0.07, height: 0.36, length: 0.57, color: UIColor(red: 0.12, green: 0.4, blue: 1.0, alpha: 1.0), chamfer: 0.015)
            south.position.x = -0.52
            root.addChildNode(south)
        }

        private func addSolenoid(to root: SCNNode, current: Float) {
            let core = cylinder(radius: 0.2, height: 1.45, color: UIColor(red: 0.34, green: 0.36, blue: 0.4, alpha: 1.0), metalness: 0.55)
            core.eulerAngles.z = Float.pi / 2.0
            root.addChildNode(core)

            for index in 0..<10 {
                let torus = SCNTorus(ringRadius: 0.28, pipeRadius: 0.024)
                torus.materials = [material(UIColor(red: 1.0, green: 0.55 + CGFloat(current) * 0.18, blue: 0.16, alpha: 1.0), metalness: 0.5, roughness: 0.22, emission: UIColor(red: CGFloat(current) * 0.5, green: CGFloat(current) * 0.25, blue: 0.0, alpha: 1.0))]
                let coil = SCNNode(geometry: torus)
                coil.eulerAngles.y = Float.pi / 2.0
                coil.position.x = -0.65 + Float(index) * 0.145
                root.addChildNode(coil)
            }

            root.addChildNode(arrow(from: SCNVector3(-0.92, 0.0, 0.0), to: SCNVector3(0.92, 0.0, 0.0), color: UIColor(red: 0.36, green: 0.9, blue: 1.0, alpha: 1.0)))
        }

        private func addElectromagnet(to root: SCNNode, current: Float) {
            let yoke = box(width: 1.38, height: 0.34, length: 0.3, color: UIColor(red: 0.38, green: 0.4, blue: 0.46, alpha: 1.0), metalness: 0.55, chamfer: 0.05)
            yoke.position.z = -0.42
            root.addChildNode(yoke)

            let south = box(width: 0.32, height: 0.32, length: 1.1, color: UIColor(red: 0.13, green: 0.4, blue: 1.0, alpha: 1.0), metalness: 0.25, chamfer: 0.045)
            south.position.x = -0.52
            root.addChildNode(south)

            let north = box(width: 0.32, height: 0.32, length: 1.1, color: UIColor(red: 1.0, green: 0.11, blue: 0.18, alpha: 1.0), metalness: 0.25, chamfer: 0.045)
            north.position.x = 0.52
            root.addChildNode(north)

            for index in 0..<8 {
                let torus = SCNTorus(ringRadius: 0.25, pipeRadius: 0.022)
                torus.materials = [material(UIColor(red: 1.0, green: 0.56, blue: 0.14, alpha: 1.0), metalness: 0.45, roughness: 0.24, emission: UIColor(red: CGFloat(current) * 0.45, green: CGFloat(current) * 0.18, blue: 0.0, alpha: 1.0))]
                let coil = SCNNode(geometry: torus)
                coil.eulerAngles.x = Float.pi / 2.0
                coil.position = SCNVector3(0.52, 0.0, -0.35 + Float(index) * 0.13)
                root.addChildNode(coil)
            }
        }

        private func addHalbachArray(to root: SCNNode) {
            let colors = [
                UIColor(red: 1.0, green: 0.14, blue: 0.22, alpha: 1.0),
                UIColor(red: 0.96, green: 0.64, blue: 0.12, alpha: 1.0),
                UIColor(red: 0.2, green: 0.82, blue: 1.0, alpha: 1.0),
                UIColor(red: 0.16, green: 0.44, blue: 1.0, alpha: 1.0),
                UIColor(red: 0.82, green: 0.42, blue: 1.0, alpha: 1.0)
            ]

            for index in 0..<5 {
                let block = box(width: 0.38, height: 0.38, length: 0.7, color: colors[index], metalness: 0.3, chamfer: 0.035)
                block.position.x = -0.82 + Float(index) * 0.41
                block.eulerAngles.z = Float(index) * Float.pi / 2.0
                root.addChildNode(block)

                let topArrow = arrow(from: SCNVector3(block.position.x, 0.35, -0.2), to: SCNVector3(block.position.x, 0.35, 0.25), color: .white)
                root.addChildNode(topArrow)
            }
        }

        private func addFridgeSheet(to root: SCNNode) {
            let backing = box(width: 1.45, height: 0.05, length: 0.95, color: UIColor(red: 0.1, green: 0.13, blue: 0.16, alpha: 1.0), metalness: 0.15, chamfer: 0.03)
            root.addChildNode(backing)

            for index in 0..<6 {
                let color = index.isMultiple(of: 2)
                    ? UIColor(red: 1.0, green: 0.14, blue: 0.22, alpha: 1.0)
                    : UIColor(red: 0.15, green: 0.44, blue: 1.0, alpha: 1.0)
                let stripe = box(width: 0.18, height: 0.065, length: 0.98, color: color.withAlphaComponent(0.82), chamfer: 0.01)
                stripe.position.x = -0.55 + Float(index) * 0.22
                root.addChildNode(stripe)
            }
        }

        private func addCompassNeedle(to root: SCNNode, yaw: Float, fieldStrength: Float) {
            let base = SCNCylinder(radius: 0.34, height: 0.035)
            base.radialSegmentCount = 42
            base.materials = [material(UIColor.white.withAlphaComponent(0.17), metalness: 0.1, roughness: 0.5)]
            let baseNode = SCNNode(geometry: base)
            root.addChildNode(baseNode)

            let pivot = sphere(radius: 0.045, color: UIColor.white.withAlphaComponent(0.75))
            pivot.position.y = 0.055
            root.addChildNode(pivot)

            let needleRoot = SCNNode()
            needleRoot.eulerAngles.y = yaw
            needleRoot.position.y = 0.065
            root.addChildNode(needleRoot)

            let north = box(width: 0.46, height: 0.035, length: 0.08, color: UIColor(red: 1.0, green: 0.12, blue: 0.2, alpha: 1.0), chamfer: 0.015)
            north.position.x = 0.21
            needleRoot.addChildNode(north)

            let south = box(width: 0.46, height: 0.035, length: 0.08, color: UIColor(red: 0.12, green: 0.4, blue: 1.0, alpha: 1.0), chamfer: 0.015)
            south.position.x = -0.21
            needleRoot.addChildNode(south)

            let glow = cylinder(radius: 0.39 + CGFloat(fieldStrength) * 0.04, height: 0.008, color: UIColor(red: 1.0, green: 0.86, blue: 0.32, alpha: 0.25))
            glow.position.y = 0.018
            root.addChildNode(glow)
        }

        private func addFerrofluid(to root: SCNNode, snapshot: MagnetSceneSnapshot) {
            let pool = cylinder(radius: 0.62, height: 0.07, color: UIColor(red: 0.02, green: 0.025, blue: 0.028, alpha: 0.95), metalness: 0.85, roughness: 0.18)
            pool.position.y = 0.035
            root.addChildNode(pool)

            let spikeCount = 18 + Int(snapshot.fieldDensity * 18.0)
            for index in 0..<spikeCount {
                let angle = Float(index) / Float(spikeCount) * Float.pi * 2.0
                let ring = Float(index % 4) / 4.0
                let radius = 0.12 + ring * 0.46
                let fieldLift = 0.26 + Float(snapshot.strength) * 0.18 + (1.0 - Float(snapshot.gelViscosity)) * 0.12
                let height = fieldLift * (0.7 + 0.35 * sinf(angle * 3.0))
                let cone = SCNCone(topRadius: 0.0, bottomRadius: 0.035 + CGFloat(ring) * 0.012, height: CGFloat(height))
                cone.radialSegmentCount = 18
                cone.materials = [material(UIColor(red: 0.025, green: 0.03, blue: 0.035, alpha: 1.0), metalness: 0.9, roughness: 0.14)]
                let spike = SCNNode(geometry: cone)
                spike.position = SCNVector3(cosf(angle) * radius, 0.07 + height / 2.0, sinf(angle) * radius)
                spike.eulerAngles.x = sinf(angle) * 0.12
                spike.eulerAngles.z = cosf(angle) * -0.12
                root.addChildNode(spike)
            }
        }

        private func addMagneticGel(to root: SCNNode, snapshot: MagnetSceneSnapshot) {
            let viscosity = Float(snapshot.gelViscosity)
            let stretch = 1.0 + Float(snapshot.strength) * (0.8 - viscosity * 0.45)

            for index in 0..<13 {
                let angle = Float(index) / 13.0 * Float.pi * 2.0
                let radius = 0.12 + Float(index % 5) * 0.065
                let gel = SCNSphere(radius: CGFloat(0.13 + Float(index % 3) * 0.018))
                gel.segmentCount = 24
                gel.materials = [
                    material(
                        UIColor(red: 0.25, green: 0.95, blue: 0.75, alpha: 0.44),
                        metalness: 0.0,
                        roughness: 0.18,
                        alpha: 0.56,
                        emission: UIColor(red: 0.02, green: 0.18, blue: 0.13, alpha: 1.0)
                    )
                ]

                let blob = SCNNode(geometry: gel)
                blob.position = SCNVector3(cosf(angle) * radius, 0.1 + Float(index % 4) * 0.055, sinf(angle) * radius * 0.75)
                blob.scale = SCNVector3(stretch, 0.74 + viscosity * 0.36, 0.74)
                blob.eulerAngles.y = angle * 0.35
                root.addChildNode(blob)
            }

            for index in 0..<9 {
                let offset = -0.44 + Float(index) * 0.11
                let bead = sphere(radius: 0.038, color: UIColor(red: 0.05, green: 0.08, blue: 0.09, alpha: 0.9))
                bead.position = SCNVector3(offset, 0.28 + sinf(offset * 8.0) * 0.04, 0.16 * sinf(offset * 4.0))
                root.addChildNode(bead)
            }
        }

        private func applyMotion(to node: SCNNode, kind: MagnetKind, speed: Float) {
            let duration = Double(max(0.35, 4.0 - speed * 3.0))
            switch kind {
            case .ring, .disk, .solenoid, .electromagnet:
                node.runAction(.repeatForever(.rotateBy(x: 0.0, y: CGFloat(0.55 + speed), z: 0.0, duration: duration)))
            case .magneticGel, .ferrofluid:
                node.runAction(.repeatForever(.sequence([
                    .moveBy(x: 0.0, y: CGFloat(0.05 * speed), z: 0.0, duration: duration * 0.4),
                    .moveBy(x: 0.0, y: CGFloat(-0.05 * speed), z: 0.0, duration: duration * 0.4)
                ])))
            default:
                break
            }
        }

        private func addFieldLines(for sources: [MagnetEntity], snapshot: MagnetSceneSnapshot) {
            guard sources.isEmpty == false else { return }

            let root = SCNNode()
            root.name = "field-lines"
            scene.rootNode.addChildNode(root)

            let density = max(5, 8 + Int(snapshot.fieldDensity * 18.0))
            let usableSources = Array(sources.prefix(snapshot.scenario == .fullCatalog ? 7 : sources.count))

            for source in usableSources {
                let direction = source.moment.normalized()
                guard direction.length > 0.001 else { continue }

                let basis = perpendicularBasis(for: direction)
                let origin = source.position + direction * (0.52 * source.scale)
                let rings = max(4, density / max(1, usableSources.count))

                for index in 0..<rings {
                    let angle = Float(index) / Float(rings) * Float.pi * 2.0
                    let radius = 0.18 + Float(index % 4) * 0.075
                    let seed = origin + basis.side * (cosf(angle) * radius) + basis.up * (sinf(angle) * radius + 0.18)
                    traceFieldLine(from: seed, sources: sources, root: root, polarity: Float(snapshot.polarity))
                }
            }
        }

        private func traceFieldLine(from seed: SCNVector3, sources: [MagnetEntity], root: SCNNode, polarity: Float) {
            var point = seed
            let stepLength: Float = 0.24

            for step in 0..<18 {
                let field = fieldVector(at: point, sources: sources)
                guard field.length > 0.002 else { break }

                var next = point + field.normalized() * stepLength
                next.y = min(max(next.y, 0.12), 3.2)
                guard abs(next.x) < 6.5 && abs(next.z) < 4.8 else { break }

                let energy = min(1.0, field.length * 0.55)
                let color = polarity >= 0.0
                    ? UIColor(red: 0.22 + CGFloat(energy) * 0.55, green: 0.82, blue: 1.0, alpha: 0.46)
                    : UIColor(red: 1.0, green: 0.42 + CGFloat(energy) * 0.3, blue: 0.32, alpha: 0.46)
                let segment = tube(from: point, to: next, radius: 0.008 + CGFloat(step % 3) * 0.0015, color: color)
                root.addChildNode(segment)
                point = next
            }
        }

        private func addCompassGrid(for sources: [MagnetEntity]) {
            guard sources.isEmpty == false else { return }

            let root = SCNNode()
            root.name = "compass-grid"
            scene.rootNode.addChildNode(root)

            for xIndex in -2...2 {
                for zIndex in -2...2 {
                    let point = SCNVector3(Float(xIndex) * 1.45, 0.05, Float(zIndex) * 1.12)
                    let field = fieldVector(at: point, sources: sources)
                    guard field.length > 0.001 else { continue }

                    let compass = SCNNode()
                    compass.position = point
                    let yaw = atan2f(-field.z, field.x)
                    addCompassNeedle(to: compass, yaw: -yaw, fieldStrength: min(1.4, field.length))
                    compass.scale = SCNVector3(0.58, 0.58, 0.58)
                    root.addChildNode(compass)
                }
            }
        }

        private func addForceArrows(for sources: [MagnetEntity]) {
            guard sources.count > 1 else { return }

            let root = SCNNode()
            root.name = "force-arrows"
            scene.rootNode.addChildNode(root)

            for source in sources.prefix(8) {
                let start = source.position + SCNVector3(0.0, 0.72 * source.scale, 0.0)
                let field = fieldVector(at: start + SCNVector3(0.1, 0.0, 0.1), sources: sources.filter { $0.id != source.id })
                guard field.length > 0.004 else { continue }

                let end = start + field.normalized() * min(0.85, 0.28 + field.length * 0.16)
                root.addChildNode(arrow(from: start, to: end, color: UIColor(red: 0.48, green: 1.0, blue: 0.52, alpha: 0.8)))
            }
        }

        private func fieldVector(at point: SCNVector3, sources: [MagnetEntity]) -> SCNVector3 {
            var total = SCNVector3.zero

            for source in sources {
                let r = point - source.position
                let distance = max(0.38, r.length)
                let unit = r / distance
                let moment = source.moment
                let dot = moment.dot(unit)
                let contribution = (unit * (3.0 * dot) - moment) * (1.0 / powf(distance, 3.0))
                total = total + contribution
            }

            return total
        }

        private func perpendicularBasis(for direction: SCNVector3) -> (side: SCNVector3, up: SCNVector3) {
            let worldUp = SCNVector3(0.0, 1.0, 0.0)
            var side = direction.cross(worldUp)
            if side.length < 0.001 {
                side = SCNVector3(1.0, 0.0, 0.0)
            }
            side = side.normalized()
            let up = side.cross(direction).normalized()
            return (side, up)
        }

        private func material(
            _ color: UIColor,
            metalness: CGFloat = 0.0,
            roughness: CGFloat = 0.35,
            alpha: CGFloat = 1.0,
            emission: UIColor? = nil
        ) -> SCNMaterial {
            let mat = SCNMaterial()
            mat.lightingModel = .physicallyBased
            mat.diffuse.contents = color.withAlphaComponent(alpha)
            mat.metalness.contents = NSNumber(value: Double(metalness))
            mat.roughness.contents = NSNumber(value: Double(roughness))
            mat.transparency = alpha
            mat.isDoubleSided = true
            if alpha < 1.0 {
                mat.blendMode = .alpha
            }
            if let emission = emission {
                mat.emission.contents = emission
            }
            return mat
        }

        private func box(
            width: CGFloat,
            height: CGFloat,
            length: CGFloat,
            color: UIColor,
            metalness: CGFloat = 0.0,
            roughness: CGFloat = 0.34,
            chamfer: CGFloat = 0.025
        ) -> SCNNode {
            let geometry = SCNBox(width: width, height: height, length: length, chamferRadius: chamfer)
            geometry.materials = [material(color, metalness: metalness, roughness: roughness, alpha: alphaComponent(color))]
            return SCNNode(geometry: geometry)
        }

        private func sphere(radius: CGFloat, color: UIColor) -> SCNNode {
            let geometry = SCNSphere(radius: radius)
            geometry.segmentCount = 32
            geometry.materials = [material(color, metalness: 0.2, roughness: 0.28, alpha: alphaComponent(color))]
            return SCNNode(geometry: geometry)
        }

        private func cylinder(
            radius: CGFloat,
            height: CGFloat,
            color: UIColor,
            metalness: CGFloat = 0.0,
            roughness: CGFloat = 0.28
        ) -> SCNNode {
            let geometry = SCNCylinder(radius: radius, height: height)
            geometry.radialSegmentCount = 36
            geometry.materials = [material(color, metalness: metalness, roughness: roughness, alpha: alphaComponent(color))]
            return SCNNode(geometry: geometry)
        }

        private func tube(from start: SCNVector3, to end: SCNVector3, radius: CGFloat, color: UIColor) -> SCNNode {
            let height = CGFloat((end - start).length)
            let geometry = SCNCylinder(radius: radius, height: max(0.001, height))
            geometry.radialSegmentCount = 10
            geometry.materials = [material(color, roughness: 0.18, alpha: alphaComponent(color), emission: color.withAlphaComponent(0.35))]
            let node = SCNNode(geometry: geometry)
            node.position = (start + end) * 0.5
            orient(node, along: end - start)
            return node
        }

        private func arrow(from start: SCNVector3, to end: SCNVector3, color: UIColor) -> SCNNode {
            let root = SCNNode()
            let direction = end - start
            let length = max(0.001, direction.length)
            let bodyEnd = start + direction.normalized() * max(0.001, length - 0.16)

            let shaft = tube(from: start, to: bodyEnd, radius: 0.018, color: color)
            root.addChildNode(shaft)

            let cone = SCNCone(topRadius: 0.0, bottomRadius: 0.055, height: 0.16)
            cone.radialSegmentCount = 18
            cone.materials = [material(color, roughness: 0.18, alpha: alphaComponent(color), emission: color.withAlphaComponent(0.22))]
            let head = SCNNode(geometry: cone)
            head.position = bodyEnd + direction.normalized() * 0.08
            orient(head, along: direction)
            root.addChildNode(head)
            return root
        }

        private func label(_ text: String, color: UIColor, position: SCNVector3, scale: Float) -> SCNNode {
            let geometry = SCNText(string: text, extrusionDepth: 0.012)
            geometry.font = UIFont.systemFont(ofSize: 12.0, weight: .black)
            geometry.flatness = 0.2
            geometry.materials = [material(color, roughness: 0.2, emission: color.withAlphaComponent(0.2))]

            let node = SCNNode(geometry: geometry)
            node.position = position
            node.scale = SCNVector3(scale, scale, scale)
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = SCNBillboardAxis.all
            node.constraints = [billboard]
            return node
        }

        private func alphaComponent(_ color: UIColor) -> CGFloat {
            var red: CGFloat = 0.0
            var green: CGFloat = 0.0
            var blue: CGFloat = 0.0
            var white: CGFloat = 0.0
            var alpha: CGFloat = 1.0

            if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                return alpha
            }

            if color.getWhite(&white, alpha: &alpha) {
                return alpha
            }

            return 1.0
        }

        private func orient(_ node: SCNNode, along direction: SCNVector3) {
            let unit = direction.normalized()
            let up = SCNVector3(0.0, 1.0, 0.0)
            let dot = min(1.0, max(-1.0, up.dot(unit)))
            let axis = up.cross(unit)

            if axis.length < 0.0001 {
                if dot < 0.0 {
                    node.orientation = SCNVector4(1.0, 0.0, 0.0, Float.pi)
                }
            } else {
                let normalizedAxis = axis.normalized()
                node.orientation = SCNVector4(normalizedAxis.x, normalizedAxis.y, normalizedAxis.z, acosf(dot))
            }
        }
    }
}

private struct MagnetEntity: Identifiable {
    let id = UUID()
    let kind: MagnetKind
    let position: SCNVector3
    let yaw: Float
    let strength: Float
    var scale: Float = 1.0
    var polarity: Float = 1.0
    var current: Float = 0.65

    var contributesToField: Bool {
        switch kind {
        case .compassNeedle, .ferrofluid, .magneticGel:
            return false
        default:
            return true
        }
    }

    var moment: SCNVector3 {
        let currentBoost: Float
        switch kind {
        case .solenoid, .electromagnet:
            currentBoost = max(0.08, current)
        case .fridgeSheet:
            currentBoost = 0.35
        default:
            currentBoost = 1.0
        }

        return SCNVector3(cosf(yaw), 0.0, -sinf(yaw)) * (strength * polarity * currentBoost)
    }
}

private extension SCNVector3 {
    static var zero: SCNVector3 {
        SCNVector3(0.0, 0.0, 0.0)
    }

    static func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    static func * (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        SCNVector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    static func / (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        SCNVector3(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
    }

    var length: Float {
        sqrtf(x * x + y * y + z * z)
    }

    func normalized() -> SCNVector3 {
        let value = length
        guard value > 0.00001 else {
            return .zero
        }
        return self / value
    }

    func dot(_ other: SCNVector3) -> Float {
        x * other.x + y * other.y + z * other.z
    }

    func cross(_ other: SCNVector3) -> SCNVector3 {
        SCNVector3(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        )
    }
}
