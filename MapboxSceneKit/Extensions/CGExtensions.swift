import Foundation
import UIKit

internal func * (left: CGSize, right: CGFloat) -> CGSize {
    return CGSize(width: left.width * right, height: left.height * right)
}

internal func *= ( left: inout CGSize, right: CGFloat) {
    left = left * right
}

internal func * (left: UIEdgeInsets, right: CGFloat) -> UIEdgeInsets {
    return UIEdgeInsets(top: left.top * right, left: left.left * right, bottom: left.bottom * right, right: left.right * right)
}

internal func *= ( left: inout UIEdgeInsets, right: CGFloat) {
    left = left * right
}

