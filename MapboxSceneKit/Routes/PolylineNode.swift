//
//  PolylineNode.swift
//  MapboxSceneKit
//
//  Created by Jim Martin on 9/11/18.
//  Copyright © 2018 MapBox. All rights reserved.
//

import Foundation
import SceneKit

public class PolylineNode: SCNNode {
    
    //line generation changes depending on ios version
    private var lineGenerator : PolylineGenerator
    
    private var positions: [SCNVector3]
    private var radius: CGFloat
    private var color: UIColor
    
    public init( positions: [SCNVector3], radius: CGFloat, color: UIColor ) {
        self.lineGenerator = PolylineNode.getValidLineGenerator()
        self.positions = positions
        self.radius = radius
        self.color = color
        super.init()
        
        lineGenerator.generatePolyline(forNode: self, positions: self.positions, radius: self.radius, color: self.color)
        
    }
    
    //return the appropriate line generator based on the ios version / metal availability
    private static func getValidLineGenerator() -> PolylineGenerator{
        //TODO: first, check if a metal rendering context is available
        
        //then, check if the ios version can support framework shaders
        if #available(iOS 10.0, *) {
            return Polyline_Shader()
        } else {
            return Polyline_Cylinder()
        }
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

}
