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

extension TerrainNode {
    @discardableResult
    /// Calculates and draws a route with two circles on the beginning and the end of the path and cylinders
    /// in the meantime.
    ///
    /// - Parameters:
    ///   - locations: The locations which define where to draw the path.
    ///   - cylinderRadius: Radius of the cylinders.
    ///   - sphereRadius: Radius of the first and last spheres.
    ///   - color: Color of the path.
    /// - Returns: The array of all added nodes (first and last objects are the spheres, rest are the cylinders)
    public func drawPath(from locations: [CLLocation], cylinderRadius: CGFloat, sphereRadius: CGFloat, color: UIColor) -> [SCNNode] {
        var nodes = [SCNNode]()
        
        guard let firstLocation = locations.first, let lastLocation = locations.last else {
            return nodes// there are no points to draw
        }
        
        let firstNode = projectedSphere(at: firstLocation, radius: sphereRadius, color: color)
        nodes.append(firstNode)
        
        var previousLocation: CLLocation? = nil
        for location in locations {
            if let previousLocation = previousLocation {
                let node = projectedCylinder(from: previousLocation, to: location, radius: cylinderRadius, color: color)
                nodes.append(node)
            }
            previousLocation = location
        }
        
        let lastNode = projectedSphere(at: lastLocation, radius: sphereRadius, color: color)
        nodes.append(lastNode)
        
        for node in nodes {
            addChildNode(node)
        }
        return nodes
    }
    
    /// Builds a cylinder at the given location on given terrain node.
    ///
    /// - Parameters:
    ///   - startLocation: First location at which the cylinder should be placed.
    ///   - endLocation: Second location at which the cylinder should be placed.
    ///   - radius: Radius of the cylinder.
    ///   - color: Color of the cylinder.
    /// - Returns: Fully configured and projected cylinder to the given terrain node.
    public func projectedCylinder(from startLocation: CLLocation, to endLocation: CLLocation, radius: CGFloat, color: UIColor) -> SCNNode {
        var startVector = positionForLocation(startLocation)
        startVector = convertPosition(startVector, to: self)
        startVector.y += Float(radius / 2) // move up a bit so we see it properly
        
        var endVector = positionForLocation(endLocation)
        endVector = convertPosition(endVector, to: self)
        endVector.y += Float(radius / 2)
        
        return TerrainNode.cylinder(from: startVector, to: endVector, radius: radius, color: color)
    }
    
    /// Builds a sphere at the given location on given terrain node.
    ///
    /// - Parameters:
    ///   - terrainNode: Terrain node on which the sphere should be positioned.
    ///   - location: Location at which the sphere should be placed.
    ///   - radius: Radius of the sphere.
    ///   - color: Color of the sphere.
    /// - Returns: Fully configured and projected sphere to the given terrain node.
    public func projectedSphere(at location: CLLocation, radius: CGFloat, color: UIColor) -> SCNNode {
        let node = SCNNode(geometry: SCNSphere(radius: radius))
        node.geometry?.firstMaterial?.diffuse.contents = color
        let position = positionForLocation(location)
        node.position = convertPosition(position, to: self)
        return node
    }
    
    /// Builds a line (cylinder) between two given points in 3D.
    /// Math behind taken from: http://danceswithcode.net/engineeringnotes/quaternions/quaternions.html
    /// Credits to Windchill @ https://stackoverflow.com/a/42941966/849616
    ///
    /// - Parameters:
    ///   - startPoint: One of two points, between which a cylinder should be drawn.
    ///   - endPoint: Second one of two points, between which a cylinder should be drawn.
    ///   - radius: Radius of the cylinder.
    ///   - color: Color of the cylinder.
    /// - Returns: Fully configured and projected cylinder to the given terrain node.
    public static func cylinder(from startPoint: SCNVector3, to endPoint: SCNVector3, radius: CGFloat, color: UIColor) -> SCNNode {
        let node = SCNNode()
        let middleVector = SCNVector3(x: endPoint.x - startPoint.x, y: endPoint.y - startPoint.y, z: endPoint.z - startPoint.z)
        let length = CGFloat(sqrt(middleVector.x * middleVector.x + middleVector.y * middleVector.y + middleVector.z * middleVector.z))
        
        guard length != 0.0 else { // two points together.
            let sphere = SCNSphere(radius: radius)
            sphere.firstMaterial?.diffuse.contents = color
            node.geometry = sphere
            node.position = startPoint
            return node
        }
        
        let cylinder = SCNCylinder(radius: radius, height: length)
        cylinder.firstMaterial?.diffuse.contents = color
        node.geometry = cylinder
        
        //original vector of cylinder above 0,0,0
        let ov = SCNVector3(0, length/2.0, 0)
        //target vector, in new coordination
        let nv = SCNVector3((endPoint.x - startPoint.x)/2.0, (endPoint.y - startPoint.y)/2.0, (endPoint.z-startPoint.z)/2.0)
        // axis between two vector
        let av = SCNVector3( (ov.x + nv.x)/2.0, (ov.y+nv.y)/2.0, (ov.z+nv.z)/2.0)
        
        //normalized axis vector
        let av_normalized = normalizeVector(av)
        let q0 = Float(0.0) //cos(angel/2), angle is always 180 or M_PI
        let q1 = Float(av_normalized.x) // x' * sin(angle/2)
        let q2 = Float(av_normalized.y) // y' * sin(angle/2)
        let q3 = Float(av_normalized.z) // z' * sin(angle/2)
        
        node.transform.m11 = q0 * q0 + q1 * q1 - q2 * q2 - q3 * q3
        node.transform.m12 = 2 * q1 * q2 + 2 * q0 * q3
        node.transform.m13 = 2 * q1 * q3 - 2 * q0 * q2
        node.transform.m14 = 0.0
        
        node.transform.m21 = 2 * q1 * q2 - 2 * q0 * q3
        node.transform.m22 = q0 * q0 - q1 * q1 + q2 * q2 - q3 * q3
        node.transform.m23 = 2 * q2 * q3 + 2 * q0 * q1
        node.transform.m24 = 0.0
        
        node.transform.m31 = 2 * q1 * q3 + 2 * q0 * q2
        node.transform.m32 = 2 * q2 * q3 - 2 * q0 * q1
        node.transform.m33 = q0 * q0 - q1 * q1 - q2 * q2 + q3 * q3
        node.transform.m34 = 0.0
        
        node.transform.m41 = (startPoint.x + endPoint.x) / 2.0
        node.transform.m42 = (startPoint.y + endPoint.y) / 2.0
        node.transform.m43 = (startPoint.z + endPoint.z) / 2.0
        node.transform.m44 = 1.0
        
        return node
    }
    
    private static func normalizeVector(_ iv: SCNVector3) -> SCNVector3 {
        let length = sqrt(iv.x * iv.x + iv.y * iv.y + iv.z * iv.z)
        if length == 0 {
            return SCNVector3(0.0, 0.0, 0.0)
        }
        
        return SCNVector3( iv.x / length, iv.y / length, iv.z / length)
    }
}
