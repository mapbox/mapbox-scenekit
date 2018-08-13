//
//  LineNode.swift
//  line-rendering
//
//  Created by Jim Martin on 8/2/18.
//  Copyright © 2018 Jim Martin. All rights reserved.
//

import Foundation
import SceneKit

class LineNode: SCNNode {
    
    var positions : [SCNVector3] = [SCNVector3Zero]
    var startRadius : CGFloat = 0.1
    var endRadius : CGFloat = 0.5
    var startColor : UIColor = UIColor.yellow
    var endColor : UIColor = UIColor.white
    var pointScaleFactor : CGFloat = 1.0
    
    //derived from position/radius
    private var verts : [SCNVector3]! //components -> quads
    private var normals : [SCNVector3]! //we use the normal magnitude to pass the line radius to the geometry shader
    private var indices: [Int32]!
    private var uvs : [CGPoint]! //uv per vert, indicating the corner of the quad
    private var colors : [SCNVector4]! //vertex colors
    private var lineDimensions : [CGPoint]! //line radius captured in y value
    private var neighbors : [SCNVector3]! //neighboring component stored as texCoords, for screen-space comparisons in the shader
    
    override init() {
        super.init()
    }
    
    convenience init( positions: [SCNVector3],
                      startRadius: CGFloat, endRadius: CGFloat,
                      startColor: UIColor, endColor: UIColor) {
        self.init()
        self.positions = positions
        self.startRadius = startRadius
        self.endRadius = endRadius
        self.startColor = startColor
        self.endColor = endColor
        createLine()
    }
    
    func createLine(){

        self.geometry = generateGeometry()
        
        //assign materials
        let lineMaterial = SCNMaterial()
        let program = SCNProgram()
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
        lineDimensions = []
        normals = []
        indices = []

        neighbors = []
        
        //step forward through positions and add lines first
        for (index, position) in positions.enumerated() where index != 0{
            let lastPosition = positions[index - 1]
            
            //add a line to the new position
            addLine(from: lastPosition, to: position, withIndex: index)
        }
        
        //step backwards and add caps
        //we want the vertex transforms calculate for the lines first, so the cap alphas appear correctly.
        for (index, position) in positions.enumerated().reversed(){
            //add a cap at the new position
            addCap(atPosition: position, withIndex: index )
        }
        
        //create geometry from sources
        let vertSource = SCNGeometrySource(vertices: verts)
        let normalSource = SCNGeometrySource(normals: normals)
        let uvSource = SCNGeometrySource(textureCoordinates: uvs)
        let colorSource = SCNGeometrySource(colors: colors)
        let lineDimensionSource = SCNGeometrySource(textureCoordinates: lineDimensions)
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
        //TODO: set vertex colors from some gradient
        let color = getColor(atPositionIndex: index).asSCNVector()
        colors.append(contentsOf: [color, color, color, color])
        
        //set line dimensions
        let radius = getLineRadius(atPositionIndex: index)
        lineDimensions.append(contentsOf: [radius, radius, radius, radius])
        
        //add incices
        indices.append(contentsOf: [Int32(vertIndex),
                                    Int32(vertIndex + 1),
                                    Int32(vertIndex + 2),
                                    Int32(vertIndex + 3),
                                    Int32(vertIndex + 2),
                                    Int32(vertIndex + 1)])
        
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
        //TODO: set vertex colors
        let fromColor = getColor(atPositionIndex: index - 1).asSCNVector()
        let toColor = getColor(atPositionIndex: index).asSCNVector()
        colors.append(contentsOf: [fromColor, fromColor, toColor, toColor])
        
        //set line dimensions
        let fromRadius = getLineRadius(atPositionIndex: index - 1)
        let toRadius = getLineRadius(atPositionIndex: index)
        lineDimensions.append(contentsOf: [fromRadius, fromRadius, toRadius, toRadius])
        
        //add incices
        indices.append(contentsOf: [Int32(vertIndex),
                                    Int32(vertIndex + 1),
                                    Int32(vertIndex + 2),
                                    Int32(vertIndex + 3),
                                    Int32(vertIndex + 2),
                                    Int32(vertIndex + 1)])
    }
    
    private func billboardUVs() -> [CGPoint]{
        
        let uvSet1 = CGPoint(x: 1, y: 0)
        let uvSet2 = CGPoint(x: 0, y: 0)
        let uvSet3 = CGPoint(x: 1, y: 1)
        let uvSet4 = CGPoint(x: 0, y: 1)
        
        return [uvSet1, uvSet2, uvSet3, uvSet4]
    }
    
    //TODO: get lineradius from curve
    private func getLineRadius(atPositionIndex index: Int ) -> CGPoint{
        
        let totalPositions = positions.count
        let progress = CGFloat.map(value: CGFloat(index),
                                   low1: 0, high1: CGFloat(totalPositions), //map from total postions
                                    low2: 0, high2: 1) //to a 0-1 range
        
        let radius = CGFloat.lerp(from: startRadius, to: endRadius, withProgress: progress)
        return CGPoint(x: 0.0, y: radius)
    }
    
    //TODO: get colors from curve, currently just linear interpolation between start and end colors
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
    //TODO: HSV would probably look better
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
        
        return UIColor(displayP3Red: rOut, green: gOut, blue: bOut, alpha: aOut)
        
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
