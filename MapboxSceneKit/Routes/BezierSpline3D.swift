//
//  BezierSpline3D.swift
//  Examples
//
//  Created by Avi Cieplinski on 8/2/18.
//  Copyright © 2018 MapBox. All rights reserved.
//

import SceneKit
import UIKit

internal class BezierSpline3D {
    public let curvePoints: [SCNVector3]

    public init(curvePoints: [SCNVector3]) {
        self.curvePoints = curvePoints
    }

    public func evaluate(progress: CGFloat) -> SCNVector3 { // Normalized progress through the spline points
        let (_, spineSegmentStartIndex, t) = getProgressProperties(progress: progress, paddedVertices: 1)

        let p0 = curvePoints[spineSegmentStartIndex]
        let p1 = curvePoints[spineSegmentStartIndex + 1]
        let p2 = curvePoints[spineSegmentStartIndex + 2]
        let p3 = curvePoints[spineSegmentStartIndex + 3]

        var a0, a1, a2, a3: SCNVector3
        a0 = p3 - p2 - p0 + p1
        a1 = p0 - p1 - a0
        a2 = p2 - p0
        a3 = p1

        return (a0 * CGFloat(pow(t, 3))) + (a1 * CGFloat(pow(t, 2))) + (a2 * CGFloat(t)) + (a3)
    }

    private func getProgressProperties(progress: CGFloat, paddedVertices pad: Int = 0) -> (CGFloat, Int, Float) { // paddedVertices is the number of unused vertices on the ends
        let absoluteProgress = min(max(progress, 0), 1) * CGFloat(curvePoints.count - 1 - pad * 2) // progress through the curvePoints
        let spineSegmentStartIndex: Int = min(Int(absoluteProgress), curvePoints.count - 2 - pad * 2) // Integer time for the index of the starting curvePoint
        let t = Float(absoluteProgress) - Float(spineSegmentStartIndex) // The time to evaluate the curve at
        return (absoluteProgress, spineSegmentStartIndex, t)
    }
}
