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
    @discardableResult
    @objc
    /// Converts a set of coordinates to SCNVector3s relative to the TerrainNode, then adds a PolylineNode through those locations.
    ///
    /// - Parameters:
    ///   - coordinates: Coordinates on the TerrainNode. The Polyline is drawn through each location consectutively from 0...n
    ///   - radius: The width of the line
    ///   - color: The color of the line
    /// - Returns: The final PolylineNode, already added as a child of the TerrainNode
    public func addPolyline( coordinates: [CLLocation], radius: CGFloat, color: UIColor) -> PolylineNode{
        
        var scenePositions : [SCNVector3] = []
        for coord in coordinates {
            let position = self.positionForLocation(coord)
            scenePositions.append(position)
        }
        
        let lineNode = PolylineNode(positions: scenePositions, radius: radius, color: color)
        lineNode.position.y += Float(radius)
        self.addChildNode(lineNode)
        return lineNode
    }
    
    @available(iOS 10.0, *)
    /// Converts a set of coordinates to SCNVector3s relative to the TerrainNode, then adds a PolylineNode through those locations.
    ///
    /// - Parameters:
    ///   - coordinates: Coordinates on the TerrainNode. The Polyline is drawn through each location consectutively from 0...n
    ///   - startRadius: The width of the initial point of the line. Linearly interpolated from start to end positions.
    ///   - endRadius: The width of the final point of the line. Linearly interpolated from start to end positions.
    ///   - startColor: The color of the initial point of the line. Linearly interpolated through RGB color space from start to end.
    ///   - endColor: The color of the final point of the line. Linearly interpolated through RGB color space from start to end.
    /// - Returns: The final PolylineNode, already added as a child of the TerrainNode
    public func addPolyline( coordinates: [CLLocation], startRadius: CGFloat, endRadius: CGFloat, startColor: UIColor, endColor: UIColor) -> PolylineNode{
        
        var scenePositions : [SCNVector3] = []
        for coord in coordinates {
            let position = self.positionForLocation(coord)
            scenePositions.append(position)
        }
        
        let lineNode = PolylineNode(positions: scenePositions, startRadius: startRadius, endRadius: endRadius, startColor: startColor, endColor: endColor)
        lineNode.position.y += Float((startRadius + endRadius)/2)
        self.addChildNode(lineNode)
        return lineNode
    }
}
