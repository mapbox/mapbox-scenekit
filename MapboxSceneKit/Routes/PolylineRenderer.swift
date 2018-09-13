//
//  PolylineRenderer.swift
//  MapboxSceneKit
//
//  Created by Jim Martin on 9/12/18.
//  Copyright © 2018 MapBox. All rights reserved.
//

import Foundation
import SceneKit

/// Implement this protocol to define new line rendering behavior
internal protocol PolylineRenderer {
    
    func render(_ polyline: PolylineNode, withSampleCount sampleCount: Int)
}

/// Responsible for selecting the correct renderer based on iOS version or GPU context.
internal class PolylineRendererVersion {
    
    /// Change linerenderer class based on the ios version / metal availability
    ///
    /// - Returns: The best linerenderer for the current platform
    public static func getValidRenderer() -> PolylineRenderer {
        //TODO: first, check if a metal rendering context is available
        
        //then, check if the ios version can support framework shaders
        if #available(iOS 10.0, *) {
            return Polyline_Shader()
        } else {
            return Polyline_Cylinder()
        }
    }
}
