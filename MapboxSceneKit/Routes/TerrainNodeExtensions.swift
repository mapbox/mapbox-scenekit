//
//  TerrainNodeExtensions.swift
//  MapboxSceneKit
//
//  Created by Natalia Osiecka on 08/08/2018.
//  Copyright © 2018 MapBox. All rights reserved.
//

import Foundation
import SceneKit
import CoreLocation

//extension TerrainNode {
//    @discardableResult
    /// Calculates and draws a route with two circles on the beginning and the end of the path and cylinders
    /// in the meantime.
    ///
    /// - Parameters:
    ///   - locations: The locations which define where to draw the path.
    ///   - cylinderRadius: Radius of the cylinders.
    ///   - color: Color of the path.
    ///   - verticalOffset: Provide positive value to move the path up or negative to move it down.
    /// - Returns: The array of all added nodes as a line
//    @objc public func drawPath(from locations: [CLLocation], cylinderRadius: CGFloat, color: UIColor, verticalOffset: CGFloat = 0) -> [SCNNode] {
//        var nodes = [SCNNode]()
//        guard locations.count > 0 else {
//            return nodes// there are no points to draw
//        }
//
//        var previousLocation: CLLocation? = nil
//        for location in locations {
//            if let previousLocation = previousLocation {
//                let node = projectedCylinder(from: previousLocation, to: location, radius: cylinderRadius, color: color, verticalOffset: verticalOffset)
//                nodes.append(node)
//            }
//            previousLocation = location
//        }
//
//        for node in nodes {
//            addChildNode(node)
//        }
//        return nodes
//    }
    
//    /// Builds a cylinder at the given location on given terrain node.
//    ///
//    /// - Parameters:
//    ///   - startLocation: First location at which the cylinder should be placed.
//    ///   - endLocation: Second location at which the cylinder should be placed.
//    ///   - radius: Radius of the cylinder.
//    ///   - color: Color of the cylinder.
//    ///   - verticalOffset: Provide positive value to move the line up or negative to move it down.
//    /// - Returns: Fully configured and projected cylinder to the given terrain node.
//    @objc public func projectedCylinder(from startLocation: CLLocation, to endLocation: CLLocation, radius: CGFloat, color: UIColor, verticalOffset: CGFloat = 0) -> SCNNode {
//        var startVector = positionForLocation(startLocation)
//        startVector = convertPosition(startVector, to: self)
//        startVector.y += Float(radius / 2 + verticalOffset) // move up a bit so we see it properly
//
//        var endVector = positionForLocation(endLocation)
//        endVector = convertPosition(endVector, to: self)
//        endVector.y += Float(radius / 2 + verticalOffset)
//
//        return TerrainNode.cylinder(from: startVector, to: endVector, radius: radius, color: color)
//    }
//
//    /// Builds a sphere at the given location on given terrain node.
//    ///
//    /// - Parameters:
//    ///   - terrainNode: Terrain node on which the sphere should be positioned.
//    ///   - location: Location at which the sphere should be placed.
//    ///   - radius: Radius of the sphere.
//    ///   - color: Color of the sphere.
//    ///   - verticalOffset: Provide positive value to move the sphere up or negative to move it down.
//    /// - Returns: Fully configured and projected sphere to the given terrain node.
//    @objc public func projectedSphere(at location: CLLocation, radius: CGFloat, color: UIColor, verticalOffset: CGFloat = 0) -> SCNNode {
//        let node = SCNNode(geometry: SCNSphere(radius: radius))
//        node.geometry?.firstMaterial?.diffuse.contents = color
//        let position = positionForLocation(location)
//        node.position = convertPosition(position, to: self)
//        node.position.y += Float(verticalOffset)
//        return node
//    }
    

//}
