import UIKit
import SceneKit
import MapKit
import MapboxSceneKit

/**
 Simplest example of the Mapbox Scene Kit API: placing a flat box in Scene Kit and applying a user-created map style to the top surface.
 **/
class DemoStyleViewController: UIViewController {
    @IBOutlet private weak var sceneView: SCNView?
    @IBOutlet private weak var progressView: UIProgressView?
    @IBOutlet private weak var stylePicker: UISegmentedControl?
    private weak var terrainNode: TerrainNode?

    private let styles = ["mapbox/outdoors-v10", "mapbox/satellite-v9", "mapbox/navigation-preview-day-v2"]

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let sceneView = sceneView else {
            return
        }

        let scene = TerrainDemoScene()
        sceneView.scene = scene

        //Add the default camera controls for iOS 11
        sceneView.pointOfView = scene.cameraNode
        sceneView.defaultCameraController.pointOfView = sceneView.pointOfView
        sceneView.defaultCameraController.interactionMode = .orbitTurntable
        sceneView.defaultCameraController.inertiaEnabled = true
        sceneView.showsStatistics = true

        //Set up initial terrain and materials
        let terrainNode = TerrainNode(minLat: 50.044660402821592, maxLat: 50.120873988090956,
                                      minLon: -122.99017089272466, maxLon: -122.86824490727534)
        terrainNode.position = SCNVector3(0, 500, 0)
        terrainNode.geometry?.materials = defaultMaterials()
        scene.rootNode.addChildNode(terrainNode)

        //Now that we've set up the terrain, lets place the lighting and camera in nicer positions
        scene.directionalLight.constraints = [SCNLookAtConstraint(target: terrainNode)]
        scene.directionalLight.position = SCNVector3Make(terrainNode.boundingBox.max.x, terrainNode.boundingSphere.center.y + 5000, terrainNode.boundingBox.max.z)
        scene.cameraNode.position = SCNVector3(terrainNode.boundingBox.max.x * 2, 9000, terrainNode.boundingBox.max.z * 2)
        scene.cameraNode.look(at: terrainNode.position)

        self.terrainNode = terrainNode

        //Time to hit the web API and load Mapbox data for the terrain node
        applyStyle(styles.first!)
    }

    private func applyStyle(_ style: String) {
        guard let terrainNode = terrainNode else {
            return
        }

        self.progressView?.progress = 0.0
        self.progressView?.isHidden = false
        
        // we want to fetch texture only here, so we don't need to use the new fetching of both height and texture
        // for which this method was deprecated. Probably in real app you'll never want to present texture without
        // heights, so it stays here for easier example to let you get the idea faster as 1st simplest solution
        terrainNode.fetchTerrainTexture(style, progress: { progress, total in
            self.progressView?.progress = progress

        }, completion: { image, fetchError in
            if let fetchError = fetchError {
                NSLog("Texture load failed: \(fetchError.localizedDescription)")
            }
            if image != nil {
                NSLog("Texture load complete")
                terrainNode.geometry?.materials[4].diffuse.contents = image
            }
            self.progressView?.isHidden = true
        })
    }

    private func defaultMaterials() -> [SCNMaterial] {
        let groundImage = SCNMaterial()
        groundImage.diffuse.contents = UIColor.darkGray
        groundImage.name = "Ground texture"

        let sideMaterial = SCNMaterial()
        sideMaterial.diffuse.contents = UIColor.darkGray
        //TODO: Some kind of bug with the normals for sides where not having them double-sided has them not show up
        sideMaterial.isDoubleSided = true
        sideMaterial.name = "Side"

        let bottomMaterial = SCNMaterial()
        bottomMaterial.diffuse.contents = UIColor.black
        bottomMaterial.name = "Bottom"

        return [sideMaterial, sideMaterial, sideMaterial, sideMaterial, groundImage, bottomMaterial]
    }

    @IBAction func swtichStyle(_ sender: Any?) {
        applyStyle(styles[stylePicker!.selectedSegmentIndex])
    }
}
