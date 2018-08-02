//
//  Spline.swift
//
//  Created by Nathan Flurry on 4/23/16.
//  Copyright © 2016 Nathan Flurry. All rights reserved.
//

import SceneKit

public enum SplineEvaluationMethod {
    case Linear, Cubic, CatmullRom, Hermite(CGFloat, CGFloat)
}

extension SplineEvaluationMethod : Equatable { }

public func ==(lhs: SplineEvaluationMethod, rhs: SplineEvaluationMethod) -> Bool {
    switch (lhs, rhs) {
    case (.Linear, .Linear), (.Cubic, .Cubic), (.Hermite(_, _), .Hermite(_, _)):
        return true
    default:
        return false
    }
}

public enum SplineAxis {
    case X, Y, Z, All
}

public class Spline { // See http://paulbourke.net/miscellaneous/interpolation/
    public let points: [SCNVector3]
    public var method: SplineEvaluationMethod
    
    public init(points: [SCNVector3], method: SplineEvaluationMethod) {
        self.points = points // TODO: Verify there are enough points
        self.method = method
    }
    
    public func evaluate(time: CGFloat) -> SCNVector3 { // Time between 0 and 1
        switch method {
        case .Linear:
            let (_, intTime, t) = getTimeProperties(time: time)
            
            let p0 = points[intTime]
            let p1 = points[intTime + 1]
            
            return p0 * (1 - t) + p1 * t
        case .Cubic, .CatmullRom:
            let (_, intTime, t) = getTimeProperties(time: time, paddedVertices: 1)
            
            let p0 = points[intTime]
            let p1 = points[intTime + 1]
            let p2 = points[intTime + 2]
            let p3 = points[intTime + 3]
            
            var a0, a1, a2, a3: SCNVector3
            if method == .Cubic {
                a0 = p3 - p2 - p0 + p1
                a1 = p0 - p1 - a0
                a2 = p2 - p0
                a3 = p1
            } else {
                a0 = p0 * -0.5
                a0 += p1 * 1.5
                a0 -= p2 * 1.5
                a0 += p3 * 0.5
                
                
                a1 = p0
                a1 -= p1 * 2.5
                a1 += p2 * 2
                a1 -= p3 * 0.5
                
                a2 = p0 * -0.5
                a2 += p2 * 0.5
                
                a3 = p1
            }
            
            return (a0 * CGFloat(pow(t, 3))) + (a1 * CGFloat(pow(t, 2))) + (a2 * CGFloat(t)) + (a3)
        case .Hermite(let tension, let bias):
            let (_, intTime, t) = getTimeProperties(time: time, paddedVertices: 1)
            
            let p0 = points[intTime]
            let p1 = points[intTime + 1]
            let p2 = points[intTime + 2]
            let p3 = points[intTime + 3]
            
            let t2 = t * t;
            let t3 = t2 * t;
            
//            let m0  = (p1 - p0) * (1 + bias) * (1 - tension) / 2 + (p2 - p1) * (1 - bias) * (1 - tension) / 2
//            let m1  = (p2 - p1) * (1 + bias) * (1 - tension) / 2 + (p3 - p2) * (1 - bias) * (1 - tension) / 2
            var m00 = (p1 - p0) * (1.0 + bias) // Split up these lines for the compiler
            m00 = m00 * (1.0 - tension) / 2.0
            var m01 = (p2 - p1) * (1.0 - bias)
            m01 = m01 * (1.0 - tension) / 2.0
            let m0 = m00 + m01
            var m10 = (p2 - p1) * (1 + bias)
            m10 = m10 * (1 - tension) / 2
            var m11 = (p3 - p2) * (1 - bias)
            m11 = m11 * (1 - tension) / 2
            let m1 = m10 + m11

            let a0 =  2 * t3 - 3 * t2 + 1
            let a1 =      t3 - 2 * t2 + t
            let a2 =      t3 -     t2
            let a3 = -2 * t3 + 3 * t2
            
//            return (a0 * p1) + (a1 * m0) + (a2 * m1) + (a3 * p2)
            let r1 = (p1 * a0) + (m0 * a1) // Split up these lines for the compiler
            let r2 = (m1 * a2) + (p2 * a3)
            return r1 + r2
        }
    }
    
    public func evaluateRotation(time: CGFloat, axis: SplineAxis, samplePrecision precision: CGFloat = 20) -> SCNVector3 {
        // Find two positions on either side of the time to attempt to approximate the angle; this could be done better and more efficiently
        let range = 1 / CGFloat(points.count) / precision // The range at which to sample
        let vector = evaluate(time: time + range) - evaluate(time: time - range) // The approximate derivative of the point
        switch axis {
        case .X:
            return SCNVector3(
                atan2(vector.y, vector.z),
                0,
                0
            )
        case .Y:
            return SCNVector3(
                0,
                atan2(vector.x, vector.z),
                0
            )
        case .Z:
            return SCNVector3(
                0,
                0,
                atan2(vector.x, vector.y)
            )
        case .All:
            return SCNVector3(
                atan2(vector.y, vector.z),
                atan2(vector.x, vector.z),
                atan2(vector.x, vector.y)
            )
        }
    }
    
    private func getTimeProperties(time: CGFloat, paddedVertices pad: Int = 0) -> (CGFloat, Int, CGFloat) { // paddedVertices is the number of unused vertices on the ends
        let absoluteTime = min(max(time, 0), 1) * CGFloat(points.count - 1 - pad * 2) // Time throughout the entire curve
        let intTime: Int = min(Int(absoluteTime), points.count - 2 - pad * 2) // Integer time for the starting index
        let t = absoluteTime - CGFloat(intTime) // The time to evaluate the curve at
        return (absoluteTime, intTime, t)
    }
}
