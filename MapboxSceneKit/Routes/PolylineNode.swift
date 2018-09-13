//
//  PolylineNode.swift
//  MapboxSceneKit
//
//  Created by Jim Martin on 9/11/18.
//  Copyright © 2018 MapBox. All rights reserved.
//

import Foundation
import SceneKit

//MARK: - Constructors
public class PolylineNode: SCNNode {
    
    private var lineRenderer : PolylineRenderer
    
    let positionCurve: BezierSpline3D
    let colorCurve: BezierSpline3D
    let radiusCurve: BezierSpline3D
    
    /// PolylineNode is a line drawn through the given positions. Can be sampled later at any point on the line.
    ///
    /// - Parameters:
    ///   - positions: The list of SCNVector3 positions. The line is drawn through each position consectutively from 0...n
    ///   - radius: The width of the line in local space
    ///   - color: The color of the line
    public init( positions: [SCNVector3], radius: CGFloat, color: UIColor ) {
        
        //Find and instantiate the appropriate renderer
        self.lineRenderer = PolylineRendererVersion.getValidRenderer()
        
        //define the polyline's curves from the inputs
        positionCurve = BezierSpline3D(curvePoints: positions)
        colorCurve = BezierSpline3D(curvePoints: [color, color, color, color])
        radiusCurve = BezierSpline3D(curvePoints: [radius, radius, radius, radius])
        
        super.init()
        
        //render the line
        lineRenderer.render(self, withSampleCount: positions.count)
    }
    
    @available(iOS 10.0, *)
    /// PolylineNode is a line drawn through the given positions. Can be sampled later at any point on the line.
    ///
    /// - Parameters:
    ///   - positions: The list of SCNVector3 positions. The line is drawn through each position consectutively from 0...n
    ///   - startRadius: The width of the initial point of the line. Linearly interpolated from start to end positions.
    ///   - endRadius: The width of the final point of the line. Linearly interpolated from start to end positions.
    ///   - startColor: The color of the initial point of the line. Linearly interpolated through RGB color space from start to end.
    ///   - endColor: The color of the final point of the line. Linearly interpolated through RGB color space from start to end.
    public init( positions: [SCNVector3], startRadius: CGFloat, endRadius: CGFloat, startColor: UIColor, endColor: UIColor){
        
        //Find and instantiate the appropriate renderer
        self.lineRenderer = PolylineRendererVersion.getValidRenderer()
        
        //define the polyline's curves from the inputs
        positionCurve = BezierSpline3D(curvePoints: positions)
        colorCurve = BezierSpline3D(curvePoints: [startColor, startColor, endColor, endColor])
        radiusCurve = BezierSpline3D(curvePoints: [startRadius, startRadius, endRadius, endRadius])
        
        super.init()
        
        //render the line
        lineRenderer.render(self, withSampleCount: positions.count)
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

//MARK: - Public methods
public extension PolylineNode {
    
    /// Position along the polyline
    ///
    /// - Parameter progress: normalized progress along the polyline. 0.0 = the beginning, 0.5 = halfway, 1.0 = the end of the line.
    /// - Returns: the local position at the given progress
    func getPositon(atProgress progress: CGFloat) -> SCNVector3{
        return positionCurve.evaluate(progress: progress);
    }
    
    /// Radius along the polyline
    ///
    /// - Parameter progress: normalized progress along the polyline. 0.0 = the beginning, 0.5 = halfway, 1.0 = the end of the line.
    /// - Returns: the radius at the given progress
    func getRadius(atProgress progress: CGFloat) -> CGFloat{
        return radiusCurve.evaluate(progress: progress).toRadius();
    }
    
    /// Color along the polyline
    ///
    /// - Parameter progress: normalized progress along the polyline. 0.0 = the beginning, 0.5 = halfway, 1.0 = the end of the line.
    /// - Returns: the UIColor at the given progress
    func getColor(atProgress progress: CGFloat) -> UIColor{
        return colorCurve.evaluate(progress: progress).toColor();
    }
}

//temporary extension to use the bezierspline class for color splines, doesn't support alpha
fileprivate extension BezierSpline3D {
    convenience init(curvePoints: [UIColor]) {
        var points = [SCNVector3]()
        for color  in curvePoints {
            var r1 : CGFloat = 0
            var g1 : CGFloat = 0
            var b1 : CGFloat = 0
            var a1 : CGFloat = 0
            color.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            
            points.append(SCNVector3(r1, g1, b1))
        }
        self.init(curvePoints: points)
    }
    
    convenience init(curvePoints: [CGFloat]) {
        var points = [SCNVector3]()
        for radius  in curvePoints {
            points.append(SCNVector3(radius, 0, 0))
        }
        self.init(curvePoints: points)
    }
}
