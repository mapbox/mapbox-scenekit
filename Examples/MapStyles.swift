//
//  MapStyles.swift
//  Examples
//
//  Created by Steven Rockarts on 2018-10-25.
//  Copyright © 2018 MapBox. All rights reserved.
//

import Foundation

struct MapStyles {
    public static let streets:DefaultStyle = DefaultStyle(url:"mapbox/streets-v10", name:"Streets", currentVersion:10)
    static let outdoors:DefaultStyle = DefaultStyle(url:"mapbox/outdoors-v10", name:"Outdoors", currentVersion:10)
    static let light:DefaultStyle = DefaultStyle(url:"mapbox/light-v9", name:"Light", currentVersion:9)
    static let dark:DefaultStyle = DefaultStyle(url:"mapbox/dark-v9", name:"Dark", currentVersion: 9)
    static let satellite:DefaultStyle = DefaultStyle(url:"mapbox/satellite-v9", name:"Satellite",currentVersion: 9)
    static let satelliteStreets:DefaultStyle = DefaultStyle(url:"mapbox/satellite-streets-v10", name:"Satellite Streets", currentVersion:10)
    static let navigationPreviewDay:DefaultStyle = DefaultStyle(url: "mapbox/navigation-preview-day-v2", name:"Navigation Preview Day", currentVersion: 2)
    
    static let allStyles:[String] = [streets.url, outdoors.url, light.url, dark.url, satellite.url, satelliteStreets.url, navigationPreviewDay.url]
    
    struct DefaultStyle {
        let url:String
        let name:String
        let currentVersion:Int
    }
}
