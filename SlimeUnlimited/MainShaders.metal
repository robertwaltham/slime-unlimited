//
//  MainShaders.metal
//  SlimeUnlimited
//
//  Created by Robert Waltham on 2022-07-23.
//

#include <metal_stdlib>
using namespace metal;


kernel void firstPass(texture2d<half, access::write> output [[texture(0)]],
                      uint2 id [[thread_position_in_grid]]) {
    output.write(half4(0.5, 1., 1., 1.), id);
}
