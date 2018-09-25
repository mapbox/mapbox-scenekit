//
//  PolylineCylinder.swift
//  MapboxSceneKit
//
//  Created by Jim Martin on 9/11/18.
//  Copyright © 2018 MapBox. All rights reserved.
//

import Foundation
import SceneKit

@available(iOS, introduced: 8.0, deprecated: 10.0, message: "Use PolylineShader")
internal class PolylineCylinder: PolylineRenderer {

    var sampleCount: Int = 0
    
    func render(_ polyline: PolylineNode, withSampleCount sampleCount: Int) {

        self.sampleCount = sampleCount
        var positions = [SCNVector3]()
        for index in 0..<sampleCount {
            positions.append(polyline.getPositon(atProgress: progressAtSample(index)))
        }
        let radius = polyline.getRadius(atProgress: 0)
        let color = polyline.getColor(atProgress: 0)

        var nodes = [SCNNode]()
        guard positions.count > 0 else {
            return // there are no points to draw
        }

        var previousPosition: SCNVector3?
        for position in positions {
            if let previousPosition = previousPosition {
                let cylinderNode = cylinder(from: previousPosition, to: position, radius: radius, color: color)
                let sphereNode = sphere(position: position, radius: radius, color: color)
                nodes.append(cylinderNode)
                nodes.append(sphereNode)
            } else {
                let sphereNode = sphere(position: position, radius: radius, color: color)
                nodes.append(sphereNode)
            }
            previousPosition = position
        }

        for cylinderNode in nodes {
            polyline.addChildNode(cylinderNode)
        }
    }

    private func progressAtSample(_ sample: Int) -> CGFloat {
        return (CGFloat(sample) / CGFloat(sampleCount - 1))
    }

    private func sphere( position: SCNVector3, radius: CGFloat, color: UIColor) -> SCNNode {
        let sphereNode = SCNNode(geometry: SCNSphere(radius: radius))
        sphereNode.position = position
        sphereNode.geometry?.firstMaterial?.diffuse.contents = color
        return sphereNode
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
    @objc private func cylinder(from startPoint: SCNVector3, to endPoint: SCNVector3,
                                radius: CGFloat, color: UIColor) -> SCNNode {
        let node = SCNNode()
        let middleVector = SCNVector3(x: endPoint.x - startPoint.x,
                                      y: endPoint.y - startPoint.y,
                                      z: endPoint.z - startPoint.z)
        let length = CGFloat(sqrt(middleVector.x * middleVector.x +
                                  middleVector.y * middleVector.y +
                                  middleVector.z * middleVector.z))

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
        let ovec = SCNVector3(0, length/2.0, 0)

        //target vector, in new coordination
        let nvec = SCNVector3((endPoint.x - startPoint.x)/2.0,
                            (endPoint.y - startPoint.y)/2.0,
                            (endPoint.z-startPoint.z)/2.0)

        // axis between two vector
        let avec = SCNVector3( (ovec.x + nvec.x)/2.0,
                             (ovec.y + nvec.y)/2.0,
                             (ovec.z + nvec.z)/2.0)

        //normalized axis vector
        let avNormalized = normalizeVector(avec)
        let q0 = Float(0.0) //cos(angel/2), angle is always 180 or M_PI
        let q1 = Float(avNormalized.x) // x' * sin(angle/2)
        let q2 = Float(avNormalized.y) // y' * sin(angle/2)
        let q3 = Float(avNormalized.z) // z' * sin(angle/2)
        
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
    
    private func normalizeVector(_ iv: SCNVector3) -> SCNVector3 {
        let length = sqrt(iv.x * iv.x + iv.y * iv.y + iv.z * iv.z)
        if length == 0 {
            return SCNVector3(0.0, 0.0, 0.0)
        }

        return SCNVector3( iv.x / length, iv.y / length, iv.z / length)
    }
}
