//
//  PolylineGenerator.swift
//  MapboxSceneKit
//
//  Created by Jim Martin on 9/11/18.
//  Copyright © 2018 MapBox. All rights reserved.
//

import Foundation
import SceneKit

protocol PolylineGenerator {
    
    func generatePolyline(forNode node: SCNNode, positions: [SCNVector3], radius: CGFloat, color: UIColor)

}

@available(iOS 10.0, *)
internal class Polyline_Shader: PolylineGenerator {
    func generatePolyline(forNode node: SCNNode, positions: [SCNVector3], radius: CGFloat, color: UIColor) {
        // add material and geometry to the node
        print("Generate shader polyline")
    }
}

internal class Polyline_Cylinder: PolylineGenerator {
    func generatePolyline(forNode node: SCNNode, positions: [SCNVector3], radius: CGFloat, color: UIColor) {
        // add material and geometry to the node
        print("Generate cylinder polyline")
    }
}
