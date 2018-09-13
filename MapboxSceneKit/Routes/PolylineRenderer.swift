//
//  PolylineRenderer.swift
//  MapboxSceneKit
//
//  Created by Jim Martin on 9/12/18.
//  Copyright © 2018 MapBox. All rights reserved.
//

import Foundation
import SceneKit
import Metal

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
        //first, check if a metal rendering context is available
        let device = MTLCreateSystemDefaultDevice()
        if device == nil {
            // No metal rendering context available, fallback to cylinder polylines
            return PolylineCylinder()
        }

        //then, check if the ios version can support framework shaders
        if #available(iOS 10.0, *) {
            return PolylineShader()
        } else {
            return PolylineCylinder()
        }
    }
}
