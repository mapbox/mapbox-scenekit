import Foundation
import CoreLocation
import CoreGraphics

internal class Math {
    static func degreesToRadians(_ degrees: Double) -> Double {
        return Double.pi * degrees / 180.0
    }

    static func radiansToDegrees(_ radians: Double) -> Double {
        return radians * 180.0 / Double.pi
    }

    static func metersToDegreesForLat(atLongitude longitude: CLLocationDegrees) -> CLLocationDistance {
        let a = cos(2 * Math.degreesToRadians(longitude))
        let b = cos(4 * Math.degreesToRadians(longitude))
        let c = cos(6 * Math.degreesToRadians(longitude))
        
        return 1.0 / fabs(111132.95255 - 559.84957 * a + 1.17514 * b - 0.00230 * c)
    }

    static func metersToDegreesForLon(atLatitude latitude: CLLocationDegrees) -> CLLocationDistance {
        let a = cos(Math.degreesToRadians(latitude))
        let b = cos(3 * Math.degreesToRadians(latitude))
        let c = cos(5 * Math.degreesToRadians(latitude))
        
        return 1.0 / fabs(111412.87733 * a - 93.50412 * b + 0.11774 * c)
    }

    static func latLng2tile(lat: Double, lon: Double, zoom: Int, tileSize: CGSize) -> (xTile: Int, yTile: Int, xPos: Double, yPos: Double) {
        var eLng = (lon + 180.0) / 360.0 * pow(2.0, Double(zoom))
        var eLat = (1 - log(tan(Math.degreesToRadians(lat)) + 1 / cos(Math.degreesToRadians(lat))) / Double.pi) / 2 * pow(2.0, Double(zoom))
        let xInd = round((eLng - floor(eLng)) * Double(tileSize.width))
        let yInd = round((eLat - floor(eLat)) * Double(tileSize.height))
        eLng = floor(eLng)
        eLat = floor(eLat)

        return (Int(eLng), Int(eLat), xInd, yInd)
    }

    static func tile2LatLng(x: Int, y: Int, z: Int) -> (lat: CLLocationDegrees, lon: CLLocationDegrees) {
        let lon = Double(x) / pow(2.0, Double(z)) * 360.0 - 180.0
        let n = Double.pi - 2.0 * Double.pi * Double(y) / pow(2.0, Double(z))
        let lat = Math.radiansToDegrees(atan(0.5 * (exp(n) - exp(-n))))
        
        return (lat, lon)
    }

    static func tile2BoundingBox(x: Int, y: Int, z: Int) -> (latBounds: (CLLocationDegrees, CLLocationDegrees), lonBounds: (CLLocationDegrees, CLLocationDegrees)) {
        let topLeft = tile2LatLng(x: x, y: y, z: z)
        let bottomRight = tile2LatLng(x: x + 1, y: y + 1, z: z)
        
        return ((bottomRight.lat, topLeft.lat), (topLeft.lon, bottomRight.lon))
    }
    
    static func zoomLevelForBounds(southWestCorner: CLLocation, northEastCorner: CLLocation) -> Int {
        let distance = northEastCorner.distance(from: southWestCorner) / 1000.0 //use kilometers
        let imageSize = Double(Constants.maxTextureImageSize)
        let latitudeAdjustment = cos(.pi * northEastCorner.coordinate.latitude / 180)
        let arg = Constants.earthDiameterInKilometers
                    * imageSize
                    * latitudeAdjustment
                    / (distance * MapboxImageAPI.tileSizeWidth)
        let zoom = Int(round(log(arg)/log(2)))
        
        return zoom
    }
}
