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
        scenePositions = subdivideAndSnapToTerrain(positions: scenePositions)
        return scenePositions
    }
    
    /// Resamples the provided route based on zoom level to avoid polylines that intersect or float above terrain.
    ///
    /// - Parameter positions: the positions to be re-sampled
    /// - Returns: the final route, snapped to the terrainNode's surface
    fileprivate func subdivideAndSnapToTerrain(positions: [SCNVector3]) -> [SCNVector3] {
        
        guard let firstPosition = positions.first else { return [] }
        var newPositions =  [SCNVector3]()
        newPositions.append(firstPosition)
        
        //re-use a single bezierspline instance to interpolate each segment
        var positionBezier: BezierSpline3D
        
        //for each segment...
        for index in 1..<positions.count {
            
            let fromPostion = positions[index - 1]
            let toPositon = positions[index]
            
            /*
             Define the maximum meaningful elevation samples supported by the terrainnode's pixels per meter.
             More samples would read the same pixel multiple times per line, creating jagged steps.
             */
            let lengthInMeters = Double((toPositon - fromPostion).length())
            let maxSamplesInSegment = lengthInMeters / self.metersPerPixelX
            
            //resample at a 1/5 of the maximum terrain resolution, to save on performance.
            let samplesInSegment = floor(maxSamplesInSegment * 0.2)

            /*
             If a segment crosses enough terrain, it's samplesInSegment will be > 1.
             Longer lines will have more samplesInSegment, because they cover more elevation data.
             Lines below 1 mean there's not enough difference in the height data between the two points, so no need to re-sample
            */
            for sampleIndex in 0..<Int(samplesInSegment) where sampleIndex > 0 {
                
                //define a spline for the segment
                positionBezier = BezierSpline3D(curvePoints: [fromPostion, toPositon])
                
                //create a new point on the segment at a step along the line.
                let progress = CGFloat(sampleIndex)/CGFloat(samplesInSegment)
                let samplePosition: SCNVector3 = positionBezier.evaluate(progress: progress)
                
                //sample the height at this position
                let newPosition  = SCNVector3(samplePosition.x,
                                              Float(self.heightForLocalPosition(samplePosition)),
                                              samplePosition.z)
                
                //add the new position to the new line.
                newPositions.append(newPosition)
            }
            
            //add the original end position to the new line
            newPositions.append(positions[index])
        }
        
        return newPositions
    }
}
