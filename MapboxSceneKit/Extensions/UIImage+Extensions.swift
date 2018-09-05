//
//  UIImage+Extensions.swift
//  MapboxSceneKit
//
//  Created by Avi Cieplinski on 9/5/18.
//  Copyright © 2018 MapBox. All rights reserved.
//

import UIKit

extension UIImage {
    func scaleImage(scaleFactor: CGFloat) -> UIImage {
        let width = size.width * scaleFactor
        let height = size.height * scaleFactor
        let bitsPerComponent = cgImage!.bitsPerComponent
        let bytesPerRow = scaleFactor * CGFloat(cgImage!.bytesPerRow)
        let colorSpace = cgImage!.colorSpace
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast

        let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: bitsPerComponent, bytesPerRow: Int(bytesPerRow), space: colorSpace!, bitmapInfo: bitmapInfo.rawValue)

        context?.interpolationQuality = .high

        context?.draw(cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))

        let scaledImage = context!.makeImage().flatMap { UIImage(cgImage: $0) }

        return scaledImage!
    }
}
