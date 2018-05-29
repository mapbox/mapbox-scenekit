import Foundation
import UIKit
import CoreLocation

internal final class MapboxHTTPAPI {
    private static var operationQueue: OperationQueue = {
        var operationQueue = OperationQueue()
        operationQueue.underlyingQueue = DispatchQueue(label: "com.mapbox.scenekit.api", attributes: [.concurrent])
        operationQueue.name = "Mapbox API Queue"
        operationQueue.maxConcurrentOperationCount = 10
        return operationQueue
    }()

    private var accessToken: String

    init(accessToken token: String) {
        accessToken = token
    }

    func tileset(_ tileset: String, zoomLevel z: Int, xTile x: Int, yTile y: Int, format: String, completion: @escaping (_ image: UIImage?) -> Void) -> UUID? {
        guard let url = URL(string: "https://api.mapbox.com/v4/\(tileset)/\(z)/\(x)/\(y).\(format)?access_token=\(accessToken)") else {
            NSLog("Couldn't get URL for fetch task")
            return nil
        }

        let task = HttpRequestOperation(url: url, callback: {  (success, responseCode, data) -> Void in
            guard success, let data = data, let image = UIImage(data: data) else {
                NSLog("Error downloading tile: \(responseCode)")
                completion(nil)
                return
            }
            completion(image)
        }, session: URLSession.shared)
        MapboxHTTPAPI.operationQueue.addOperations([task], waitUntilFinished: false)

        return task.taskID
    }

    func style(_ s: String, zoomLevel z: Int, xTile x: Int, yTile y: Int, tileSize: CGSize, completion: @escaping (_ image: UIImage?) -> Void) -> UUID? {
        let boundingBox = Math.tile2BoundingBox(x: x, y: y, z: z)
        let centerLat = boundingBox.latBounds.1 - (boundingBox.latBounds.1 - boundingBox.latBounds.0) / 2.0
        let centerLon = boundingBox.lonBounds.1 - (boundingBox.lonBounds.1 - boundingBox.lonBounds.0) / 2.0

        return style(s, zoomLevel: z, centerLat: centerLat, centerLon: centerLon, tileSize: tileSize, completion: completion)
    }

    func style(_ style: String, zoomLevel z: Int, centerLat: CLLocationDegrees, centerLon: CLLocationDegrees, tileSize: CGSize, completion: @escaping (_ image: UIImage?) -> Void) -> UUID? {
        guard let url = URL(string: "https://api.mapbox.com/styles/v1/\(style)/static/\(centerLon),\(centerLat),\(z)/\(Int(tileSize.width))x\(Int(tileSize.height))?access_token=\(accessToken)&attribution=false&logo=false") else {
            NSLog("Couldn't get URL for fetch task")
            return nil
        }

        let headers: [String: String] = ["Accept": "image/*;q=0.8"]
        let task = HttpRequestOperation(url: url, headers: headers, callback: {  (success, responseCode, data) -> Void in
            guard success, let data = data, let image = UIImage(data: data) else {
                NSLog("Error downloading tile: \(responseCode)")
                completion(nil)
                return
            }
            completion(image)
        }, session: URLSession.shared)

        MapboxHTTPAPI.operationQueue.addOperations([task], waitUntilFinished: false)

        return task.taskID
    }

    func cancelRequestWithID(_ id: UUID) {
        MapboxHTTPAPI.operationQueue.operations.filter({ ($0 as? HttpRequestOperation)?.taskID == id }).forEach({ $0.cancel() })
    }
}
