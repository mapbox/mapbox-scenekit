import Foundation
import UIKit

internal final class ImageBuilder {
    private let context: CGContext?
    private let clippedRect: CGRect
    private let tileSize: CGSize
    private let imageSize: CGSize
    private let compositingDispatchQueue = DispatchQueue(label: "com.mapbox.SceneKit.compositing", attributes: .concurrent)

    init(xs: Int, ys: Int, tileSize: CGSize, insets: UIEdgeInsets) {
        self.imageSize = CGSize(width: CGFloat(xs) * tileSize.width, height: CGFloat(ys) * tileSize.height)
        let finalSize = CGSize(width: imageSize.width - insets.left - insets.right,
                               height: imageSize.height - insets.top - insets.bottom)
        self.clippedRect = CGRect(x: insets.left, y: insets.top, width: finalSize.width, height: finalSize.height)
        self.tileSize = tileSize
        let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        context = CGContext(data: nil, width: Int(imageSize.width), height: Int(imageSize.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)

        if context == nil {
            NSLog("Error creating CGContext")
        }
    }

    func addTile(x: Int, y: Int, image: UIImage) {
        compositingDispatchQueue.sync(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            context?.draw(image.cgImage!, in: CGRect(origin: CGPoint(x: CGFloat(x) * self.tileSize.width, y: CGFloat(Int(self.imageSize.height / self.tileSize.height) - y - 1) * self.tileSize.height), size: self.tileSize))
        }
    }

    func makeImage() -> UIImage? {
        guard let fullImageRef = context?.makeImage(), let croppedImageRef = fullImageRef.cropping(to: clippedRect) else {
            return nil
        }
        return UIImage(cgImage: croppedImageRef)
    }
}
