//
//  BezierSpline3D.swift
//  MapboxSceneKit
//
//  Created by Avi Cieplinski on 8/2/18.
//  Copyright © 2018 MapBox. All rights reserved.
//

import SceneKit
import UIKit

internal class BezierSpline3D {
    public let curvePoints: [SCNVector3]

    private var curveProgressBuckets: [(CGFloat, SCNVector3)] = [(CGFloat, SCNVector3)]()
    private var curveLength = CGFloat(0.0)
    public var length: CGFloat {
        get {
            if curveProgressBuckets.count == 0 {
                self.calculateProgressBuckets()
            }

            return curveLength
        }
    }

    private var subdividedPoints: [(CGFloat, SCNVector3)] {
        get {
            if curveProgressBuckets.count == 0 {
                self.calculateProgressBuckets()
            }

            return curveProgressBuckets
        }
    }

    private func calculateProgressBuckets() -> Void {
        let bucketCount = 100
        var time: Float = 0.0
        let stepSize = 1.0 / Float(bucketCount)
        var distance = Float(0.0)
        var index = 0
        var previousPoint = self.evaluate(progress: 0.0)

        while index < bucketCount {
            let currentPoint = self.evaluate(progress: CGFloat(time))
            distance = previousPoint.distance(vector: currentPoint)
            curveLength += CGFloat(distance)
            curveProgressBuckets.append((curveLength, currentPoint))
            previousPoint = currentPoint
            time += stepSize
            index += 1
        }
    }

    public init(curvePoints: [SCNVector3]) {

        //ensure the the spline has a minimum of 4 handles.
        switch curvePoints.count {
        case 0:
            //no points
            fatalError("BezierSpline3D initialized with an empty array")
        case 1:
            //single point
            self.curvePoints = [curvePoints[0], curvePoints[0], curvePoints[0], curvePoints[0]]
        case 2:
            //straight line, add extra handles at the end points.
            self.curvePoints = [curvePoints[0], curvePoints[0],
                                curvePoints[1], curvePoints[1]]
        case 3:
            //add a single handle at the end
            self.curvePoints = [curvePoints[0], curvePoints[0],
                                curvePoints[1], curvePoints[1],
                                curvePoints[2], curvePoints[2]]
        default:
            self.curvePoints = curvePoints
        }
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

    public func evaluateCurveProgress(atProgress progress: CGFloat) -> SCNVector3 {
        // look for the "bucket" that the requested progress falls into
        var position = SCNVector3(0, 0, 0)
        var index = Int(0)
        let lengthProgress = progress * self.length
        for entry in self.subdividedPoints {
            if index == self.subdividedPoints.count-1 {
                let previousEntry = self.subdividedPoints.last!
                // reached the last entry so it needs to be here
                let lerpValue = self.lerp(progress: progress, min: previousEntry.0, max: lengthProgress)
                position = self.interpolatedPosition(progress: lerpValue, minEntry: previousEntry, maxEntry: entry)
                return position
            }

            let nextEntry = self.subdividedPoints[index+1]

            // if the progress exactly matches one of the bucket start/end values, return that position
            if entry.0 == lengthProgress {
                return entry.1
            } else if nextEntry.0 == lengthProgress {
                return nextEntry.1
            }

            if lengthProgress > entry.0 && lengthProgress < nextEntry.0 {
                // found the right bucket

                // linear interpolate between the min & max entry position to get the value
                let lerpValue = self.lerp(progress: lengthProgress, min: entry.0, max: nextEntry.0)
                position = self.interpolatedPosition(progress: lerpValue, minEntry: entry, maxEntry: nextEntry)

                break
            }

            // keep looking in the next bucket
            index += 1
        }

        return position
    }

    private func getProgressProperties(progress: CGFloat, paddedVertices pad: Int = 0) -> (CGFloat, Int, Float) { // paddedVertices is the number of unused vertices on the ends
        let absoluteProgress = min(max(progress, 0), 1) * CGFloat(curvePoints.count - 1 - pad * 2) // progress through the curvePoints
        let spineSegmentStartIndex: Int = min(Int(absoluteProgress), curvePoints.count - 2 - pad * 2) // Integer time for the index of the starting curvePoint
        let t = Float(absoluteProgress) - Float(spineSegmentStartIndex) // The time to evaluate the curve at
        return (absoluteProgress, spineSegmentStartIndex, t)
    }

    private func lerp(progress: CGFloat, min: CGFloat, max: CGFloat) -> Float {
        return Float((progress - min) / (max - min))
    }

    private func interpolatedPosition(progress:Float, minEntry: (CGFloat, SCNVector3), maxEntry: (CGFloat, SCNVector3)) -> SCNVector3 {
        var position = SCNVector3(0, 0, 0)

        let diffVector = (maxEntry.1 - minEntry.1)
        let lerpVector = SCNVector3(progress * diffVector.x, progress * diffVector.y, progress * diffVector.z)
        position = minEntry.1 + lerpVector

        return position
    }
}

//temporary extension to use this class for color splines
internal extension SCNVector3 {

    func toColor() -> UIColor {
        return UIColor(red: CGFloat(self.x), green: CGFloat(self.y), blue: CGFloat(self.z), alpha: 1.0)
    }

    func toRadius() -> CGFloat {
        return CGFloat(self.x)
    }

    func distance(vector: SCNVector3) -> Float {
        return (self - vector).length()
    }
}
