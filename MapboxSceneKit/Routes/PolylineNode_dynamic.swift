//
//  LineNode.swift
//  line-rendering
//
//  Created by Jim Martin on 8/2/18.
//  Copyright © 2018 Jim Martin. All rights reserved.
//

import Foundation
import SceneKit
import Metal

/// PolylineNode generates line geometry through a list of positions, and uses a Metal Shader to give that geometry a set radius in screen-space. Not compatible with iOS simulator builds.
///
/// - Parameters:
///   - positions: The list of SCNVector3 positions. The line is drawn through each position consectutively from 0...n
///   - startRadius: The width of the initial point of the line. Linearly interpolated from start to end positions.
///   - endRadius: The width of the final point of the line. Linearly interpolated from start to end positions.
///   - startColor: The color of the initial point of the line. Linearly interpolated through RGB color space from start to end.
///   - endColor: The color of the final point of the line. Linearly interpolated through RGB color space from start to end.
///   - handleGeometryOverlap: !Experimental! Flag indicating whether the line radius should be used to handle overlap/z-fighting per-pixel. Greatly improves visual quality of lines intersecting with other geometry, but at some cost to performance. May create graphical artifacts on some devices.

@available(iOS 10.0, *)
internal class PolylineNode_dynamic: SCNNode {
    
    private var positions: [SCNVector3] = [SCNVector3Zero]
    private var startRadius: CGFloat = 0.1
    private var endRadius: CGFloat = 0.5
    private var startColor: UIColor = UIColor.yellow
    private var endColor: UIColor = UIColor.white
    private var handleGeometryOverlap: Bool = false
    
    //derived from position, radius, and color settings
    private var verts: [SCNVector3]! //components -> quads
    private var normals: [SCNVector3]! //Appears as 'neighbors' in the vertex input. Used to pass the line segment(direction and magnitude) to each vertex.
    private var indices: [Int32]!
    private var uvs: [CGPoint]! //uv per vert, indicating the corner of the quad
    private var colors: [SCNVector4]! //vertex colors
    private var lineParams: [CGPoint]! //line radius captured in y value
    
    @objc
    public init( positions: [SCNVector3],
                      startRadius: CGFloat, endRadius: CGFloat,
                      startColor: UIColor, endColor: UIColor,
                      handleGeometryOverlap: Bool = true) {
        super.init()
        self.positions = positions
        self.startRadius = startRadius
        self.endRadius = endRadius
        self.startColor = startColor
        self.endColor = endColor
        self.handleGeometryOverlap = handleGeometryOverlap
        setMaterial()
    }
    
    private func setMaterial(){
        
        self.geometry = generateGeometry()
        
        //assign materials using the scenekit metal library
        let lineMaterial = SCNMaterial()
        let program = SCNProgram(withLibraryForClass: type(of: self))
        program.fragmentFunctionName = "lineFrag"
        program.vertexFunctionName = "lineVert"
        program.isOpaque = false
        lineMaterial.program = program
        lineMaterial.isDoubleSided = true
        lineMaterial.blendMode = .alpha
        self.geometry?.firstMaterial = lineMaterial
    }
    
    private func generateGeometry() -> SCNGeometry{
        
        //reset geometry
        verts = []
        uvs = []
        colors = []
        lineParams = []
        normals = []
        indices = []
        
        //step forward through positions and add lines first
        for (index, position) in positions.enumerated() where index != 0{
            let lastPosition = positions[index - 1]
            addLine(from: lastPosition, to: position, withIndex: index)
        }
        
        //step backwards and add caps
        //we want the vertex transforms calculate for the lines first, so that alpha transparency appears correctly on the caps.
        for (index, position) in positions.enumerated().reversed(){
            addCap(atPosition: position, withIndex: index )
        }
        
        //create geometry from sources
        let vertSource = SCNGeometrySource(vertices: verts)
        let normalSource = SCNGeometrySource(normals: normals)
        let uvSource = SCNGeometrySource(textureCoordinates: uvs)
        let colorSource = SCNGeometrySource(colors: colors)
        let lineDimensionSource = SCNGeometrySource(textureCoordinates: lineParams)
        let elements = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        return SCNGeometry(sources: [vertSource, normalSource, uvSource, lineDimensionSource, colorSource], elements: [elements])
    }
    
    private func addCap(atPosition position: SCNVector3, withIndex index: Int){
        
        let vertIndex = verts.count
        
        //add vert
        verts.append(contentsOf: [position, position, position, position])
        
        //neighboring point captured in normals
        normals.append(contentsOf: [position, position, position, position])
        
        //set UVs
        uvs.append(contentsOf: billboardUVs())
        
        //set Color
        let color = getColor(atPositionIndex: index).asSCNVector()
        colors.append(contentsOf: [color, color, color, color])
        
        //set line radius and geometry overlap settings
        let handleOverlapFlag: CGFloat = handleGeometryOverlap ? 1.0 : 0.0
        let radius = getLineRadius(atPositionIndex: index)
        let lineParam = CGPoint(x: handleOverlapFlag, y: radius)
        lineParams.append(contentsOf: [lineParam, lineParam, lineParam, lineParam])
        
        //add indices
        indices.append(contentsOf: getQuadIndices(fromIndex: vertIndex))

    }
    
    private func addLine(from: SCNVector3, to: SCNVector3, withIndex index: Int){
        
        let vertIndex = verts.count
        
        //add vert
        verts.append(contentsOf: [from, from, to, to])
        
        //neighboring point captured in normals
        normals.append(contentsOf: [to, to, from, from])
        
        //set UVs
        uvs.append(contentsOf: billboardUVs())
        
        //set Color
        let fromColor = getColor(atPositionIndex: index - 1).asSCNVector()
        let toColor = getColor(atPositionIndex: index).asSCNVector()
        colors.append(contentsOf: [fromColor, fromColor, toColor, toColor])
        
        //set line radius and geometry overlap settings
        let handleOverlapFlag : CGFloat = handleGeometryOverlap ? 1.0 : 0.0
        let fromRadius = getLineRadius(atPositionIndex: index - 1)
        let toRadius = getLineRadius(atPositionIndex: index)
        let fromParam = CGPoint(x: handleOverlapFlag, y: fromRadius)
        let toParam = CGPoint(x: handleOverlapFlag, y: toRadius)
        lineParams.append(contentsOf: [fromParam, fromParam, toParam, toParam])
        
        //add indices
        indices.append(contentsOf: getQuadIndices(fromIndex: vertIndex))
    }
    
    //return indices for two joined triangles, creating a quad
    private func getQuadIndices(fromIndex vertIndex: Int) -> [Int32]{
        return [Int32(vertIndex),
                Int32(vertIndex + 1),
                Int32(vertIndex + 2),
                Int32(vertIndex + 3),
                Int32(vertIndex + 2),
                Int32(vertIndex + 1)]
    }
    
    private func billboardUVs() -> [CGPoint]{
        
        let uvSet1 = CGPoint(x: 1, y: 0)
        let uvSet2 = CGPoint(x: 0, y: 0)
        let uvSet3 = CGPoint(x: 1, y: 1)
        let uvSet4 = CGPoint(x: 0, y: 1)
        
        return [uvSet1, uvSet2, uvSet3, uvSet4]
    }
    
    private func getLineRadius(atPositionIndex index: Int ) -> CGFloat{
        
        let totalPositions = positions.count
        let progress = CGFloat.map(value: CGFloat(index),
                                   low1: 0, high1: CGFloat(totalPositions), //map from total postions
            low2: 0, high2: 1) //to a 0-1 range
        
        let radius = CGFloat.lerp(from: startRadius, to: endRadius, withProgress: progress)
        return radius
    }
    
    private func getColor(atPositionIndex index: Int) -> UIColor{
        
        let totalPositions = positions.count
        let progress = CGFloat.map(value: CGFloat(index),
                                   low1: 0, high1: CGFloat(totalPositions), //map from total postions
            low2: 0, high2: 1) //to a 0-1 range
        
        return UIColor.lerp(from: startColor, to: endColor, withProgress: progress)
    }
    
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//MARK: - SCNGEOMETRYSOURCE EXTENSIONS
extension SCNGeometrySource {
    
    convenience init( colors: [SCNVector4]){
        
        let colorData = NSData(bytes: colors, length: MemoryLayout<SCNVector4>.stride * colors.count) as Data
        self.init(data: colorData, semantic: SCNGeometrySource.Semantic.color, vectorCount: colors.count, usesFloatComponents: true, componentsPerVector: 4, bytesPerComponent: MemoryLayout<Float>.stride, dataOffset: 0, dataStride: MemoryLayout<SCNVector4>.stride)
        
    }
}


//MARK: - LERP EXTENSIONS
fileprivate extension UIColor {
    
    func asSCNVector() -> SCNVector4 {
        var r : CGFloat = 0
        var g : CGFloat = 0
        var b : CGFloat = 0
        var a : CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let color = SCNVector4(r, g, b, a)
        return color
    }
    
    //interpolate from -> to in RGB colorspace given some 0.0 - 1.0 progress value.
    class func lerp( from: UIColor, to: UIColor, withProgress progress: CGFloat) -> UIColor{
        var r1 : CGFloat = 0
        var g1 : CGFloat = 0
        var b1 : CGFloat = 0
        var a1 : CGFloat = 0
        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        
        var r2 : CGFloat = 0
        var g2 : CGFloat = 0
        var b2 : CGFloat = 0
        var a2 : CGFloat = 0
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let rOut = CGFloat.lerp(from: r1, to: r2, withProgress: progress)
        let gOut = CGFloat.lerp(from: g1, to: g2, withProgress: progress)
        let bOut = CGFloat.lerp(from: b1, to: b2, withProgress: progress)
        let aOut = CGFloat.lerp(from: a1, to: a2, withProgress: progress)
        
        return UIColor(red: rOut, green: gOut, blue: bOut, alpha: aOut)
        
    }
    
}

fileprivate extension CGFloat {
    
    //interpolate from -> to given some 0.0 - 1.0 progress value.
    static func lerp( from: CGFloat, to: CGFloat, withProgress progress: CGFloat) -> CGFloat{
        return (1.0 - progress) * from + progress * to;
    }
    
    static func map( value: CGFloat, low1: CGFloat, high1: CGFloat, low2: CGFloat, high2: CGFloat) -> CGFloat{
        return low2 + (value - low1) * (high2 - low2) / (high1 - low1)
    }
    
}
