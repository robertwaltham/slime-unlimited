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
    float4 trail;
    float4 particle;
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

kernel void secondPass(texture2d<half, access::read_write> output [[texture(InputTextureIndexPathInput)]],
                       const device RenderColours& colours [[buffer(InputIndexColours)]],
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
    
    uint width = output.get_width();
    uint height = output.get_height();
    
    // position
    position += velocity;
    
    if (position.x < 0 || position.x > width) {
        velocity.x *= -1;
    }
    
    if (position.y < 0 || position.y > height) {
        velocity.y *= -1;
    }

    // update particle
    particle.velocity = velocity;
    particle.acceleration = acceleration;
    particle.position = position;

    // output
    particles[index] = particle;
    
    // leave trail
    
    uint2 pos = uint2(particle.position);
    
    // display
    half4 color = (half4)colours.trail;
    uint span = 7;
    
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


kernel void thirdPass(texture2d<half, access::write> output [[texture(InputTextureIndexDrawable)]],
                      device Particle *particles [[buffer(InputIndexParticles)]],
                      const device int& span [[ buffer(InputIndexDrawSpan)]],
                      const device RenderColours& colours [[buffer(InputIndexColours)]],
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
    half4 color = (half4)colours.particle;
    
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

kernel void fourthPass(texture2d<half, access::write> output [[texture(InputTextureIndexDrawable)]],
                       texture2d<half, access::read_write> input [[texture(InputTextureIndexPathOutput)]],
                       uint2 gid [[ thread_position_in_grid ]]) {
    half4 color = input.read(gid);
    output.write(color, gid);
}

kernel void boxBlur(texture2d<half, access::write> output [[texture(InputTextureIndexPathOutput)]],
                       texture2d<half, access::read_write> input [[texture(InputTextureIndexPathInput)]],
                       uint2 gid [[ thread_position_in_grid ]]) {
    
    const int blurSize = 5;
    int range = floor(blurSize/2.0);

    half4 colors = half4(0);
    for (int x = -range; x <= range; x++) {
        for (int y = -range; y <= range; y++) {
            half4 color = input.read(uint2(gid.x+x, gid.y+y));
            colors += color;
        }
    }

    half4 finalColor = colors/float(blurSize*blurSize);
    
    float cutoff = 0.01;
    if (finalColor[0] < cutoff) {
        finalColor[0] = 0;
    }
    if (finalColor[1] < cutoff) {
        finalColor[1] = 0;
    }
    if (finalColor[2] < cutoff) {
        finalColor[2] = 0;
    }
    
    float decay = 0.999;
    finalColor[0] *= decay;
    finalColor[1] *= decay;
    finalColor[2] *= decay;

    output.write(finalColor, gid);
    
//    half4 color = input.read(gid);
//    output.write(color, gid);
}

