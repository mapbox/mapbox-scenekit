//
//  StaticConstants.swift
//  Examples
//
//  Created by Jim Martin on 9/28/18.
//  Copyright © 2018 MapBox. All rights reserved.
//
import CoreLocation
import Foundation

struct Constants {
    /// Terrain.rgb isn't available in all areas beyond this value, higher zoom levels are oversampled.
    static let maxTerrainRGBZoomLevel: Int = 12
    
    /// Is the largest supported texture size by the SDK, style images are drawn at 2x this value, so any higher number would result in crashes.
    static let maxTextureImageSize: Int = 2048
    
    static let earthDiameterInKilometers = 40075.16
}
