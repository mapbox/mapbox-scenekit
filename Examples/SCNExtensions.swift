import Foundation
import SceneKit

extension SCNVector3 {
    func negate() -> SCNVector3 {
        return self * -1
    }

    mutating func negated() -> SCNVector3 {
        self = negate()
        return self
    }

    func length() -> Float {
        return sqrtf(x * x + y * y + z * z)
    }

    func normalized() -> SCNVector3 {
        return self / length()
    }

    mutating func normalize() -> SCNVector3 {
        self = normalized()
        return self
    }

    func distance(vector: SCNVector3) -> Float {
        return (self - vector).length()
    }

    func dot(vector: SCNVector3) -> Float {
        return x * vector.x + y * vector.y + z * vector.z
    }

    func cross(vector: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(y * vector.z - z * vector.y, z * vector.x - x * vector.z, x * vector.y - y * vector.x)
    }
}

func SCNVector3Length(vector: SCNVector3) -> Float {
    return sqrtf(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}

func SCNVector3Normalize(vector: SCNVector3) -> SCNVector3 {
    return vector / SCNVector3Length(vector: vector)
}

func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}

func += ( left: inout SCNVector3, right: SCNVector3) {
    left = left + right
}

func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
}

func -= ( left: inout SCNVector3, right: SCNVector3) {
    left = left - right
}

func * (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x * right.x, left.y * right.y, left.z * right.z)
}

func *= ( left: inout SCNVector3, right: SCNVector3) {
    left = left * right
}

func * (vector: SCNVector3, scalar: Float) -> SCNVector3 {
    return SCNVector3Make(vector.x * scalar, vector.y * scalar, vector.z * scalar)
}

func *= ( vector: inout SCNVector3, scalar: Float) {
    vector = vector * scalar
}

func / (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x / right.x, left.y / right.y, left.z / right.z)
}

func /= ( left: inout SCNVector3, right: SCNVector3) {
    left = left / right
}

func / (vector: SCNVector3, scalar: Float) -> SCNVector3 {
    return SCNVector3Make(vector.x / scalar, vector.y / scalar, vector.z / scalar)
}

func /= ( vector: inout SCNVector3, scalar: Float) {
    vector = vector / scalar
}

func SCNVector3CrossProduct(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.y * right.z - left.z * right.y, left.z * right.x - left.x * right.z, left.x * right.y - left.y * right.x)
}

