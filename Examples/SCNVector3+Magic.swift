//
//  SCNVector3+Magic.swift
//
//  Created by Nathan Flurry on 4/23/16.
//  Copyright © 2016 Nathan Flurry. All rights reserved.
//

import SceneKit

// MARK: VectorFloat
// Used for SCNVector3s to determine the type of float they use
#if os(iOS)
typealias VectorFloat = Float
#elseif os(OSX)
typealias VectorFloat = CGFloat
#endif

// Shorthand for VectorFloat
typealias VFloat = VectorFloat

// MARK: Protocol spaghetti
// Let Float and CGFloat be convertable between eachother and do math with them
protocol FloatConvertible {
    init(_ value: CGFloat)
    init(_ value: Float)
}
protocol FloatConvertibleMathable: FloatConvertible {
    static func +(lhs: Self, rhs: Self) -> Self
    static func -(lhs: Self, rhs: Self) -> Self
    static func *(lhs: Self, rhs: Self) -> Self
    static func /(lhs: Self, rhs: Self) -> Self
    
    static func +=(lhs: inout Self, rhs: Self)
    static func -=(lhs: inout Self, rhs: Self)
}
extension Float: FloatConvertibleMathable { }
extension Double: FloatConvertibleMathable { }
extension CGFloat: FloatConvertibleMathable { init(_ value: CGFloat) { self.init(Float(value)) } }

// MARK: VFloat extension
// Let VFloats be created with a FloatConvertible
extension VFloat {
    init(_ value: FloatConvertible) {
        if let v = value as? Float {
            self.init(v)
        } else if let v = value as? Double {
            self.init(v)
        } else if let v = value as? CGFloat {
            self.init(v)
        } else {
            print("Could not conver FloatConvertible to VFloat. \(value)")
            self.init(0)
        }
    }
}

// MARK: Operators
func +(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
    return SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
}

func -(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
    return lhs + (-rhs)
}

func *(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
    return SCNVector3(lhs.x * rhs.x, lhs.y * rhs.y, lhs.z * rhs.z)
}

func *<T: FloatConvertibleMathable>(lhs: SCNVector3, rhs: T) -> SCNVector3 {
    return SCNVector3(
        VFloat(T(lhs.x) * rhs),
        VFloat(T(lhs.y) * rhs),
        VFloat(T(lhs.z) * rhs)
    )
}

func +=(lhs: inout SCNVector3, rhs: SCNVector3) {
    lhs.x += rhs.x
    lhs.y += rhs.y
    lhs.z += rhs.z
}

func -=(lhs: inout SCNVector3, rhs: SCNVector3) {
    lhs.x -= rhs.x
    lhs.y -= rhs.y
    lhs.z -= rhs.z
}

func /(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
    return SCNVector3(lhs.x / rhs.x, lhs.y / rhs.y, lhs.z / rhs.z)
}

func /(lhs: SCNVector3, rhs: CGFloat) -> SCNVector3 {
    return SCNVector3(VFloat(CGFloat(lhs.x) / rhs), VFloat(CGFloat(lhs.y) / rhs), VFloat(CGFloat(lhs.z) / rhs))
}

func /<T: FloatConvertibleMathable>(lhs: SCNVector3, rhs: T) -> SCNVector3 {
    return SCNVector3(
        VFloat(T(lhs.x) / rhs),
        VFloat(T(lhs.y) / rhs),
        VFloat(T(lhs.z) / rhs)
    )
}

prefix func -(vector: SCNVector3) -> SCNVector3 {
    return SCNVector3(-vector.x, -vector.y, -vector.z)
}

func * (quat: SCNQuaternion, vec: SCNVector3) -> SCNVector3 {
    let num = quat.x * 2
    let num2 = quat.y * 2
    let num3 = quat.z * 2
    let num4 = quat.x * num
    let num5 = quat.y * num2
    let num6 = quat.z * num3
    let num7 = quat.x * num2
    let num8 = quat.x * num3
    let num9 = quat.y * num3
    let num10 = quat.w * num
    let num11 = quat.w * num2
    let num12 = quat.w * num3
    let x = (1 - (num5 + num6)) * vec.x + (num7 - num12) * vec.y + (num8 + num11) * vec.z
    let y = (num7 + num12) * vec.x + (1 - (num4 + num6)) * vec.y + (num9 - num10) * vec.z
    let z = (num8 - num11) * vec.x + (num9 + num10) * vec.y + (1 - (num4 + num5)) * vec.z
    return SCNVector3(x, y, z)
}

func +(lhs: SCNVector4, rhs: SCNVector4) -> SCNVector4 {
    return SCNVector4(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z, lhs.w + rhs.w)
}
