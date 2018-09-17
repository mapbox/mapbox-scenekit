import UIKit
import SceneKit
import MapKit
import MapboxSceneKit

/**
 Demonstrates how to create a terrain node using the Mapbox Scene Kit SDK and apply a heightmap to it based on terrain height.
 **/
class DemoHeightmapViewController: UIViewController {
    @IBOutlet private weak var stylePicker: UISegmentedControl?
    @IBOutlet private weak var sceneView: SCNView?
    @IBOutlet private weak var progressView: UIProgressView?
    private weak var terrainNode: TerrainNode?
    private var progressHandler: ProgressCompositor!

    private let styles = ["mapbox/outdoors-v10", "mapbox/satellite-v9", "mapbox/navigation-preview-day-v2"]

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        //Progress handler is a helper to aggregate progress through the three stages causing user wait: fetching heightmap images, calculating/rendering the heightmap, fetching the texture images
        progressHandler = ProgressCompositor(updater: { [weak self] progress in
            self?.progressView?.progress = progress
            self?.progressView?.isHidden = false
        }, completer: { [weak self] in
            self?.progressView?.isHidden = true
        })
    }

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

        self.terrainNode = terrainNode
        
        //Now that we've set up the terrain, lets place the lighting and camera in nicer positions
        scene.directionalLight.constraints = [SCNLookAtConstraint(target: terrainNode)]
        scene.directionalLight.position = SCNVector3Make(terrainNode.boundingBox.max.x, 5000, terrainNode.boundingBox.max.z)
        scene.cameraNode.position = SCNVector3(terrainNode.boundingBox.max.x * 2, 9000, terrainNode.boundingBox.max.z * 2)
        scene.cameraNode.look(at: terrainNode.position)

        applyStyle(styles.first!)
    }

    private func applyStyle(_ style: String) {
        guard let terrainNode = terrainNode else {
            return
        }

        self.progressView?.progress = 0.0
        
        //Time to hit the web API and load Mapbox heightmap data for the terrain node
        //Note, you can also wait to place the node until after this fetch has completed. It doesn't have to be in-scene to fetch.
        let terrainFetcherHandler = progressHandler.registerForProgress()
        let terrainRendererHandler = progressHandler.registerForProgress()
        progressHandler.updateProgress(handlerID: terrainRendererHandler, progress: 0, total: 1)
        let textureFetchHandler = progressHandler.registerForProgress()
        terrainNode.fetchTerrainAndTexture(minWallHeight: 50.0, multiplier: 1.5, enableDynamicShadows: false, textureStyle: style, heightProgress: { progress, total in
            self.progressHandler.updateProgress(handlerID: terrainFetcherHandler, progress: progress, total: total)
        }, heightCompletion: { heightFetchError in
            if let heightFetchError = heightFetchError {
                NSLog("Texture load failed: \(heightFetchError.localizedDescription)")
            } else {
                NSLog("Terrain load complete")
            }
            self.progressHandler.updateProgress(handlerID: terrainRendererHandler, progress: 1, total: 1)
        }, textureProgress: { progress, total in
            self.progressHandler.updateProgress(handlerID: textureFetchHandler, progress: progress, total: total)
        }) { image, textureFetchError in
            if let textureFetchError = textureFetchError {
                NSLog("Texture load failed: \(textureFetchError.localizedDescription)")
            }
            if image != nil {
                NSLog("Texture load for \(style) complete")
                terrainNode.geometry?.materials[4].diffuse.contents = image
            }
        }
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
