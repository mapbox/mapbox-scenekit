//
//  BezierSpline3D.swift
//  Examples
//
//  Created by Avi Cieplinski on 8/2/18.
//  Copyright © 2018 MapBox. All rights reserved.
//

import SceneKit
import UIKit

public struct BezierSplineSegment
{
    let curvePoint1: SCNVector3
    let curvePoint2: SCNVector3
    let controlPoint1: SCNVector3
    let controlPoint2: SCNVector3
}

public class BezierSpline3D {
    public let curvePoints: [SCNVector3]
    public var splineSegments: [BezierSplineSegment] = [BezierSplineSegment]()
    public var controlPoints: [SCNVector3]? = nil
    private var firstControlPoints: [SCNVector3?] = []
    private var secondControlPoints: [SCNVector3?] = []

    public init(curvePoints: [SCNVector3]) {
        self.curvePoints = curvePoints

        // calculate our control points based on the supplied curvePoints
        generateControlPointsFromCurvePoints(curvePoints: curvePoints)
    }

    // Based on https://github.com/Ramshandilya/Bezier
    private func generateControlPointsFromCurvePoints(curvePoints: [SCNVector3]) -> Void {
        //Number of Segments
        let count = curvePoints.count - 1

        //P0, P1, P2, P3 are the points for each segment, where P0 & P3 are the knots and P1, P2 are the control points.
        if count == 1 {
            let P0 = curvePoints[0]
            let P3 = curvePoints[1]

            //Calculate First Control Point
            //3P1 = 2P0 + P3

            let P1x = (2*P0.x + P3.x)/3
            let P1y = (2*P0.y + P3.y)/3
            let P1z = (2*P0.z + P3.z)/3

            firstControlPoints.append(SCNVector3(P1x, P1y, P1z))

            //Calculate second Control Point
            //P2 = 2P1 - P0
            let P2x = (2*P1x - P0.x)
            let P2y = (2*P1y - P0.y)
            let P2z = (2*P1z - P0.z)

            secondControlPoints.append(SCNVector3(P2x, P2y, P2z))
        } else {
            firstControlPoints = Array(repeating: nil, count: count)// Array(count: count)//Array(count: count, repeatedValue: nil)

            var rhsArray = [SCNVector3]()

            //Array of Coefficients
            var a = [Double]()
            var b = [Double]()
            var c = [Double]()

            for i in 0..<count {
                var rhsValueX: Float = 0
                var rhsValueY: Float = 0
                var rhsValueZ: Float = 0

                let P0 = curvePoints[i]
                let P3 = curvePoints[i+1]

                if i==0 {
                    a.append(0)
                    b.append(2)
                    c.append(1)

                    //rhs for first segment
                    rhsValueX = P0.x + 2*P3.x
                    rhsValueY = P0.y + 2*P3.y
                    rhsValueZ = P0.z + 2*P3.z

                } else if i == count-1 {
                    a.append(2)
                    b.append(7)
                    c.append(0)

                    //rhs for last segment
                    rhsValueX = 8*P0.x + P3.x;
                    rhsValueY = 8*P0.y + P3.y;
                    rhsValueZ = 8*P0.z + P3.z;
                } else {
                    a.append(1)
                    b.append(4)
                    c.append(1)

                    rhsValueX = 4*P0.x + 2*P3.x;
                    rhsValueY = 4*P0.y + 2*P3.y;
                    rhsValueZ = 4*P0.z + 2*P3.z;
                }

                rhsArray.append(SCNVector3(x: rhsValueX, y: rhsValueY, z: rhsValueZ))
            }

            //Solve Ax=B. Use Tridiagonal matrix algorithm a.k.a Thomas Algorithm

            for i in 1..<count {
                let rhsValueX = rhsArray[i].x
                let rhsValueY = rhsArray[i].y
                let rhsValueZ = rhsArray[i].z

                let prevRhsValueX = rhsArray[i-1].x
                let prevRhsValueY = rhsArray[i-1].y
                let prevRhsValueZ = rhsArray[i-1].z

                let m = Float(a[i]/b[i-1])

                let b1 = b[i] - Double(m) * c[i-1]
                b[i] = b1

                let r2x = rhsValueX - m * prevRhsValueX
                let r2y = rhsValueY - m * prevRhsValueY
                let r2z = rhsValueZ - m * prevRhsValueZ

                rhsArray[i] = SCNVector3(x: r2x, y: r2y, z: r2z)
            }

            //Get First Control Points

            //Last control Point
            let lastControlPointX = rhsArray[count-1].x/Float(b[count-1])
            let lastControlPointY = rhsArray[count-1].y/Float(b[count-1])
            let lastControlPointZ = rhsArray[count-1].z/Float(b[count-1])

            firstControlPoints[count-1] = SCNVector3(x: lastControlPointX, y: lastControlPointY, z: lastControlPointZ)

            for i in stride(from: count-2, to: -1, by: -1) {
                if let nextControlPoint = firstControlPoints[i+1] {
                    let controlPointX = (rhsArray[i].x - Float(Float(c[i]) * nextControlPoint.x))/(Float(b[i]))
                    let controlPointY = (rhsArray[i].y - Float(Float(c[i]) * nextControlPoint.y))/(Float(b[i]))
                    let controlPointZ = (rhsArray[i].z - Float(Float(c[i]) * nextControlPoint.z))/(Float(b[i]))

                    firstControlPoints[i] = SCNVector3(x: controlPointX, y: controlPointY, z: controlPointZ)
                }
            }

            //Compute second Control Points from first

            for i in 0..<count {
                if i == count-1 {
                    let P3 = curvePoints[i+1]

                    guard let P1 = firstControlPoints[i] else {
                        continue
                    }

                    let controlPointX = (P3.x + P1.x)/2
                    let controlPointY = (P3.y + P1.y)/2
                    let controlPointZ = (P3.z + P1.z)/2

                    secondControlPoints.append(SCNVector3(x: controlPointX, y: controlPointY, z: controlPointZ))

                } else {
                    let P3 = curvePoints[i+1]

                    guard let nextP1 = firstControlPoints[i+1] else {
                        continue
                    }

                    let controlPointX = 2*P3.x - nextP1.x
                    let controlPointY = 2*P3.y - nextP1.y
                    let controlPointZ = 2*P3.z - nextP1.z

                    secondControlPoints.append(SCNVector3(x: controlPointX, y: controlPointY, z: controlPointZ))
                }
            }
        }

        for i in 0..<count {
            if let firstControlPoint = firstControlPoints[i],
                let secondControlPoint = secondControlPoints[i] {
                let segment = BezierSplineSegment(curvePoint1: curvePoints[i], curvePoint2: curvePoints[i+1], controlPoint1: firstControlPoint, controlPoint2: secondControlPoint)
                self.splineSegments.append(segment)
                controlPoints?.append(firstControlPoint)
                controlPoints?.append(secondControlPoint)
            }
        }
    }

    public func evaluate(progress: CGFloat) -> SCNVector3 { // Normalized progress through the spline points
        let (_, spineSegmentStartIndex, t) = getProgressProperties(progress: progress, paddedVertices: 1)

        let p0 = curvePoints[spineSegmentStartIndex]
        let p1 = curvePoints[spineSegmentStartIndex + 1]
        let p2 = curvePoints[spineSegmentStartIndex + 2]
        let p3 = curvePoints[spineSegmentStartIndex + 3]

        #if false
        let oneMinusT = Float(1.0 - t);
        let firstTerm = p0 * (oneMinusT * oneMinusT * oneMinusT)
        let secondTerm = p1 * (3.0 * oneMinusT * oneMinusT * t)
        let thirdTerm = p2 * (3.0 * oneMinusT * t * t)
        let fourthTerm = p3 * (t * t * t)
        return  firstTerm + secondTerm + thirdTerm + fourthTerm

        #else

        var a0, a1, a2, a3: SCNVector3
        a0 = p3 - p2 - p0 + p1
        a1 = p0 - p1 - a0
        a2 = p2 - p0
        a3 = p1

        // a0 * (t^3) + a1 * (t^2) + a2 * t + a3
        //
        // (p3 - p2 - p0 + p1)*(t^3) + (p0 - p1 - (p3 - p2 - p0 + p1))*(t^2)) + (p2 - p0)*(t) + p1
        // (p3 - p2 - p0 + p1)*(t^3) + (2p0 - p3 + p2)(t^2) + p2t - p0t + p1
        // (p3*t^3 - p2*t^3 - p0*t^3 + p1*t^3 + 2p0*t^2 - p3*t^2 + p2&t^2 + p2*t - p0*t + p1
        // (p3*t^3 - p3*t^2) + (-p2*t^3 p2*t^2 + p2*t) + p1*t^3 + p1 + (-p0*t^3 + 2p0*t^2 - p0*t)
        // t^2(p3*t - p3) + t(-p2*t^2 + p2*t + p2) + p1(t^3 + 1) + p0*t*(-t^2 + t - 1)
        // t^2(p3*t - p3) + p2*t(-t^2 + t + 1) + p1(t^3 + 1) + p0*t*(-t^2 + t - 1)
        return (a0 * CGFloat(pow(t, 3))) + (a1 * CGFloat(pow(t, 2))) + (a2 * CGFloat(t)) + (a3)
        #endif
    }

    private func getProgressProperties(progress: CGFloat, paddedVertices pad: Int = 0) -> (CGFloat, Int, Float) { // paddedVertices is the number of unused vertices on the ends
        let absoluteProgress = min(max(progress, 0), 1) * CGFloat(curvePoints.count - 1 - pad * 2) // progress through the curvePoints
        let spineSegmentStartIndex: Int = min(Int(absoluteProgress), curvePoints.count - 2 - pad * 2) // Integer time for the index of the starting curvePoint
        let t = Float(absoluteProgress) - Float(spineSegmentStartIndex) // The time to evaluate the curve at
        return (absoluteProgress, spineSegmentStartIndex, t)
    }
}
