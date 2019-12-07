import Foundation
import UIKit
import CoreLocation
import MapboxMobileEvents

/**
`MapboxImageAPI` provides a convenience wrapper for fetching tiles through the Mapbox web APIs.
 **/
@objc(MBImageAPI)
public final class MapboxImageAPI: NSObject {
    /**
     Image format for tileset fetcher, PNG uncompressed.
     **/
    @objc static let TileImageFormatPNG = "pngraw"

    /**
     Image format for tileset fetcher, JPG uncompressed.
     **/
    @objc static let TileImageFormatJPG100 = "jpg"

    /**
     Image format for tileset fetcher, JPG at compression 0.9.
     **/
    @objc static let TileImageFormatJPG90 = "jpg90"

    /**
     Image format for tileset fetcher, JPG at compression 0.8.
     **/
    @objc static let TileImageFormatJPG80 = "jpg80"

    /**
     Image format for tileset fetcher, JPG at compression 0.7.
     **/
    @objc static let TileImageFormatJPG70 = "jpg70"

    /**
     In-progress callback typealias as tiles are loaded with the expected total needed and the current process as a percent.
     **/
    public typealias TileLoadProgressCallback = (_ progress: Float, _ total: Int) -> Void

    /**
     Completion typealias for when tile loading is complete and the image is ready.
     **/
    public typealias TileLoadCompletion = (_ image: UIImage?, _ error: NSError?) -> Void

    fileprivate static let tileSize = CGSize(width: 256, height: 256)
    fileprivate static let styleSize = CGSize(width: 256, height: 256)
    fileprivate var pendingFetches = [UUID: [UUID]]()
    fileprivate let pendingFetchesDispatchQueue = DispatchQueue(label: "com.mapbox.SceneKit.pendingFetches", attributes: .concurrent)
    public static var tileSizeWidth: Double {
        get { return Double(MapboxImageAPI.tileSize.width) }
    }

    private static let queue = DispatchQueue(label: "com.mapbox.scenekit.processing", attributes: [.concurrent])

    private let httpAPI: MapboxHTTPAPI
    private var eventsManager: MMEEventsManager = MMEEventsManager.shared()

    @objc
    public override init() {
        var mapboxAccessToken: String? = nil
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject],
            let token = dict["MGLMapboxAccessToken"] as? String {
            mapboxAccessToken = token
        }

        if let mapboxAccessToken = mapboxAccessToken {
            eventsManager.isMetricsEnabledInSimulator = true
            eventsManager.isMetricsEnabledForInUsePermissions = false
            eventsManager.initialize(withAccessToken: mapboxAccessToken, userAgentBase: "mapbox-scenekit-ios", hostSDKVersion: String(describing: Bundle(for: MapboxImageAPI.self).object(forInfoDictionaryKey: "CFBundleShortVersionString")!))
            eventsManager.disableLocationMetrics()
            eventsManager.sendTurnstileEvent()

            httpAPI = MapboxHTTPAPI(accessToken: mapboxAccessToken)
        } else {
            assert(false, "`accessToken` must be set in the Info.plist as `MGLMapboxAccessToken` or the `Route` passed into the `RouteController` must have the `accessToken` property set.")
            httpAPI = MapboxHTTPAPI(accessToken: "")
        }

        super.init()
    }

    deinit {
        let tasks = pendingFetches.keys
        for task in tasks {
            cancelRequestWithID(task)
        }
    }

    //MARK: - Public API

    /**
     Used to fetch a stitched together set of tiles from the tileset API. The tileset API can be used to fetch images representing data Mapbox datasets, such
     as streets-v10, terrain-rgb, and tilesets a user has uploaded through Mapbox studio.

     See: https://www.mapbox.com/api-documentation/#retrieve-tiles

     Expected formats are one of `TileImageFormatPNG`, `TileImageFormatJPG100`, `TileImageFormatJPG90`, `TileImageFormatJPG80`, `TileImageFormatJPG70`.

     Returns a UUID representing the task managing the fetching and stitching together of the tile images. Used for cancellation if needed.
     **/
    @objc
    public func image(forTileset tileset: String,
                      zoomLevel zoom: Int,
                      southWestCorner: CLLocation,
                      northEastCorner: CLLocation,
                      format: String, progress: TileLoadProgressCallback? = nil,
                      completion: @escaping TileLoadCompletion) -> UUID {

        let bounding = MapboxImageAPI.tiles(zoom: zoom, southWestCorner: southWestCorner, northEastCorner: northEastCorner, tileSize: MapboxImageAPI.tileSize)
        let imageBuilder = ImageBuilder(xs: bounding.xs.count, ys: bounding.ys.count, tileSize: MapboxImageAPI.tileSize, insets: bounding.insets)

        let group = DispatchGroup()
        let groupID = UUID()
        self.pendingFetchesDispatchQueue.sync(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.pendingFetches[groupID] = [UUID]()
        }

        var completed: Int = 0
        let total = bounding.xs.count * bounding.ys.count

        DispatchQueue.main.async {
            progress?(Float(0) / Float(total), total)
        }

        var error: FetchError?
        for (xindex, x) in bounding.xs.enumerated() {
            for (yindex, y) in bounding.ys.enumerated() {
                group.enter()
                if let task = httpAPI.tileset(tileset, zoomLevel: zoom, xTile: x, yTile: y, format: format, completion: { image, fetchError in
                    MapboxImageAPI.queue.async {
                        defer {
                            completed += 1
                            DispatchQueue.main.async {
                                progress?(Float(completed) / Float(total), total)
                            }
                            group.leave()
                        }
                        guard let image = image else {
                            error = fetchError ?? FetchError.unknown
                            NSLog("Couldn't get image for tile {\(zoom),\(x),\(y)}")
                            return
                        }

                        imageBuilder.addTile(x: xindex, y: yindex, image: image)
                    }
                }) {
                    pendingFetchesDispatchQueue.sync(flags: .barrier) { [weak self] in
                        guard let self = self else { return }
                        self.pendingFetches[groupID]?.append(task)
                    }
                }
            }
        }

        group.notify(queue: MapboxImageAPI.queue) {
            guard error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error?.toNSError())
                }
                return
            }

            //Color data gets messed up if the user expectes a PNG back but doesn't get one
            if format == MapboxImageAPI.TileImageFormatPNG, let image = imageBuilder.makeImage(), let png = UIImagePNGRepresentation(image), let formattedImage = UIImage(data: png) {
                DispatchQueue.main.async {
                    completion(formattedImage, nil)
                }
            } else if let image = imageBuilder.makeImage() {
                DispatchQueue.main.async {
                    completion(image, nil)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil, FetchError.unknown.toNSError())
                }
            }
        }

        return groupID
    }

    /**
     Used to fetch a stitched together set of tiles from the style API. The style API can be used to fetch images representing user-created styles
     via Mapbox Studio. Styles are referenced by `username.id`.

     See: https://www.mapbox.com/api-documentation/#static

     Returns a UUID representing the task managing the fetching and stitching together of the tile images. Used for cancellation if needed.
     **/
    @objc
    public func image(forStyle style: String, zoomLevel zoom: Int, southWestCorner: CLLocation, northEastCorner: CLLocation, progress: TileLoadProgressCallback? = nil, completion: @escaping TileLoadCompletion) -> UUID {
        //Note: this API endpoint returns at 2x the normal tile size (512 covers a bounding box calculated for 256), but relies on the bounding size of the normal size (256)
        let returnedSize = MapboxImageAPI.styleSize * CGFloat(2.0)
        let bounding = MapboxImageAPI.tiles(zoom: zoom, southWestCorner: southWestCorner, northEastCorner: northEastCorner, tileSize: MapboxImageAPI.styleSize)
        let imageBuilder = ImageBuilder(xs: bounding.xs.count, ys: bounding.ys.count, tileSize: returnedSize, insets: bounding.insets * 2)

        let group = DispatchGroup()
        let groupID = UUID()
        pendingFetchesDispatchQueue.sync(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.pendingFetches[groupID] = [UUID]()
        }

        var completed: Int = 0
        let total = bounding.xs.count * bounding.ys.count

        DispatchQueue.main.async {
            progress?(Float(0) / Float(total), total)
        }

        var error: FetchError?
        for (xindex, x) in bounding.xs.enumerated() {
            for (yindex, y) in bounding.ys.enumerated() {
                group.enter()
                if let task = httpAPI.style(style, zoomLevel: zoom, xTile: x, yTile: y, tileSize: returnedSize, completion: { image, fetchError in
                    MapboxImageAPI.queue.async {
                        defer {
                            completed += 1
                            DispatchQueue.main.async {
                                progress?(Float(completed) / Float(total), total)
                            }
                            group.leave()
                        }
                        guard let image = image else {
                            error = fetchError ?? FetchError.unknown
                            NSLog("Couldn't get image for tile {\(zoom),\(x),\(y)}")
                            return
                        }

                        imageBuilder.addTile(x: xindex, y: yindex, image: image)
                    }
                }) {
                    pendingFetchesDispatchQueue.sync(flags: .barrier) { [weak self] in
                        guard let self = self else { return }
                        self.pendingFetches[groupID]?.append(task)
                    }
                }
            }
        }

        group.notify(queue: DispatchQueue.main) {
            self.pendingFetchesDispatchQueue.sync(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                self.pendingFetches.removeValue(forKey: groupID)
            }
            completion(error == nil ? imageBuilder.makeImage() : nil, error?.toNSError())
        }

        return groupID
    }

    /**
     Used to cancel an in-progress tile fetch request given the UUID returned from the intiial call.
     **/
    @objc
    func cancelRequestWithID(_ groupID: UUID) {
        self.pendingFetchesDispatchQueue.sync(flags: .barrier) { [weak self] in
            guard let tasks = pendingFetches[groupID] else {
                return
            }
            for task in tasks {
                httpAPI.cancelRequestWithID(task)
            }

            self?.pendingFetches.removeValue(forKey: groupID)
        }
    }

    //MARK: - Helpers

    internal static func tiles(zoom: Int, southWestCorner: CLLocation, northEastCorner: CLLocation, tileSize: CGSize) -> (xs: [Int], ys: [Int], insets: UIEdgeInsets) {
        
        let minLat = southWestCorner.coordinate.latitude
        let maxLat = northEastCorner.coordinate.latitude
        let minLon = southWestCorner.coordinate.longitude
        let maxLon = northEastCorner.coordinate.longitude
        
        var xs = [Int]()
        var ys = [Int]()
        var insets = UIEdgeInsets.zero

        for lat in [minLat, maxLat] {
            for lon in [minLon, maxLon] {
                let tile = Math.latLng2tile(lat: lat, lon: lon, zoom: zoom, tileSize: tileSize)
                xs.append(tile.xTile)
                ys.append(tile.yTile)

                if lat == minLat {
                    insets = UIEdgeInsets(top: insets.top, left: insets.left, bottom: tileSize.height - CGFloat(tile.yPos), right: insets.right)
                }
                if lat == maxLat {
                    insets = UIEdgeInsets(top: CGFloat(tile.yPos), left: insets.left, bottom: insets.bottom, right: insets.right)
                }
                if lon == minLon {
                    insets = UIEdgeInsets(top: insets.top, left: CGFloat(tile.xPos), bottom: insets.bottom, right: insets.right)
                }
                if lon == maxLon {
                    insets = UIEdgeInsets(top: insets.top, left: insets.left, bottom: insets.bottom, right: tileSize.width - CGFloat(tile.xPos))
                }
            }
        }

        return ((xs.min()!...xs.max()!).map({ $0 }), (ys.min()!...ys.max()!).map({ $0 }), insets)
    }
}
