//
//  SCNProgramExtensions.swift
//  MapboxSceneKit
//
//  Created by Jim Martin on 8/17/18.
//  Copyright © 2018 MapBox. All rights reserved.
//

import Foundation
import SceneKit


@available(iOS 10.0, *)
extension SCNProgram {
    /// By default, SCNPrograms use the main bundle's default library to find shader functions.
    /// This extension finds the bundle containing the input class, and uses that bundle's default MTLLibrary.
    ///
    /// - Parameter myClass: The class used to lookup metal libraries outside the main bundle, likely from an imported framework.
    public convenience init( withLibraryForClass myClass: AnyClass ){
        self.init()
        let classBundle = Bundle(for: myClass)
        let device = MTLCreateSystemDefaultDevice()
        do {
            let bundleLib = try device?.makeDefaultLibrary(bundle: classBundle)
            self.library = bundleLib
        } catch {
            print("Couldn't locate default library for bundle: \(classBundle)")
            print( error )
        }
    }
}
