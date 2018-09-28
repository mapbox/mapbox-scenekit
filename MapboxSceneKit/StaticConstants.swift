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
    static let maxTextureImageSize: Int = 2048 // set a max texture size in order to dynamically calculate the highest zoom level for a given lat/lon bounding rect. Need to balance download speed and detail, so set to 1MB for now
    
    static let earthDiameterInKilometers = 40075.16
}
