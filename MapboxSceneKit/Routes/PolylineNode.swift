//
//  PolylineNode.swift
//  MapboxSceneKit
//
//  Created by Jim Martin on 9/11/18.
//  Copyright © 2018 MapBox. All rights reserved.
//

import Foundation
import SceneKit

//MARK: - Polyline Renderer Protocol
/// Implement this protocol to define new line rendering behavior
internal protocol PolylineRenderer {
    
    func generatePolyline(forNode node: SCNNode, positions: [SCNVector3], radius: CGFloat, color: UIColor)
    
}

//MARK: - Polyline Node
/// Stores data on the polyline, responsible for selecting the correct renderer based on iOS version.
public class PolylineNode: SCNNode {
    
    //line generation changes depending on ios version
    private var lineRenderer : PolylineRenderer
    
    private var positions: [SCNVector3]
    private var radius: CGFloat
    private var color: UIColor
    
    public init( positions: [SCNVector3], radius: CGFloat, color: UIColor ) {
        
        //Find and instantiate the appropriate renderer
        self.lineRenderer = PolylineNode.getValidRenderer()
        self.positions = positions
        self.radius = radius
        self.color = color
        super.init()
        
        //use the line renderer to generate the line geometry for this node
        lineRenderer.generatePolyline(forNode: self, positions: self.positions, radius: self.radius, color: self.color)
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

}

//MARK: - Selecting Renderer version
fileprivate extension PolylineNode {
    
    //return the appropriate line generator based on the ios version / metal availability
    static func getValidRenderer() -> PolylineRenderer {
        //TODO: first, check if a metal rendering context is available
        
        //then, check if the ios version can support framework shaders
        if #available(iOS 10.0, *) {
            return Polyline_Shader()
        } else {
            return Polyline_Cylinder()
        }
    }
}
