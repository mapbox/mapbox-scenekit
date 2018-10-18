//
//  TerrainNodeExtension+Routes.swift
//  MapboxSceneKit
//
//  Created by Jim Martin on 8/16/18.
//  Copyright © 2018 MapBox. All rights reserved.
//

import Foundation
import SceneKit
import CoreLocation

extension TerrainNode {
    
    /// Normalising locations greatly decreases possibility of the line to go through a mountain or above a lake,
    /// what could happen when there is eg 10km distance between 2 points and a peek in middle of the line.
    /// Checks distance between following points in `locations` (in provided order).
    /// Adds additional point(s) between them if the distance is larger than `maximumDistance`.
    ///
    /// - Parameters:
    ///   - locations: Locations on the TerrainNode.
    ///   - maximumDistance: The distance [meters] above which the line should be split
    /// to segments of maximum `maximumDistance` length.
    /// - Returns: Same array as input `locations` but with added mid-points, so that no difference
    /// between two following points is bigger than `maximumDistance`.
    @objc
    public func normalise(locations: [CLLocation], maximumDistance: CLLocationDistance) -> [CLLocation] {
        guard locations.count > 0 else { // algorithm has no sense for 0 samples.
            return locations
        }
        
        var newLocations: [CLLocation] = []
        for location in locations {
            guard let previousLocation = newLocations.last else { // first location always fulfills the conditions
                newLocations.append(location)
                continue
            }
            let distance = location.distance(from: previousLocation)
            guard distance > maximumDistance else { // distance is small enough to continue
                newLocations.append(location)
                continue
            }
            // distance is greater than expected, divide it to equal segments lower than maximumDistance
            let numberOfPoints = Int(ceil(distance / maximumDistance))
            let previousCoordinate = previousLocation.coordinate
            let currentCoordinate = location.coordinate
            let deltaLatitude = (currentCoordinate.latitude - previousCoordinate.latitude) / Double(numberOfPoints)
            let deltaLongitude = (currentCoordinate.longitude - previousCoordinate.longitude) / Double(numberOfPoints)
            for pointNumber in 1..<numberOfPoints {
                let newLocation = CLLocation(latitude: previousCoordinate.latitude + deltaLatitude * Double(pointNumber),
                                             longitude: previousCoordinate.longitude + deltaLongitude * Double(pointNumber))
                newLocations.append(newLocation)
            }
            newLocations.append(location)
        }
        return newLocations
    }
    
    /// Converts a set of coordinates to SCNVector3s relative to the TerrainNode,
    /// then adds a PolylineNode through those locations.
    ///
    /// - Parameters:
    ///   - coordinates: Coordinates on the TerrainNode. The Polyline is drawn through locations from 0...n
    ///   - radius: The width of the line
    ///   - color: The color of the line
    /// - Returns: The final PolylineNode, already added as a child of the TerrainNode
    @discardableResult
    @objc
    public func addPolyline(coordinates: [CLLocation], radius: CGFloat, color: UIColor) -> PolylineNode {

        let scenePositions = coordinatesToSCNVector3(coordinates: coordinates)
        let lineNode = PolylineNode(positions: scenePositions, radius: radius, color: color)
        lineNode.position.y += Float(radius)
        self.addChildNode(lineNode)
        return lineNode
    }
    
    /// Converts a set of coordinates to SCNVector3s relative to the TerrainNode,
    /// then adds a PolylineNode through those locations.
    ///
    /// - Parameters:
    ///   - coordinates: Coordinates to draw. The Polyline is drawn through each location consectutively from 0...n
    ///   - startRadius: The width of the initial point of the line. Linearly interpolated from start to end positions.
    ///   - endRadius: The width of the final point of the line. Linearly interpolated from start to end positions.
    ///   - startColor: The color of the initial point of the line. Linearly interpolated from start to end.
    ///   - endColor: The color of the final point of the line. Linearly interpolated from start to end.
    /// - Returns: The final PolylineNode, already added as a child of the TerrainNode
    @discardableResult
    @objc
    @available(iOS 10.0, *)
    public func addPolyline(coordinates: [CLLocation], startRadius: CGFloat, endRadius: CGFloat,
                            startColor: UIColor, endColor: UIColor) -> PolylineNode {
        
        let scenePositions = coordinatesToSCNVector3(coordinates: coordinates)
        let lineNode = PolylineNode(positions: scenePositions,
                                    startRadius: startRadius, endRadius: endRadius,
                                    startColor: startColor, endColor: endColor)
        lineNode.position.y += Float((startRadius + endRadius)/2)
        self.addChildNode(lineNode)
        return lineNode
    }

    @discardableResult
    @objc
    @available(iOS 10.0, *)
    public func addPolyline(coordinates: [CLLocation],
                            radii: [CGFloat],
                            colors: [UIColor],
                            verticalOffset: CGFloat = 0) -> PolylineNode {

        let scenePositions = coordinatesToSCNVector3(coordinates: coordinates)
        let lineNode = PolylineNode(positions: scenePositions, radii: radii, colors: colors)
        lineNode.position.y += Float(verticalOffset)
        self.addChildNode(lineNode)
        return lineNode
    }
    
    /// Convert coordinates to SCNVector3
    ///
    /// - Parameter coordinates: CLLocation coordinates to convert
    /// - Returns: vector in terrainNode local space
    fileprivate func coordinatesToSCNVector3(coordinates: [CLLocation]) -> [SCNVector3] {
        
        var scenePositions: [SCNVector3] = []
        for coord in coordinates {
            let position = self.positionForLocation(coord)
            scenePositions.append(position)
        }
        return scenePositions
    }
}
