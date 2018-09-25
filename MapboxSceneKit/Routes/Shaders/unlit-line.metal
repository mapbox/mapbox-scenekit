//
//  unlit-line.metal
//  MapboxSceneKit
//
//  Created by Jim Martin on 8/2/18.
//  Copyright © 2018 Mapbox. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include <metal_math>
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
    float2 lineParams [[ attribute(SCNVertexSemanticTexcoord1) ]];
} VertexInput;

struct Vertex {
    float4 position [[position]];
    half4 color;
    float2 texCoords;
    float capFlag;
    float zOffset;
};

/*
 Linear color space conversion happens automatically for sRGBA textures,
 but not for vertex colors. This conversion method is copied from section
 7.7.7 of the Metal Language Spec:
( https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf )
 */
static float srgbToLinear(float c) {
    if (c <= 0.04045)
        return c / 12.92;
    else
        return powr((c + 0.055) / 1.055, 2.4);
}

vertex Vertex lineVert(VertexInput in [[ stage_in ]],
                       constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                       constant NodeBuffer& scn_node [[buffer(1)]])
{
    Vertex vert;
    vert.position = scn_node.modelViewProjectionTransform * float4(in.position, 1.0);
    vert.texCoords = in.texCoords;
    vert.color = in.color;
    vert.color.r = srgbToLinear(vert.color.r);
    vert.color.g = srgbToLinear(vert.color.g);
    vert.color.b = srgbToLinear(vert.color.b);
    
    //give useful names to line params
    float lineRadius = in.lineParams.y;
    bool shouldModifyDepthBuffer = in.lineParams.x > 0;
    
    //calculate the offset amounts using the model's largest x/y/z component scale
    float3 modelScale = float3(scn_node.modelTransform[0][0], scn_node.modelTransform[1][1], scn_node.modelTransform[2][2]);
    float expandDistance = lineRadius * max(modelScale.x, max(modelScale.y, modelScale.z));
    
    //apply the offset
    float4 neighborPos = scn_node.modelViewProjectionTransform * float4(in.normals, 1.0);
    float3 pVec = (neighborPos.xyz / neighborPos.w) - (vert.position.xyz / vert.position.w);
    vert.capFlag = step(.001, length(pVec));
    
    float2 perpVec = normalize(pVec).yx;
    perpVec.y *= -1;
    perpVec.xy *= (2 * (in.texCoords.x - .5)) * (2 * (in.texCoords.y - .5));
    
    //less than 2 because the caps look better slightly small
    float2 capVec = 1.98 * (in.texCoords.xy - .5);
    
    // get aspect ratio by applying the projection transform to a 1,1,1 vector.
    float4 projectedPoint = scn_frame.projectionTransform * float4(1,1,1,1);

    //apply the corresponding component of the aspect ratio to adjust for screen size
    vert.position.x += mix(capVec.x, perpVec.x, vert.capFlag) * (expandDistance * projectedPoint.x);
    vert.position.y += mix(capVec.y, perpVec.y, vert.capFlag) * (expandDistance * projectedPoint.y);
    
    //if cap, 1, else 0
    vert.capFlag = 1 - vert.capFlag;
    
    if( shouldModifyDepthBuffer ) {
        //define a depth offset to use as the pipe thickness in the fragment shader when adjusting the output depth value
        float offsetAngleModifier;
        if(vert.capFlag < 1) {
            //increase the maximum depth offset as the incident angle of the pipe increases
            offsetAngleModifier = mix(0.02, abs(pVec.z) , abs(normalize(pVec).z));
        } else {
            //use a static offset for caps
            offsetAngleModifier = 0.02;
        }
        vert.zOffset = (expandDistance * offsetAngleModifier) / vert.position.w;
    } else {
        vert.zOffset = 0;
    }
    
    return vert;
}

struct FragmentOutput {
    // color attachment 0
    half4 color [[color(0)]];
    // depth offset
    float d [[depth(less)]];
};

fragment FragmentOutput lineFrag(Vertex in [[stage_in]]) {
    FragmentOutput output;
    
    //Adds a circular alpha mask to caps, creating a cylinder effect
    float lineAlpha = 1 - step(1, length(in.texCoords * 2 - float2(1.0, 1.0))) * in.capFlag;
    
    if( lineAlpha < 1 ) {
        discard_fragment();
    }
    //premultiply alpha
    output.color = lineAlpha * in.color;
    
    if( in.zOffset > 0 ) {
        //offset the z value of the fragment by the line width to create a cylinder effect when intersecting with other geometry.
        float modifiedOffset;
        if( in.capFlag < 0.5 ) {
            //displace in the virtical axis only for pipes
            modifiedOffset = sin(M_PI_F * in.texCoords.x) * in.zOffset;
        } else {
            //use a round 2D offset for caps
            modifiedOffset = cos(M_PI_F * (saturate(length(in.texCoords - float2(.5, .5))))) * in.zOffset;
        }
        output.d = in.position.z - modifiedOffset;

    } else {
        output.d = in.position.z;
    }
    
    return output;
}
