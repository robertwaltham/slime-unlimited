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

struct Particle {
    float2 position;
    float2 velocity;
    float2 acceleration;
    float2 force;
};

kernel void firstPass(texture2d<half, access::write> output [[texture(InputTextureIndexDrawable)]],
                      const device RenderColours& colours [[buffer(InputIndexColours)]],
                      uint2 id [[thread_position_in_grid]]) {
    output.write((half4)colours.background, id);
}

kernel void secondPass(const device RenderColours& colours [[buffer(InputIndexColours)]],
                       device Particle *particles [[buffer(InputIndexParticles)]],
                       const device int& particle_count [[ buffer(InputIndexParticleCount)]],
                       uint id [[ thread_position_in_grid ]],
                       uint tid [[ thread_index_in_threadgroup ]],
                       uint bid [[ threadgroup_position_in_grid ]],
                       uint blockDim [[ threads_per_threadgroup ]]) {
    
    uint index = bid * blockDim + tid;
    Particle particle = particles[index];
    
    float2 position = particle.position;
    float2 velocity = particle.velocity;
    float2 acceleration = float2(0,0);
    
    // position
    position += velocity;

    // update particle
    particle.velocity = velocity;
    particle.acceleration = acceleration;
    particle.position = position;

    // output
    particles[index] = particle;
}


kernel void thirdPass(texture2d<half, access::write> output [[texture(0)]],
                      device Particle *particles [[buffer(InputIndexParticles)]],
                      const device int& span [[ buffer(InputIndexDrawSpan)]],
                      uint id [[ thread_position_in_grid ]],
                      uint tid [[ thread_index_in_threadgroup ]],
                      uint bid [[ threadgroup_position_in_grid ]],
                      uint blockDim [[ threads_per_threadgroup ]]) {
    
    uint index = bid * blockDim + tid;
    
    uint width = output.get_width();
    uint height = output.get_height();

    Particle particle = particles[index];
    uint2 pos = uint2(particle.position);
    
    // display
    half4 color = half4(0.);
    
    if (span == 0) {
        output.write(color, pos);
    } else {
        for (uint u = pos.x - span; u <= uint(pos.x) + span; u++) {
            for (uint v = pos.y - span; v <= uint(pos.y) + span; v++) {
                if (u < 0 || v < 0 || u >= width || v >= height) {
                    continue;
                }
                
                if (length(float2(u, v) - particle.position) < span) {
                    output.write(color, uint2(u, v));
                }
            }
        }
    }
    
}
