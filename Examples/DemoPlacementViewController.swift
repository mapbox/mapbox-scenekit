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
        let southWest = CLLocation(latitude: 50.044660402821592, longitude: -122.99017089272466)
        let northEast = CLLocation(latitude: 50.120873988090956, longitude: -122.86824490727534)
        let terrainNode = TerrainNode(southWestCorner: southWest, northEastCorner: northEast)
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
        
        terrainNode.fetchTerrainAndTexture(minWallHeight: 50.0, enableDynamicShadows: true, textureStyle: MapStyles.satellite.url, heightProgress: { progress, total in
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
        let latlons: [(CLLocationDegrees, CLLocationDegrees)] = [(50.107331, -122.891896),(50.107330, -122.892045),(50.107330, -122.892045),(50.107421, -122.892013),(50.107503, -122.892078),(50.107450, -122.892209),(50.107339, -122.892343),(50.107242, -122.892445),(50.107124, -122.892530),(50.106991, -122.892603),(50.106868, -122.892586),(50.106774, -122.892631),(50.106884, -122.892758),(50.107027, -122.892833),(50.107193, -122.892916),(50.107360, -122.892967),(50.107456, -122.892942),(50.107611, -122.892836),(50.107754, -122.892748),(50.107906, -122.892678),(50.108056, -122.892624),(50.108172, -122.892711),(50.108226, -122.892866),(50.108248, -122.893016),(50.108312, -122.893193),(50.108358, -122.893335),(50.108395, -122.893492),(50.108426, -122.893654),(50.108426, -122.893838),(50.108418, -122.894031),(50.108394, -122.894192),(50.108376, -122.894348),(50.108344, -122.894483),(50.108336, -122.894700),(50.108326, -122.894843),(50.108333, -122.895024),(50.108349, -122.895181),(50.108431, -122.895303),(50.108488, -122.895464),(50.108474, -122.895604),(50.108469, -122.895746),(50.108456, -122.895922),(50.108515, -122.896068),(50.108506, -122.896213),(50.108541, -122.896363),(50.108568, -122.896576),(50.108620, -122.896699),(50.108629, -122.896759),(50.108677, -122.896898),(50.108750, -122.897049),(50.108799, -122.897149),(50.108841, -122.897251),(50.108921, -122.897413),(50.108949, -122.897575),(50.109013, -122.897727),(50.109025, -122.897851),(50.109050, -122.898098),(50.109011, -122.898247),(50.108926, -122.898307),(50.108834, -122.898334),(50.108870, -122.898490),(50.108951, -122.898627),(50.109012, -122.898778),(50.109088, -122.898922),(50.109166, -122.899014),(50.109230, -122.899139),(50.109327, -122.899267),(50.109389, -122.899406),(50.109413, -122.899544),(50.109454, -122.899719),(50.109438, -122.899953),(50.109453, -122.900146),(50.109432, -122.900321),(50.109425, -122.900474),(50.109363, -122.900597),(50.109312, -122.900756),(50.109225, -122.900830),(50.109138, -122.900872),(50.109001, -122.900922),(50.108904, -122.900976),(50.108793, -122.900970),(50.108712, -122.901041),(50.108612, -122.901055),(50.108528, -122.901187),(50.108433, -122.901297),(50.108289, -122.901450),(50.108208, -122.901535),(50.108126, -122.901624),(50.108041, -122.901729),(50.107968, -122.901839),(50.107909, -122.901946),(50.107816, -122.902167),(50.107717, -122.902350),(50.107652, -122.902517),(50.107615, -122.902675),(50.107631, -122.902822),(50.107662, -122.903006),(50.107679, -122.903250),(50.107696, -122.903505),(50.107744, -122.903769),(50.107854, -122.903988),(50.107931, -122.904095),(50.107993, -122.904224),(50.108015, -122.904383),(50.108058, -122.904563),(50.108112, -122.904742),(50.108155, -122.904950),(50.108191, -122.905164),(50.108231, -122.905373),(50.108284, -122.905559),(50.108354, -122.905739),(50.108421, -122.905915),(50.108463, -122.906077),(50.108518, -122.906215),(50.108587, -122.906337),(50.108643, -122.906471),(50.108672, -122.906612),(50.108724, -122.906730),(50.108811, -122.906923),(50.108879, -122.907141),(50.108996, -122.907336),(50.109105, -122.907536),(50.109193, -122.907761),(50.109209, -122.907923),(50.109313, -122.908134),(50.109364, -122.908430),(50.109423, -122.908570),(50.109519, -122.908791),(50.109574, -122.908910),(50.109649, -122.909006),(50.109718, -122.909096),(50.109782, -122.909201),(50.109859, -122.909290),(50.109958, -122.909359),(50.110050, -122.909402),(50.110126, -122.909606),(50.110244, -122.909802),(50.110319, -122.909961),(50.110350, -122.910168),(50.110402, -122.910448),(50.110413, -122.910647),(50.110444, -122.910825),(50.110496, -122.910967),(50.110541, -122.911126),(50.110558, -122.911287),(50.110551, -122.911452),(50.110566, -122.911607),(50.110596, -122.911741),(50.110613, -122.911883),(50.110608, -122.912043),(50.110629, -122.912185),(50.110686, -122.912294),(50.110773, -122.912440),(50.110848, -122.912542),(50.110925, -122.912623),(50.111021, -122.912663),(50.111145, -122.912778),(50.111267, -122.912950),(50.111361, -122.913105),(50.111449, -122.913293),(50.111478, -122.913557),(50.111503, -122.913694),(50.111540, -122.913944),(50.111546, -122.914210),(50.111540, -122.914390),(50.111517, -122.914575),(50.111497, -122.914806),(50.111431, -122.914968),(50.111399, -122.915173),(50.111332, -122.915366),(50.111290, -122.915544),(50.111248, -122.915695),(50.111208, -122.915869),(50.111175, -122.916048),(50.111155, -122.916187),(50.111188, -122.916391),(50.111200, -122.916587),(50.111211, -122.916871),(50.111223, -122.917023),(50.111248, -122.917283),(50.111275, -122.917531),(50.111282, -122.917775),(50.111308, -122.918008),(50.111292, -122.918268),(50.111281, -122.918569),(50.111273, -122.918732),(50.111267, -122.918882),(50.111272, -122.919041),(50.111273, -122.919207),(50.111279, -122.919378),(50.111292, -122.919548),(50.111306, -122.919716),(50.111327, -122.919891),(50.111355, -122.920061),(50.111392, -122.920215),(50.111429, -122.920352),(50.111472, -122.920489),(50.111513, -122.920645),(50.111560, -122.920796),(50.111616, -122.920928),(50.111667, -122.921064),(50.111703, -122.921197),(50.111736, -122.921436),(50.111794, -122.921647),(50.111799, -122.921871),(50.111834, -122.922089),(50.111855, -122.922285),(50.111879, -122.922460),(50.111905, -122.922623),(50.111942, -122.922752),(50.111947, -122.922905),(50.111918, -122.923056),(50.111844, -122.923169),(50.111739, -122.923185),(50.111649, -122.923184),(50.111560, -122.923242),(50.111472, -122.923299),(50.111376, -122.923318),(50.111280, -122.923349),(50.111188, -122.923382),(50.111095, -122.923408),(50.111008, -122.923475),(50.110910, -122.923516),(50.110815, -122.923508),(50.110848, -122.923366),(50.110852, -122.923398),(50.110775, -122.923484),(50.110744, -122.923676),(50.110744, -122.923676),(50.110712, -122.923816),(50.110689, -122.923987),(50.110697, -122.924166),(50.110690, -122.924341),(50.110712, -122.924532),(50.110731, -122.924746),(50.110835, -122.924878),(50.110976, -122.924924),(50.111126, -122.924940),(50.111273, -122.924888),(50.111398, -122.924811),(50.111513, -122.924794),(50.111640, -122.924750),(50.111764, -122.924678),(50.111894, -122.924603),(50.112052, -122.924529),(50.112191, -122.924424),(50.112333, -122.924345),(50.112500, -122.924286),(50.112635, -122.924180),(50.112752, -122.924175),(50.112789, -122.924361),(50.112719, -122.924566),(50.112684, -122.924698),(50.112652, -122.924830),(50.112590, -122.925059),(50.112467, -122.925247),(50.112354, -122.925416),(50.112267, -122.925620),(50.112214, -122.925745),(50.112163, -122.925871),(50.112106, -122.925990),(50.112061, -122.926125),(50.112022, -122.926278),(50.111989, -122.926411),(50.111920, -122.926668),(50.111874, -122.926800),(50.111820, -122.926932),(50.111723, -122.927147),(50.111678, -122.927270),(50.111573, -122.927481),(50.111453, -122.927667),(50.111376, -122.927742),(50.111282, -122.927803),(50.111199, -122.927865),(50.111054, -122.927983),(50.110976, -122.928060),(50.110896, -122.928130),(50.110743, -122.928218),(50.110594, -122.928294),(50.110449, -122.928349),(50.110312, -122.928422),(50.110169, -122.928553),(50.110016, -122.928704),(50.109945, -122.928812),(50.109882, -122.928943),(50.109820, -122.929063),(50.109750, -122.929163),(50.109676, -122.929245),(50.109553, -122.929429),(50.109424, -122.929594),(50.109294, -122.929770),(50.109224, -122.929858),(50.109147, -122.929943),(50.109008, -122.930120),(50.108870, -122.930277),(50.108754, -122.930418),(50.108668, -122.930603),(50.108568, -122.930803),(50.108468, -122.931022),(50.108404, -122.931151),(50.108335, -122.931386),(50.108259, -122.931616),(50.108189, -122.931844),(50.108097, -122.932084),(50.108066, -122.932227),(50.108017, -122.932363),(50.107945, -122.932474),(50.107899, -122.932620),(50.107872, -122.932760),(50.107844, -122.932899),(50.107817, -122.933039),(50.107790, -122.933179),(50.107762, -122.933318),(50.107735, -122.933458),(50.107681, -122.933734),(50.107650, -122.933988),(50.107595, -122.934102),(50.107560, -122.934253),(50.107532, -122.934386),(50.107505, -122.934520),(50.107477, -122.934653),(50.107450, -122.934786),(50.107422, -122.934919),(50.107394, -122.935053),(50.107367, -122.935186),(50.107339, -122.935319),(50.107312, -122.935452),(50.107284, -122.935586),(50.107256, -122.935719),(50.107229, -122.935852),(50.107201, -122.935985),(50.107174, -122.936119),(50.107146, -122.936252),(50.107091, -122.936518),(50.107036, -122.936785),(50.106980, -122.937051),(50.106953, -122.937185),(50.106925, -122.937318),(50.106898, -122.937451),(50.106870, -122.937584),(50.106817, -122.937840),(50.106814, -122.938063),(50.106845, -122.938261),(50.106842, -122.938516),(50.106886, -122.938735),(50.106952, -122.938962),(50.107007, -122.939172),(50.107062, -122.939362),(50.107114, -122.939562),(50.107172, -122.939812),(50.107239, -122.940043),(50.107279, -122.940170),(50.107326, -122.940323),(50.107375, -122.940471),(50.107431, -122.940617),(50.107518, -122.940742),(50.107604, -122.940867),(50.107691, -122.940993),(50.107777, -122.941118),(50.107864, -122.941243),(50.107950, -122.941368),(50.108036, -122.941492),(50.108149, -122.941577),(50.108269, -122.941706),(50.108450, -122.941771),(50.108543, -122.941827),(50.108647, -122.941892),(50.108749, -122.941967),(50.108816, -122.942075),(50.108882, -122.942182),(50.108959, -122.942271),(50.109037, -122.942363),(50.109107, -122.942453),(50.109234, -122.942615),(50.109372, -122.942727),(50.109515, -122.942795),(50.109673, -122.942891),(50.109826, -122.942999),(50.109963, -122.943130),(50.110037, -122.943210),(50.110164, -122.943354),(50.110310, -122.943388),(50.110381, -122.943477),(50.110471, -122.943538),(50.110555, -122.943650),(50.110616, -122.943823),(50.110674, -122.943962),(50.110753, -122.944092),(50.110845, -122.944240),(50.110924, -122.944419),(50.110989, -122.944593),(50.111024, -122.944784),(50.111036, -122.944991),(50.111026, -122.945161),(50.111000, -122.945316),(50.110984, -122.945495),(50.110978, -122.945683),(50.110960, -122.945826),(50.110940, -122.946016),(50.110939, -122.946194),(50.110935, -122.946381),(50.110932, -122.946576),(50.110938, -122.946752),(50.110946, -122.946949),(50.110952, -122.947180),(50.110939, -122.947339),(50.110937, -122.947558),(50.110912, -122.947731),(50.110862, -122.947897),(50.110741, -122.947976),(50.110701, -122.948128),(50.110659, -122.948300),(50.110647, -122.948452),(50.110642, -122.948610),(50.110683, -122.948841),(50.110706, -122.948978),(50.110750, -122.949218),(50.110812, -122.949484),(50.110876, -122.949712),(50.110902, -122.949848),(50.110989, -122.950029),(50.111101, -122.950221),(50.111181, -122.950308),(50.111262, -122.950377),(50.111336, -122.950459),(50.111412, -122.950553),(50.111496, -122.950625),(50.111582, -122.950691),(50.111664, -122.950789),(50.111751, -122.950903),(50.111854, -122.951001),(50.111961, -122.951097),(50.112059, -122.951225),(50.112160, -122.951343),(50.112258, -122.951463),(50.112360, -122.951575),(50.112455, -122.951685),(50.112542, -122.951789),(50.112619, -122.951906),(50.112703, -122.951991),(50.112778, -122.952085),(50.112893, -122.952287),(50.112985, -122.952484),(50.113051, -122.952639),(50.113089, -122.952790),(50.113124, -122.952942),(50.113187, -122.953106),(50.113215, -122.953289),(50.113272, -122.953401),(50.113317, -122.953522)]
        
        var locations = [CLLocation]()
        let stride = 20 //the number of datapoints to skip between drawn locations, this cleans up the final line.
        for index in 0..<latlons.count where index%stride == 0
        {
            let latlon = latlons[index]
            locations.append(CLLocation(latitude: latlon.0, longitude: latlon.1))
        }
        
        terrainNode.addPolyline(coordinates: locations, radius: 20, color: .red)
        
        let lineB = terrainNode.addPolyline(coordinates: locations, startRadius: 30, endRadius: 80, startColor: .red, endColor: .yellow)
        lineB.position.y += 200
        
        let lineC = terrainNode.addPolyline(coordinates: locations, radii: [10, 50, 30], colors: [.red, .yellow, .orange], verticalOffset: 40)
        lineC.position.y += 400
    }
}
