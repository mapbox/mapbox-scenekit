import UIKit
import SceneKit
import MapKit
import MapboxSceneKit

/**
 Demonstrates annotating a `TerrainNode` with other SCNShapes given a series of lat/lons.

 Can extend this to do more complex annotations like a tube representing a user's hike.
 **/
class DemoPlacementViewController: UIViewController {
    @IBOutlet private weak var sceneView: SCNView?
    @IBOutlet private weak var progressView: UIProgressView?

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
        scene.directionalLight.position = SCNVector3Make(terrainNode.boundingBox.max.x, 5000, terrainNode.boundingBox.max.z)
        scene.cameraNode.position = SCNVector3(terrainNode.boundingBox.max.x * 2, 9000, terrainNode.boundingBox.max.z * 2)
        scene.cameraNode.look(at: terrainNode.position)

        //Time to hit the web API and load Mapbox data for the terrain node
        //Note, you can also wait to place the node until after this fetch has completed. It doesn't have to be in-scene to fetch.

        self.progressView?.progress = 0.0
        self.progressView?.isHidden = false

        //Progress handler is a helper to aggregate progress through the three stages causing user wait: fetching heightmap images, calculating/rendering the heightmap, fetching the texture images
        let progressHandler = ProgressCompositor(updater: { [weak self] progress in
            self?.progressView?.progress = progress
            }, completer: { [weak self] in
                self?.progressView?.isHidden = true
        })

        let terrainRendererHandler = progressHandler.registerForProgress()
        progressHandler.updateProgress(handlerID: terrainRendererHandler, progress: 0, total: 1)
        let terrainFetcherHandler = progressHandler.registerForProgress()
        let textureFetchHandler = progressHandler.registerForProgress()
        
        terrainNode.fetchTerrainAndTexture(minWallHeight: 50.0, enableDynamicShadows: true, textureStyle: "mapbox/satellite-v9", heightProgress: { progress, total in
            progressHandler.updateProgress(handlerID: terrainFetcherHandler, progress: progress, total: total)
        }, heightCompletion: { fetchError in
            if let fetchError = fetchError {
                NSLog("Texture load failed: \(fetchError.localizedDescription)")
            } else {
                NSLog("Terrain load complete")
            }
            progressHandler.updateProgress(handlerID: terrainRendererHandler, progress: 1, total: 1)
            self.addUserPath(to: terrainNode)
        }, textureProgress: { progress, total in
            progressHandler.updateProgress(handlerID: textureFetchHandler, progress: progress, total: total)
        }) { image, fetchError in
            if let fetchError = fetchError {
                NSLog("Texture load failed: \(fetchError.localizedDescription)")
            }
            if image != nil {
                NSLog("Texture load complete")
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

    private func addUserPath(to terrainNode: TerrainNode) {
        var locations: [CLLocation] = [CLLocation(latitude: 50.107331, longitude: -122.891896),
                                       CLLocation(latitude: 50.109012, longitude: -122.898778),
                                       CLLocation(latitude: 50.111739, longitude: -122.923185),
                                       CLLocation(latitude: 50.108450, longitude: -122.941771),
                                       CLLocation(latitude: 50.111412, longitude: -122.950553),
                                       CLLocation(latitude: 50.113317, longitude: -122.953522)]
        
        // optional step, adds midpoints in long segments to avoid going through a mountain
        locations = terrainNode.normalise(locations: locations, maximumDistance: 50) // eg. here it crates 97 values from 6, each pair distance < 50m
        
        let lineA = terrainNode.addPolyline(coordinates: locations, radius: 20, color: .red)
        
        let lineB = terrainNode.addPolyline(coordinates: locations, startRadius: 30, endRadius: 80, startColor: .red, endColor: .yellow)
        lineB.position.y += 200
        
        let lineC = terrainNode.addPolyline(coordinates: locations, radii: [10, 50, 30], colors: [.red, .yellow, .orange], verticalOffset: 40)
        lineC.position.y += 400
    }
}
