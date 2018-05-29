import Foundation
import SceneKit
import CoreLocation

/**
 The `TerrainNode` object represents the easiest way to generate terrain in SceneKit (if you prefer a custom solution, see the methods on `MapboxImageAPI`
 to help get you started with a custom solution using the base data.
 **/
@objc(MBTerrainNode)
open class TerrainNode: SCNNode {
    /**
     Callback typealias for when the new geometry has been loaded based on RGB heightmaps.
     **/
    public typealias TerrainLoadCompletion = () -> Void

    /**
     Convenience tuple represending the bounds of the latitude post-initialization.
    **/
    let latBounds: (CLLocationDegrees, CLLocationDegrees)

    /**
     Convenience tuple represending the bounds of the longitude post-initialization.
     **/
    let lonBounds: (CLLocationDegrees, CLLocationDegrees)

    /**
     Convenience tuple represending the bounds of altitude after heightmaps have been loaded.
     **/
    private(set) var altitudeBounds: (CLLocationDistance, CLLocationDistance) = (0.0, 1.0)

    fileprivate static let rgbTileSize = CGSize(width: 256, height: 256)
    fileprivate static let styleTileSize = CGSize(width: 256, height: 256)

    private let terrainZoomLevel: Int

    fileprivate let terrainSize: CGSize
    fileprivate let metersPerLat: Double
    fileprivate let metersPerLon: Double
    fileprivate let metersPerX: Double
    fileprivate let metersPerY: Double
    fileprivate var terrainHeights = [[Double]]()
    private let api = MapboxImageAPI()

    fileprivate var pendingFetches = [UUID]()
    private static let queue = DispatchQueue(label: "com.mapbox.scenekit.processing", attributes: [.concurrent])

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    public init(minLat: CLLocationDegrees, maxLat: CLLocationDegrees, minLon: CLLocationDegrees, maxLon: CLLocationDegrees) {
        assert(minLat >= -90.0 && minLat <= 90.0 && maxLat >= -90.0 && maxLat <= 90.0, "lats must be between -90.0 and 90.0")
        assert(minLon >= -180.0 && minLon <= 180.0 && maxLon >= -180.0 && maxLon <= 180.0, "lons must be between -180.0 and 180.0")
        assert(minLat < maxLat, "minLat must be less than maxLat")
        assert(minLon < maxLon, "minLon must be less than maxLon")

        latBounds = (minLat, maxLat)
        lonBounds = (minLon, maxLon)
        metersPerLat = 1 / Math.metersToDegreesForLat(at: maxLon)
        metersPerLon = 1 / Math.metersToDegreesForLon(at: maxLat)

        //TODO: Calculate ideal zoom level based on node size
        //      Based on the examples in the bundled demo project, I'd expect this to return a value closer to 12 (or less), but was getting 16.
        //      Confirm math logic with the react team. Ported logic commented out below.

//        let corners = [(minLat, maxLon), (maxLat, minLon)] //se, nw
//        let cornerTiles = corners.map({ Math.latLng2tile(lat: $0.0, lon: $0.1, zoom: 22, tileSize: TerrainNode.rgbTileSize) })
//        let tileExtent = max(abs(cornerTiles.first!.xPos - cornerTiles.last!.xPos), abs(cornerTiles.first!.yPos - cornerTiles.last!.yPos))
//        let base = log(tileExtent) / log(2)
//        terrainZoomLevel = Int(floor(22 - base + 0.5))
        terrainZoomLevel = 12

        let bounding = MapboxImageAPI.tiles(zoom: terrainZoomLevel, latBounds: latBounds, lonBounds: lonBounds, tileSize: TerrainNode.rgbTileSize)
        terrainSize = CGSize(width: CGFloat(bounding.xs.count) * TerrainNode.rgbTileSize.width - bounding.insets.left - bounding.insets.right,
                             height: CGFloat(bounding.ys.count) * TerrainNode.rgbTileSize.height - bounding.insets.top - bounding.insets.bottom)
        metersPerX = Double(abs(lonBounds.1 - lonBounds.0) * metersPerLon) / Double(terrainSize.width)
        metersPerY = Double(abs(latBounds.1 - latBounds.0) * metersPerLat) / Double(terrainSize.height)

        super.init()

        name = "Terrain"
        geometry = SCNBox(width: CGFloat(metersPerX) * CGFloat(terrainSize.width), height: 10.0, length: CGFloat(metersPerY) * CGFloat(terrainSize.height), chamferRadius: 0.0)
        centerPivot()
    }

    deinit {
        for task in pendingFetches {
            api.cancelRequestWithID(task)
        }
    }

    private func centerPivot() {
        var min = SCNVector3Zero
        var max = SCNVector3Zero
        self.__getBoundingBoxMin(&min, max: &max)
        self.pivot = SCNMatrix4MakeTranslation(
            min.x + (max.x - min.x) / 2,
            min.y,
            min.z + (max.z - min.z) / 2
        )
    }

    //MARK: - Public API

    /**
     Will return the local position relative to the terrain node for a given lat/lon/alt.

     Note: the returned position should be converted from the terrain local space to the world space (or another node's corrdinate space, as needed).
    **/
    @objc
    public func positionForLocation(_ location: CLLocation) -> SCNVector3 {
        let xz = coordinates(location: location)
        if let z = TerrainNode.height(heights: terrainHeights, x: xz.x, z: xz.z, metersPerX: metersPerX, metersPerY: metersPerY) {
            return SCNVector3(xz.x, Float(max(z, location.altitude)), xz.z)
        } else {
            return SCNVector3(xz.x, 0.0, xz.z)
        }
    }

    /**
     Begins the fetch of terrain-rgb data throught the mapbox API, and then updates the geometry to repersent a to-scale model of the terrain at this location.

     `minWallHeight`: Padding amount (in meters) of the walls beyond the returned altitude minumum for the region.
     `enableDynamicShadows`: Depending on your applied texture / style, you may want to enable dynamic shadowing based on the contour of the terrain for interaction with Scene Kit lighting.
     **/
    @objc
    public func fetchTerrainHeights(minWallHeight: CLLocationDistance = 0.0, enableDynamicShadows shadows: Bool = false, progress: MapboxImageAPI.TileLoadProgressCallback? = nil, completion: @escaping TerrainLoadCompletion) {
        let latBounds = self.latBounds
        let lonBounds = self.lonBounds
        let terrainZoomLevel = self.terrainZoomLevel
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let taskID = self?.api.image(forTileset: "mapbox.terrain-rgb", zoomLevel: terrainZoomLevel, minLat: latBounds.0, maxLat: latBounds.1, minLon: lonBounds.0, maxLon: lonBounds.1, format: MapboxImageAPI.TileImageFormatPNG, progress: progress, completion: { image in
                TerrainNode.queue.async {
                    if let image = image {
                        self?.applyTerrainHeightmap(image, withWallHeight: minWallHeight, enableShadows: shadows)
                    }
                    DispatchQueue.main.async(execute: completion)
                }
            }) {
                self?.pendingFetches.append(taskID)
            }
        }
    }

    /**
     Fetches an image representing a style (either mapbox or user created) to cover this terrain node. It is up to the caller to apply it as a material component, but this gives the
     caller the opportunity to modify the image or apply it as something other then default diffuse contents.

     For the simplist usage, you'll want to apply it as the diffuse contents in position 4 (the top): `myRerrainNode.geometry?.materials[4].diffuse.contents = image`.
    **/
    @objc
    public func fetchTerrainTexture(_ style: String, zoom: Int, progress: MapboxImageAPI.TileLoadProgressCallback? = nil, completion: @escaping MapboxImageAPI.TileLoadCompletion) {
        let latBounds = self.latBounds
        let lonBounds = self.lonBounds
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let taskID = self?.api.image(forStyle: style, zoomLevel: zoom, minLat: latBounds.0, maxLat: latBounds.1, minLon: lonBounds.0, maxLon: lonBounds.1, progress: progress, completion: completion) {
                self?.pendingFetches.append(taskID)
            }
        }
    }

    //MARK: - Geometry Creation

    private func applyTerrainHeightmap(_ image: UIImage, withWallHeight wallHeight: CLLocationDistance? = nil, enableShadows shadows: Bool) {
        guard let pixelData = image.cgImage?.dataProvider?.data, let terrainData = CFDataGetBytePtr(pixelData) else {
            NSLog("Couldn't get CGImage color data for terrain")
            return
        }

        var minZ = Double.greatestFiniteMagnitude
        var maxZ = Double.leastNormalMagnitude
        var newTerrainHeights = [[Double]]()
        newTerrainHeights.reserveCapacity(Int(terrainSize.height))

        for y in 0 ..< Int(terrainSize.height) {
            var rowData = [Double]()
            rowData.reserveCapacity(Int(terrainSize.width))
            for x in 0 ..< Int(terrainSize.width) {
                guard let z = TerrainNode.heightFromImage(x: x, y: y, terrainData: terrainData, terrainSize: terrainSize) else {
                    NSLog("Couldn't get Z data for {\(x),\(y)}")
                    continue
                }
                rowData.append(z)
                minZ = min(z, minZ)
                maxZ = max(z, maxZ)
            }
            newTerrainHeights.append(rowData)
        }

        terrainHeights = newTerrainHeights.map({ $0.map({ $0 - minZ + (wallHeight ?? 0.0) })})
        altitudeBounds = (minZ, maxZ)

        var vertices = [SCNVector3]()
        var normals = [SCNVector3]()
        var uvList: [vector_float2] = []
        var sources = [SCNGeometrySource]()
        var elements = [SCNGeometryElement]()

        //Adding these geometries in the same order they'd appear in an SCNBox, so previously applied materials stay on the same side / order
        if let wallHeight = wallHeight {
            let south = createGeometryForWall(xs: [Int](0..<Int(terrainSize.width)),
                                              ys: [Int(terrainSize.height) - 1],
                                              normal: SCNVector3Make(0, 0, -1),
                                              maxHeight: Float(maxZ + wallHeight - minZ),
                                              vertexOffset: vertices.count)
            vertices.append(contentsOf: south.vertices)
            normals.append(contentsOf: south.normals)
            uvList.append(contentsOf: south.uvList)
            elements.append(south.element)
            
            let east = createGeometryForWall(xs: [Int(terrainSize.width) - 1],
                                             ys: [Int](0..<Int(terrainSize.height)),
                                             normal: SCNVector3Make(1, 0, 0),
                                             maxHeight: Float(maxZ + wallHeight - minZ),
                                             vertexOffset: vertices.count)
            vertices.append(contentsOf: east.vertices)
            normals.append(contentsOf: east.normals)
            uvList.append(contentsOf: east.uvList)
            elements.append(east.element)

            let north = createGeometryForWall(xs: [Int](0..<Int(terrainSize.width)),
                                              ys: [0],
                                              normal: SCNVector3Make(0, 0, -1),
                                              maxHeight: Float(maxZ + wallHeight - minZ),
                                              vertexOffset: vertices.count)
            vertices.append(contentsOf: north.vertices)
            normals.append(contentsOf: north.normals)
            uvList.append(contentsOf: north.uvList)
            elements.append(north.element)

            let west = createGeometryForWall(xs: [0],
                                             ys: [Int](0..<Int(terrainSize.height)),
                                             normal: SCNVector3Make(1, 0, 0),
                                             maxHeight: Float(maxZ + wallHeight - minZ),
                                             vertexOffset: vertices.count)
            vertices.append(contentsOf: west.vertices)
            normals.append(contentsOf: west.normals)
            uvList.append(contentsOf: west.uvList)
            elements.append(west.element)
        }

        let top = createTopGeometry(vertexOffset: vertices.count, enableShadows: shadows)
        vertices.append(contentsOf: top.vertices)
        normals.append(contentsOf: top.normals)
        uvList.append(contentsOf: top.uvList)
        elements.append(top.element)

        if wallHeight != nil {
            let bottom = createGeometryForBottom(vertexOffset: vertices.count)
            vertices.append(contentsOf: bottom.vertices)
            normals.append(contentsOf: bottom.normals)
            uvList.append(contentsOf: bottom.uvList)
            elements.append(bottom.element)
        }

        let float: Float = 0.0
        let sizeOfFloat = MemoryLayout.size(ofValue: float)
        let vec2: vector_float2 = vector2(0, 0)
        let sizeOfVecFloat = MemoryLayout.size(ofValue: vec2)

        sources.append(SCNGeometrySource(vertices: vertices))
        sources.append(SCNGeometrySource(normals: normals))
        let uvData = NSData(bytes: uvList, length: uvList.count * sizeOfVecFloat)
        let uvSource = SCNGeometrySource(data: uvData as Data,
                                         semantic: SCNGeometrySource.Semantic.texcoord,
                                         vectorCount: uvList.count,
                                         usesFloatComponents: true,
                                         componentsPerVector: 2,
                                         bytesPerComponent: sizeOfFloat,
                                         dataOffset: 0,
                                         dataStride: sizeOfVecFloat)
        sources.append(uvSource)

        let originalPosition = position
        let originalMaterials = geometry?.materials ?? [SCNMaterial]()
        
        geometry = SCNGeometry(sources: sources, elements: elements)
        geometry?.materials = originalMaterials
        centerPivot()
        position = originalPosition
    }

    private func createTopGeometry(vertexOffset: Int, enableShadows: Bool) -> (element: SCNGeometryElement, vertices: [SCNVector3], normals: [SCNVector3], uvList: [vector_float2]) {
        var vertices = [SCNVector3]()
        vertices.reserveCapacity(Int(terrainSize.height * terrainSize.width))
        var normals = [SCNVector3](repeating: SCNVector3(0, 1, 0), count: Int(terrainSize.height * terrainSize.width))
        var uvList: [vector_float2] = []
        uvList.reserveCapacity(Int(terrainSize.height * terrainSize.width))
        let cint: CInt = 0
        let sizeOfCInt = MemoryLayout.size(ofValue: cint)

        let geometryData = NSMutableData()
        for y in 0..<Int(terrainSize.height) {
            let previousRowStart = (y - 1) * Int(terrainSize.width)
            let currentRowStart = y * Int(terrainSize.width)

            for x in 0..<Int(terrainSize.width) {
                guard let z = TerrainNode.height(heights: terrainHeights, x: x, y: y), let xz = coordinates(imageX: x, imageY: y) else {
                    NSLog("Couldn't coordinates for \(x),\(y)")
                    continue
                }

                vertices.append(SCNVector3Make(xz.x, Float(z), xz.z))

                //texture support
                uvList.append(vector_float2(Float(Float(x) / Float(terrainSize.width)), Float(Float(y) / Float(terrainSize.height))))

                //past first row, build the faces as we go (skipping first column)
                if y > 0 && x > 0 {
                    let globalBytes: [CInt] = [CInt(previousRowStart + x - 1 + vertexOffset), CInt(currentRowStart + x + vertexOffset), CInt(previousRowStart + x + vertexOffset),
                                         CInt(previousRowStart + x - 1 + vertexOffset), CInt(currentRowStart + x - 1 + vertexOffset), CInt(currentRowStart + x + vertexOffset)]
                    geometryData.append(globalBytes, length: sizeOfCInt * 6)

                    if (enableShadows) {
                        let bytes: [CInt] = [CInt(previousRowStart + x - 1), CInt(currentRowStart + x), CInt(previousRowStart + x),
                                             CInt(previousRowStart + x - 1), CInt(currentRowStart + x - 1), CInt(currentRowStart + x)]
                        TerrainNode.updateNormals(&normals, vertices: vertices, bytes: bytes)
                    }
                }
            }
        }

        for i in 0..<normals.count {
            normals[i] = SCNVector3Normalize(vector: normals[i])
        }

        return (element: SCNGeometryElement(data: geometryData as Data,
                                            primitiveType: .triangles,
                                            primitiveCount: (Int(terrainSize.height) - 1) * (Int(terrainSize.width) - 1) * 2,
                                            bytesPerIndex: sizeOfCInt),
                vertices: vertices,
                normals: normals,
                uvList: uvList)
    }

    private func createGeometryForBottom(vertexOffset: Int) -> (element: SCNGeometryElement, vertices: [SCNVector3], normals: [SCNVector3], uvList: [vector_float2]) {
        let bottomGeometryData = NSMutableData()
        var vertices = [SCNVector3]()
        vertices.reserveCapacity(4)
        var uvList: [vector_float2] = []
        uvList.reserveCapacity(4)

        let minXZ = coordinates(imageX: 0, imageY: 0)!
        let maxXZ = coordinates(imageX: Int(terrainSize.width) - 1, imageY: Int(terrainSize.height) - 1)!
        vertices.append(SCNVector3Make(minXZ.x, Float(0.0), minXZ.z))
        uvList.append(vector_float2(Float(0.0), Float(0.0)))
        vertices.append(SCNVector3Make(maxXZ.x, Float(0.0), minXZ.z))
        uvList.append(vector_float2(Float(1.0), Float(0.0)))
        vertices.append(SCNVector3Make(minXZ.x, Float(0.0), maxXZ.z))
        uvList.append(vector_float2(Float(0.0), Float(1.0)))
        vertices.append(SCNVector3Make(maxXZ.x, Float(0.0), maxXZ.z))
        uvList.append(vector_float2(Float(1.0), Float(1.0)))

        let cint: CInt = 0
        let sizeOfCInt = MemoryLayout.size(ofValue: cint)

        let bottomEnd = vertices.count - 1 + vertexOffset
        let bytes: [CInt] = [CInt(bottomEnd - 3), CInt(bottomEnd), CInt(bottomEnd - 1),
                             CInt(bottomEnd - 3), CInt(bottomEnd - 2), CInt(bottomEnd)]
        bottomGeometryData.append(bytes, length: sizeOfCInt * 6)

        return (element: SCNGeometryElement(data: bottomGeometryData as Data,
                                            primitiveType: .triangles,
                                            primitiveCount: (vertices.count / 2 - 1) * 2,
                                            bytesPerIndex: sizeOfCInt),
                vertices: vertices,
                normals: [SCNVector3](repeating: SCNVector3(0, -1, 0), count: vertices.count),
                uvList: uvList)
    }

    private func createGeometryForWall(xs: [Int], ys: [Int], normal: SCNVector3, maxHeight: Float, vertexOffset: Int) -> (element: SCNGeometryElement, vertices: [SCNVector3], normals: [SCNVector3], uvList: [vector_float2]) {
        let sideGeometryData = NSMutableData()
        var vertices = [SCNVector3]()
        vertices.reserveCapacity(xs.count * ys.count * 2)
        var uvList: [vector_float2] = []
        uvList.reserveCapacity(xs.count * ys.count * 2)
        let cint: CInt = 0
        let sizeOfCInt = MemoryLayout.size(ofValue: cint)

        var textureX: Float = 0
        let length = Float(max(xs.count, ys.count))
        let lengthInMeters = Float(!xs.isEmpty ? metersPerX : metersPerY) * Float(length)
        let heightRatio: Float = maxHeight / lengthInMeters

        for x in xs {
            for y in ys {
                guard let z = TerrainNode.height(heights: terrainHeights, x: x, y: y), let xz = coordinates(imageX: x, imageY: y) else {
                    NSLog("Couldn't coordinates for \(x),\(y)")
                    continue
                }

                let vertexBottom = SCNVector3Make(xz.x, 0.0, xz.z)
                vertices.append(vertexBottom)
                let vertexTop = SCNVector3Make(xz.x, Float(z), xz.z)
                vertices.append(vertexTop)

                uvList.append(vector_float2(Float(textureX / length), Float(Float(z) / maxHeight) * heightRatio))
                uvList.append(vector_float2(Float(textureX / length), Float(0)))

                textureX += 1
            }
        }

        for x in 0..<vertices.count where x > 2 && x % 2 != 0 {
            let bytes: [CInt] = [CInt(x + vertexOffset - 3), CInt(x + vertexOffset), CInt(x - 1 + vertexOffset),
                                 CInt(x + vertexOffset - 3), CInt(x - 2 + vertexOffset), CInt(x + vertexOffset)]
            sideGeometryData.append(bytes, length: sizeOfCInt * 6)
        }

        return (element: SCNGeometryElement(data: sideGeometryData as Data,
                                            primitiveType: .triangles,
                                            primitiveCount: (vertices.count / 2 - 1) * 2,
                                            bytesPerIndex: sizeOfCInt),
                vertices: vertices,
                normals: [SCNVector3](repeating: normal, count: vertices.count),
                uvList: uvList)
    }
}

//MARK: - Helpers

extension TerrainNode {
    fileprivate func coordinates(imageX: Int, imageY: Int) -> (x: Float, z: Float)? {
        return (x: Float(imageX) * Float(metersPerX), z: Float(imageY) * Float(metersPerY))
    }

    fileprivate func coordinates(location: CLLocation) -> (x: Float, z: Float) {
        let x = Float(location.coordinate.longitude - lonBounds.0) * Float(metersPerLon)
        let z = Float(latBounds.1 - location.coordinate.latitude) * Float(metersPerLat)
        return (x: Float(x), z: Float(z))
    }

    fileprivate static func updateNormals(_ normals: inout [SCNVector3], vertices: [SCNVector3], bytes: [CInt]) {
        //normal calculation for the faces. We'll normalize the final value later
        //http://www.iquilezles.org/www/articles/normals/normals.htm

        //TODO: I'm not 100% sure on this, I'm noticing weird shadowing (only noticable with less-complex texture images, like solid colors)
        let face1e1 = vertices[Int(bytes[0])] - vertices[Int(bytes[1])]
        let face1e2 = vertices[Int(bytes[2])] - vertices[Int(bytes[1])]
        let face2e1 = vertices[Int(bytes[3])] - vertices[Int(bytes[4])]
        let face2e2 = vertices[Int(bytes[5])] - vertices[Int(bytes[4])]
        let face1no = SCNVector3CrossProduct(left: face1e2, right: face1e1)
        let face2no = SCNVector3CrossProduct(left: face2e2, right: face2e1)

        for i in [bytes[0], bytes[1], bytes[2]] {
            normals[Int(i)] += face1no
        }
        for i in [bytes[3], bytes[4], bytes[5]] {
            normals[Int(i)] += face2no
        }
    }

    fileprivate static func height(heights: [[Double]], x: Float, z: Float, metersPerX: Double, metersPerY: Double) -> Double? {
        let imageX: Int = Int(x / Float(metersPerX))
        let imageY: Int = Int(z / Float(metersPerY))
        guard let imageHeight = TerrainNode.height(heights: heights, x: imageX, y: imageY) else {
            return nil
        }
        return imageHeight
    }

    fileprivate static func height(heights: [[Double]], x: Int, y: Int) -> Double? {
        guard heights.count > y, y >= 0, heights[y].count > x, x >= 0 else {
            return nil
        }
        return heights[y][x]
    }

    fileprivate static func heightFromImage(x: Int, y: Int, terrainData: UnsafePointer<UInt8>, terrainSize: CGSize) -> Double? {
        guard x < Int(terrainSize.width) && y < Int(terrainSize.height) else {
            return nil
        }

        let pixelInfo: Int = ((Int(terrainSize.width) * Int(y)) + Int(x)) * 4

        let r = Float(terrainData[pixelInfo])
        let g = Float(terrainData[pixelInfo + 1])
        let b = Float(terrainData[pixelInfo + 2])

        let terrainHeight = -10000 + ((r * 256 * 256 + g * 256 + b) * 0.1)
        return Double(terrainHeight)
    }
}
