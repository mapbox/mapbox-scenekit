//
//  BezierSolver3D.swift
//  Portfolio
//
//  Created by Avi Cieplinski on 7/30/18.
//  Copyright © 2018 Avi Cieplinski. All rights reserved.
//

import Foundation
import SceneKit
import UIKit


struct CubicCurveSegment
{
    let controlPoint1: SCNVector3
    let controlPoint2: SCNVector3
}

class BezierSolver3D
{
    private var firstControlPoints: [SCNVector3?] = []
    private var secondControlPoints: [SCNVector3?] = []

    func controlPointsFromCurvePoints(curvePoints: [SCNVector3]) -> [CubicCurveSegment] {
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

                    guard let P1 = firstControlPoints[i] else{
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

        var controlPoints = [CubicCurveSegment]()

        for i in 0..<count {
            if let firstControlPoint = firstControlPoints[i],
                let secondControlPoint = secondControlPoints[i] {
                let segment = CubicCurveSegment(controlPoint1: firstControlPoint, controlPoint2: secondControlPoint)
                controlPoints.append(segment)
            }
        }

        return controlPoints
    }
}
