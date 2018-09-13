import Foundation
import UIKit
import SceneKit
import ARKit
import MapboxSceneKit
import CoreLocation

/**
 Demonstrates placing a Mapbox TerrainNode in AR. The acual Mapbox SDK logic is in the `insert` function, while the rest
 is the boilerplate code needed to start up an AR session, enable plane tracking, place objects, and support gestures.
 **/
final class DemoARViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, UIGestureRecognizerDelegate {
    @IBOutlet private weak var arView: ARSCNView?
    @IBOutlet private weak var placeButton: UIButton?
    @IBOutlet private weak var moveImage: UIImageView?
    @IBOutlet private weak var messageView: UIVisualEffectView?
    @IBOutlet private weak var messageLabel: UILabel?

    private weak var terrain: SCNNode?
    private var planes: [UUID: SCNNode] = [UUID: SCNNode]()

    override func viewDidLoad() {
        super.viewDidLoad()

        arView!.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        arView!.session.delegate = self
        arView!.delegate = self
        if let camera = arView?.pointOfView?.camera {
            camera.wantsHDR = true
            camera.wantsExposureAdaptation = true
        }

        arView!.isUserInteractionEnabled = false
        setupGestures()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        restartTracking()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        arView?.session.pause()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - SCNSceneRendererDelegate

    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.updateFocusSquare()
        }
    }

    // MARK: - IBActions

    @IBAction func place(_ sender: AnyObject?) {
        let tapPoint = screenCenter
        var result = arView?.smartHitTest(tapPoint)
        if result == nil {
            result = arView?.smartHitTest(tapPoint, infinitePlane: true)
        }

        guard result != nil, let anchor = result?.anchor, let plane = planes[anchor.identifier] else {
            return
        }

        insert(on: plane, from: result!)
        arView?.debugOptions = []

        self.placeButton?.isHidden = true
    }

    private func insert(on plane: SCNNode, from hitResult: ARHitTestResult) {
        //Set up initial terrain and materials
        let terrainNode = TerrainNode(minLat: 53.394747374316, maxLat: 53.422495172318,
                                      minLon: -1.23018147712619, maxLon: -1.18246149810173)

        //Note: Again, you don't have to do this loading in-scene. If you know the area of the node to be fetched, you can
        //do this in the background while AR plane detection is still working so it is ready by the time
        //your user selects where to add the node in the world.

        //We're going to scale the node dynamically based on the size of the node and how far away the detected plane is
        let scale = Float(0.333 * hitResult.distance) / terrainNode.boundingSphere.radius
        terrainNode.transform = SCNMatrix4MakeScale(scale, scale, scale)
        terrainNode.position = SCNVector3(hitResult.worldTransform.columns.3.x, hitResult.worldTransform.columns.3.y, hitResult.worldTransform.columns.3.z)
        terrainNode.geometry?.materials = defaultMaterials()
        arView!.scene.rootNode.addChildNode(terrainNode)
        terrain = terrainNode
        terrainNode.fetchTerrainAndTexture(minWallHeight: 50.0, enableDynamicShadows: true, textureStyle: "mapbox/satellite-v9", heightProgress: nil, heightCompletion: { fetchError in
            if let fetchError = fetchError {
                NSLog("Terrain load failed: \(fetchError.localizedDescription)")
            } else {
                NSLog("Terrain load complete")
            }
        }, textureProgress: nil) { image, fetchError in
            if let fetchError = fetchError {
                NSLog("Texture load failed: \(fetchError.localizedDescription)")
            }
            if image != nil {
                NSLog("Texture load complete")
                terrainNode.geometry?.materials[4].diffuse.contents = image
            }
        }

        arView!.isUserInteractionEnabled = true
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

    // MARK: - ARSCNViewDelegate

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }

        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        let planeNode = SCNNode(geometry: plane)
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        planeNode.eulerAngles.x = -.pi / 2
        planeNode.isHidden = true
        node.addChildNode(planeNode)

        planes[anchor.identifier] = planeNode

        DispatchQueue.main.async {
            self.setMessage("")
            if self.terrain == nil {
                self.placeButton?.isHidden = false
                self.moveImage?.isHidden = true
            }
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as?  ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else { return }

        planeNode.simdPosition = float3(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        plane.width = CGFloat(planeAnchor.extent.x)
        plane.height = CGFloat(planeAnchor.extent.z)

        planes[anchor.identifier] = planeNode
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARPlaneAnchor else { return }
        node.removeFromParentNode()
        planes.removeValue(forKey: anchor.identifier)

        if planes.isEmpty {
            DispatchQueue.main.async {
                self.terrain?.removeFromParentNode()
                self.moveImage?.isHidden = false
                self.arView?.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
            }
        }
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }

    // MARK: - ARSessionObserver

    func sessionWasInterrupted(_ session: ARSession) {
        setMessage("Session was interrupted")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        setMessage("Session interruption ended")

        restartTracking()
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        setMessage("Session failed: \(error.localizedDescription)")

        restartTracking()
    }

    // MARK: - Focus Square

    var focusSquare: FocusSquare?

    func setupFocusSquare() {
        focusSquare?.isHidden = true
        focusSquare?.removeFromParentNode()
        focusSquare = FocusSquare()
        arView?.scene.rootNode.addChildNode(focusSquare!)
    }

    func updateFocusSquare() {
        guard let arView = arView else { return }

        if !arView.isUserInteractionEnabled, let result = arView.smartHitTest(screenCenter, infinitePlane: true), let planeAnchor = result.anchor as? ARPlaneAnchor {
            let position: SCNVector3 = SCNVector3(result.worldTransform.columns.3.x, result.worldTransform.columns.3.y, result.worldTransform.columns.3.z)
            focusSquare?.update(for: position, planeAnchor: planeAnchor, camera: arView.session.currentFrame?.camera)
            focusSquare?.unhide()
        } else {
            focusSquare?.hide()
        }
    }

    // MARK: - Message Helpers

    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        let message: String

        switch trackingState {
        case .normal where frame.anchors.isEmpty:
            message = "Move the device around to detect flat surfaces."

        case .notAvailable:
            message = "Tracking unavailable."

        case .limited(.excessiveMotion):
            message = "Move the device more slowly."

        case .limited(.insufficientFeatures):
            message = "Point the device at an area with visible surface detail, or improve lighting conditions."

        case .limited(.initializing):
            message = "Initializing AR session."

        default:
            message = ""
        }

        setMessage(message)
    }

    private func setMessage(_ message: String) {
        self.messageLabel?.text = message
        self.messageView?.isHidden = message.isEmpty
    }


    // MARK: - UIGestureRecognizer

    private func setupGestures() {
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        rotate.delegate = self
        arView?.addGestureRecognizer(rotate)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        arView?.addGestureRecognizer(pinch)
        let drag = UIPanGestureRecognizer(target: self, action: #selector(handleDrag(_:)))
        drag.delegate = self
        drag.minimumNumberOfTouches = 1
        drag.maximumNumberOfTouches = 1
        arView?.addGestureRecognizer(drag)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer.numberOfTouches == otherGestureRecognizer.numberOfTouches
    }

    private var lastDragResult: ARHitTestResult?
    @objc fileprivate func handleDrag(_ gesture: UIRotationGestureRecognizer) {
        guard let terrain = terrain else {
            return
        }

        let point = gesture.location(in: gesture.view!)
        if let result = arView?.smartHitTest(point, infinitePlane: true) {
            if let lastDragResult = lastDragResult {
                let vector: SCNVector3 = SCNVector3(result.worldTransform.columns.3.x - lastDragResult.worldTransform.columns.3.x,
                                                    result.worldTransform.columns.3.y - lastDragResult.worldTransform.columns.3.y,
                                                    result.worldTransform.columns.3.z - lastDragResult.worldTransform.columns.3.z)
                terrain.position += vector
            }
            lastDragResult = result
        }

        if gesture.state == .ended {
            self.lastDragResult = nil
        }
    }

    @objc fileprivate func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard let terrain = terrain else {
            return
        }
        var normalized = (terrain.eulerAngles.y - Float(gesture.rotation)).truncatingRemainder(dividingBy: 2 * .pi)
        normalized = (normalized + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
        if normalized > .pi {
            normalized -= 2 * .pi
        }
        terrain.eulerAngles.y = normalized
        gesture.rotation = 0
    }

    private var startScale: Float?
    @objc fileprivate func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let terrain = terrain else {
            return
        }
        if gesture.state == UIGestureRecognizerState.began {
            startScale = terrain.scale.x
        }
        guard let startScale = startScale else {
            return
        }
        let newScale: Float = startScale * Float(gesture.scale)
        terrain.scale = SCNVector3(newScale, newScale, newScale)
        if gesture.state == .ended {
            self.startScale = nil
        }
    }

    //MARK: - Misc Helpers

    private func restartTracking() {
        terrain?.removeFromParentNode()
        for (_, plane) in planes {
            plane.removeFromParentNode()
        }
        planes.removeAll()

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.isLightEstimationEnabled = true

        arView?.session.run(configuration, options: [.removeExistingAnchors])
        arView?.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        arView?.isUserInteractionEnabled = false
        placeButton?.isHidden = true
        moveImage?.isHidden = false

        setupFocusSquare()

        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }

    private var screenCenter: CGPoint {
        let bounds = arView!.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }

    private var session: ARSession {
        return arView!.session
    }
    
    // MARK: - dummy data, should be handled in GPX
    private var locations: [CLLocation] {
        let latLons = [(53.418990994368, -1.20174496401449), (53.418316994367, -1.20159196401519), (53.417416994366, -1.20115396401606), (53.416292994365, -1.19994496401657), (53.415355994364, -1.19954296401747), (53.414853994363, -1.19860096401751), (53.413263994361, -1.19634396401802), (53.412633994360, -1.19494996401781), (53.411907994359, -1.19393396401803), (53.411386994358, -1.19324496401831), (53.410910994358, -1.19309696401875), (53.410621994358, -1.19271896401882), (53.410317994357, -1.19183396401865), (53.409739994356, -1.19116396401891), (53.409335994356, -1.19082296401916), (53.408600994355, -1.19006896401970), (53.407837994354, -1.18988196402041), (53.407308994354, -1.18955196402073), (53.406812994353, -1.18866196402084), (53.406295994352, -1.18710996402053), (53.406305994353, -1.18859296402137), (53.406491994353, -1.18909596402142), (53.406350994353, -1.18986696402210), (53.405997994352, -1.18845096402165), (53.405644994352, -1.18717496402136), (53.405118994351, -1.18650396402147), (53.404996994351, -1.18627896402157), (53.404535994351, -1.18743996402271), (53.404348994350, -1.18767896402305), (53.403635994350, -1.18702096402351), (53.402939994349, -1.18595196402365), (53.402160994348, -1.18496296402407), (53.401318994347, -1.18380096402424), (53.401025994346, -1.18287296402409), (53.400588994346, -1.18304696402467), (53.399930994346, -1.18451696402637), (53.399561994346, -1.18543996402722), (53.399163994345, -1.18668696402836), (53.398588994345, -1.18801596402985), (53.398044994345, -1.18942196403128), (53.397810994345, -1.19019496403197), (53.397792994345, -1.19070096403222), (53.397950994345, -1.19164096403268), (53.398383994346, -1.19240896403261), (53.398217994346, -1.19417496403380), (53.397774994346, -1.19571896403519), (53.397412994346, -1.19768096403670), (53.396972994346, -1.19910296403808), (53.396597994346, -1.19995596403897), (53.396151994346, -1.20030496403964), (53.396576994347, -1.20369996404120), (53.397016994349, -1.20791496404302), (53.396461994349, -1.21074396404536), (53.396150994349, -1.21349896404721), (53.396150994349, -1.21502596404811), (53.395550994349, -1.21505396404888), (53.395363994349, -1.21667196405004), (53.394935994349, -1.21674896405053), (53.394662994349, -1.21719896405111), (53.394738994349, -1.21841096405166), (53.395341994350, -1.21979596405181), (53.395592994350, -1.22068196405201), (53.395500994351, -1.22174796405282), (53.395402994351, -1.22271796405344), (53.395313994351, -1.22424696405439), (53.395169994351, -1.22622096405579), (53.395217994352, -1.22799196405670), (53.395262994352, -1.22845396405685), (53.396534994354, -1.22997496405629), (53.397380994354, -1.23013396405543), (53.399058994356, -1.22909996405298), (53.401801994358, -1.22830896404948), (53.403680994360, -1.22773396404698), (53.404211994360, -1.22754096404617), (53.404819994361, -1.22790496404568), (53.405805994361, -1.22716296404425), (53.406723994362, -1.22637796404277), (53.408701994364, -1.22578396404010), (53.411470994366, -1.22418896403608), (53.413301994368, -1.22420796403398), (53.414396994368, -1.22258096403172), (53.415357994369, -1.22106196402978), (53.416014994369, -1.22036896402868), (53.416147994370, -1.22076896402875), (53.416915994370, -1.21926996402702), (53.418663994371, -1.21537096402280), (53.419009994371, -1.21418596402167), (53.419145994370, -1.21173896402016), (53.419608994370, -1.20997496401867), (53.420988994371, -1.20816896401602), (53.421878994372, -1.20706896401429), (53.421799994371, -1.20622396401394), (53.422651994372, -1.20570996401264)]
        var locations = [CLLocation]()
        for latlon in latLons {
            locations.append(CLLocation(latitude: latlon.0, longitude: latlon.1))
        }
        return locations
    }

}

fileprivate extension ARSCNView {
    func smartHitTest(_ point: CGPoint,
                      infinitePlane: Bool = false,
                      objectPosition: float3? = nil,
                      allowedAlignments: [ARPlaneAnchor.Alignment] = [.horizontal]) -> ARHitTestResult? {

        // Perform the hit test.
        let results: [ARHitTestResult]!
        if #available(iOS 11.3, *) {
            results = hitTest(point, types: [.existingPlaneUsingGeometry, .estimatedHorizontalPlane])
        } else {
            results = hitTest(point, types: [.estimatedHorizontalPlane])
        }

        // 1. Check for a result on an existing plane using geometry.
        if #available(iOS 11.3, *) {
            if let existingPlaneUsingGeometryResult = results.first(where: { $0.type == .existingPlaneUsingGeometry }),
                let planeAnchor = existingPlaneUsingGeometryResult.anchor as? ARPlaneAnchor, allowedAlignments.contains(planeAnchor.alignment) {
                return existingPlaneUsingGeometryResult
            }
        }

        if infinitePlane {
            // 2. Check for a result on an existing plane, assuming its dimensions are infinite.
            //    Loop through all hits against infinite existing planes and either return the
            //    nearest one (vertical planes) or return the nearest one which is within 5 cm
            //    of the object's position.
            let infinitePlaneResults = hitTest(point, types: .existingPlane)

            for infinitePlaneResult in infinitePlaneResults {
                if let planeAnchor = infinitePlaneResult.anchor as? ARPlaneAnchor, allowedAlignments.contains(planeAnchor.alignment) {
                    // For horizontal planes we only want to return a hit test result
                    // if it is close to the current object's position.
                    if let objectY = objectPosition?.y {
                        let planeY = infinitePlaneResult.worldTransform.translation.y
                        if objectY > planeY - 0.05 && objectY < planeY + 0.05 {
                            return infinitePlaneResult
                        }
                    } else {
                        return infinitePlaneResult
                    }
                }
            }
        }

        // 3. As a final fallback, check for a result on estimated planes.
        return results.first(where: { $0.type == .estimatedHorizontalPlane })
    }
}

fileprivate extension float4x4 {
    /**
     Treats matrix as a (right-hand column-major convention) transform matrix
     and factors out the translation component of the transform.
     */
    var translation: float3 {
        get {
            let translation = columns.3
            return float3(translation.x, translation.y, translation.z)
        }
        set(newValue) {
            columns.3 = float4(newValue.x, newValue.y, newValue.z, columns.3.w)
        }
    }

    /**
     Factors out the orientation component of the transform.
     */
    var orientation: simd_quatf {
        return simd_quaternion(self)
    }

    /**
     Creates a transform matrix with a uniform scale factor in all directions.
     */
    init(uniformScale scale: Float) {
        self = matrix_identity_float4x4
        columns.0.x = scale
        columns.1.y = scale
        columns.2.z = scale
    }
}

