import Foundation
import SceneKit

/**
 Basic setup of camrea and lighting nodes for non-AR demo scenes.
 **/
@objc(MBTerrainDemoScene)
final class TerrainDemoScene: SCNScene {
    @objc public let cameraNode: SCNNode = Camera()
    @objc public let directionalLight: SCNNode = DirectionalLight()
    @objc public var floorColor: UIColor = UIColor.lightGray {
        didSet {
            floorNode.floorMaterial.diffuse.contents = floorColor
        }
    }
    @objc public var floorReflectivity: CGFloat = 0.1 {
        didSet {
            floorNode.floor.reflectivity = floorReflectivity
        }
    }
    
    fileprivate let floorNode: FloorNode = FloorNode()

    override init() {
        super.init()

        addDebugGuide()

        rootNode.addChildNode(floorNode)
        rootNode.addChildNode(AmbientLight())
        rootNode.addChildNode(directionalLight)
        directionalLight.position = SCNVector3Make(0, 5000, 0)
        background.contents = UIColor(red: 61.0/255.0, green: 171.0/255.0, blue: 235.0/255.0, alpha: 1.0)
        rootNode.addChildNode(cameraNode)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addDebugGuide() {
        for axis in ["x", "y", "z"] {
            let axisBox = SCNNode(geometry: SCNBox(width: axis == "x" ? 1000 : 10, height: axis == "y" ? 1000 : 10, length: axis == "z" ? 1000 : 10, chamferRadius: 0))
            let mat = SCNMaterial()
            if axis == "x" {
                mat.diffuse.contents = UIColor.red
            } else if axis == "y" {
                mat.diffuse.contents = UIColor.green
            } else if axis == "z" {
                mat.diffuse.contents = UIColor.blue
            }
            axisBox.geometry!.materials = [mat]
            axisBox.position = SCNVector3(0, 0, 0)
            axisBox.name = "\(axis) Axis Guide"
            rootNode.addChildNode(axisBox)
        }
    }
}

fileprivate final class Camera: SCNNode {
    override init() {
        super.init()

        name = "Camera"
        camera = SCNCamera()
        camera!.automaticallyAdjustsZRange = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate final class DirectionalLight: SCNNode {
    override init() {
        super.init()
        name = "Directional Light"
        light = SCNLight()
        light!.type = .directional
        light!.color = UIColor.white
        light!.temperature = 5500
        light!.intensity = 1300
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate final class AmbientLight: SCNNode {
    override init() {
        super.init()
        name = "Ambient Light"
        light = SCNLight()
        light!.type = .ambient
        light!.color = UIColor(white: 0.6, alpha: 1.0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate final class FloorNode: SCNNode {
    let floorMaterial: SCNMaterial = SCNMaterial()
    let floor: SCNFloor = SCNFloor()
    
    override init() {
        floorMaterial.diffuse.contents = UIColor.lightGray
        floorMaterial.locksAmbientWithDiffuse = true
        floorMaterial.isDoubleSided = true
        
        floor.materials = [floorMaterial]
        floor.reflectivity = 0.1

        super.init()

        geometry = floor
        name = "Floor"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
