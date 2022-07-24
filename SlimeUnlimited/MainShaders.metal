//
//  MainShaders.metal
//  SlimeUnlimited
//
//  Created by Robert Waltham on 2022-07-23.
//

#include <metal_stdlib>
#import "ShaderTypes.h"

using namespace metal;

struct RenderColours {
    float4 background;
    float4 foreground;
};

kernel void firstPass(texture2d<half, access::write> output [[texture(InputTextureIndexDrawable)]],
                      const device RenderColours& colours [[buffer(InputIndexColours)]],
                      uint2 id [[thread_position_in_grid]]) {
    output.write((half4)colours.background, id);
}
