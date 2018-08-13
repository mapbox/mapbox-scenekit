//
//  unlit-line.metal
//  line-rendering
//
//  Created by Jim Martin on 8/2/18.
//  Copyright © 2018 Jim Martin. All rights reserved.
//

#include <metal_stdlib>

using namespace metal;

#include <SceneKit/scn_metal>

struct NodeBuffer {
    float4x4 modelTransform;
    float4x4 modelViewTransform;
    float4x4 normalTransform;
    float4x4 modelViewProjectionTransform;
};

typedef struct {
    float3 position [[ attribute(SCNVertexSemanticPosition) ]];
    float3 normals [[ attribute(SCNVertexSemanticNormal) ]];
    half4 color [[ attribute(SCNVertexSemanticColor)]];
    float2 texCoords [[ attribute(SCNVertexSemanticTexcoord0) ]];
    float2 lineDimensions [[ attribute(SCNVertexSemanticTexcoord1) ]];
} VertexInput;

struct Vertex
{
    float4 position [[position]];
    half4 color;
    float2 texCoords;
    float capFlag;
};

vertex Vertex lineVert(VertexInput in [[ stage_in ]],
                             constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                             constant NodeBuffer& scn_node [[buffer(1)]])
{
    Vertex vert;
    vert.position = scn_node.modelViewProjectionTransform * float4(in.position, 1.0);
    vert.texCoords = in.texCoords;
    vert.color = in.color;
    
    float _lineRadius = in.lineDimensions.y;
    
    //calculate the offset amounts
    float expandDistance = _lineRadius;
    
    //apply the offset
    float4 neighborPos = scn_node.modelViewProjectionTransform * float4(in.normals, 1.0);
    float2 perpVec = (neighborPos.xy / neighborPos.w) - (vert.position.xy / vert.position.w);
    vert.capFlag = step(.01, length(perpVec));
    perpVec = normalize(perpVec).yx;
    perpVec.y *= -1;
    perpVec.xy *=  (2 * (in.texCoords.x - .5)) * (2 * (in.texCoords.y - .5));
    
    //1.95 because the caps look better slightly small
    //TODO: parameterize this value - maybe in the second 'linedimensions' coord
    float2 capVec = 1.95 * (in.texCoords.xy - .5);
    
    //FIXME: compensate for the aspect ratio stretching, maybe apply the projection transform after moving verts?
    float4 projectedPoint = scn_frame.projectionTransform * float4(1,1,1,1);
    vert.position.x += mix(capVec.x, perpVec.x, vert.capFlag) * (expandDistance * projectedPoint.x);
    vert.position.y += mix(capVec.y, perpVec.y, vert.capFlag) * (expandDistance * projectedPoint.y); // * aspectratio
    
    //if cap, 1, else 0
    vert.capFlag = 1 - vert.capFlag;
    
    return vert;
}


fragment half4 lineFrag(Vertex in [[stage_in]],
                        texture2d<float, access::sample> diffuseTexture [[texture(0)]])
{
    float lineAlpha = 1 - step(1, length(in.texCoords * 2 - float2(1.0, 1.0))) * in.capFlag;
    
    if( lineAlpha < 1 ){
        discard_fragment();
    }
    
    //premultiply alpha
    return lineAlpha * half4(in.color);
}
