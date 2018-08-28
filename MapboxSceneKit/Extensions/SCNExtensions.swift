import Foundation
import SceneKit

internal func SCNVector3Length(vector: SCNVector3) -> Float {
    return sqrtf(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}

internal func SCNVector3Normalize(vector: SCNVector3) -> SCNVector3 {
    return vector / SCNVector3Length(vector: vector)
}

internal func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}

internal func += ( left: inout SCNVector3, right: SCNVector3) {
    left = left + right
}

internal func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
}

internal func -= ( left: inout SCNVector3, right: SCNVector3) {
    left = left - right
}

internal func * (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x * right.x, left.y * right.y, left.z * right.z)
}

internal func *= ( left: inout SCNVector3, right: SCNVector3) {
    left = left * right
}

internal func * (vector: SCNVector3, scalar: Float) -> SCNVector3 {
    return SCNVector3Make(vector.x * scalar, vector.y * scalar, vector.z * scalar)
}

internal func *= ( vector: inout SCNVector3, scalar: Float) {
    vector = vector * scalar
}

internal func / (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x / right.x, left.y / right.y, left.z / right.z)
}

internal func /= ( left: inout SCNVector3, right: SCNVector3) {
    left = left / right
}

internal func / (vector: SCNVector3, scalar: Float) -> SCNVector3 {
    return SCNVector3Make(vector.x / scalar, vector.y / scalar, vector.z / scalar)
}

internal func /= ( vector: inout SCNVector3, scalar: Float) {
    vector = vector / scalar
}

internal func SCNVector3CrossProduct(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.y * right.z - left.z * right.y, left.z * right.x - left.x * right.z, left.x * right.y - left.y * right.x)
}

