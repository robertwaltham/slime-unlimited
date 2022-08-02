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
    float species;
    float bytes;
};

struct ParticleConfig {
    float sensor_angle;
    float sensor_distance;
    float turn_angle;
    float draw_radius;
    float trail_radius;
    float cutoff;
    float falloff;
    float speed_multiplier;
};

float2 rotate_vector(float2 vector, float angle) {
    float2x2 rotation = float2x2(cos(angle), -sin(angle), sin(angle), cos(angle));
    return rotation * vector;
}

kernel void firstPass(texture2d<half, access::write> output [[texture(InputTextureIndexDrawable)]],
                      const device RenderColours& colours [[buffer(InputIndexColours)]],
                      uint2 id [[thread_position_in_grid]]) {
    output.write((half4)colours.background, id);
}

kernel void secondPass(texture2d<half, access::read_write> output [[texture(InputTextureIndexPathInput)]],
                       const device RenderColours& colours [[buffer(InputIndexColours)]],
                       device Particle *particles [[buffer(InputIndexParticles)]],
                       const device float *random [[buffer(InputIndexRandom)]],
                       const device int& particle_count [[ buffer(InputIndexParticleCount)]],
                       const device ParticleConfig& config [[ buffer(InputIndexConfig)]],
                       uint id [[ thread_position_in_grid ]],
                       uint tid [[ thread_index_in_threadgroup ]],
                       uint bid [[ threadgroup_position_in_grid ]],
                       uint blockDim [[ threads_per_threadgroup ]]) {
    
    uint index = bid * blockDim + tid;
    Particle particle = particles[index];
    
    float2 position = particle.position;
    float2 velocity = particle.velocity;
    float2 acceleration = particle.acceleration;
    int species = (int)clamp(particle.species, 0.0, 3.0);
    
    uint width = output.get_width();
    uint height = output.get_height();
    
    // position
    position += (velocity * config.speed_multiplier);
    
    // bounds
    if (position.x < 0 || position.x > width) {
        velocity.x *= -1;
    }
    
    if (position.y < 0 || position.y > height) {
        velocity.y *= -1;
    }
    
    // velocity
    
    float sensor_angle = config.sensor_angle;
    float turn_angle = config.turn_angle;
    float sensor_distance = config.sensor_distance;
    
    float2 center_direction = normalize(-velocity) * sensor_distance;
    float2 left_direction = rotate_vector(center_direction, sensor_angle);
    float2 right_direction = rotate_vector(center_direction, -sensor_angle);
    
    ushort2 center_coord = (ushort2)floor(position - center_direction);
    ushort2 left_coord = (ushort2)floor(position - left_direction);
    ushort2 right_coord = (ushort2)floor(position - right_direction);

    half4 center_colour = output.read(center_coord);
    half4 left_colour = output.read(left_coord);
    half4 right_colour = output.read(right_coord);
    
    int channel = species;
    float tolerance = 0.1;
    if (left_colour[channel] - center_colour[channel] > tolerance && left_colour[channel] - right_colour[channel] > tolerance) {
        velocity = rotate_vector(velocity, turn_angle);
    } else if (right_colour[channel] - center_colour[channel] > tolerance && right_colour[channel] - left_colour[channel] > tolerance) {
        velocity = rotate_vector(velocity, -turn_angle);
    } else if (abs(right_colour[channel] - left_colour[channel]) < tolerance) {
        if (random[index % 1024] < 0.5) {
            velocity = rotate_vector(velocity, -turn_angle);
        } else {
            velocity = rotate_vector(velocity, turn_angle);
        }
    }

    // update particle
    particle.velocity = velocity;
    particle.acceleration = acceleration;
    particle.position = position;

    // output
    particles[index] = particle;
    
    // leave trail
    
    uint2 pos = uint2(particle.position);
    half4 trail_colour = half4(0,0,0,1);
    trail_colour[species] = 0.25;
    
    half4 deletion_colour = half4(0.1, 0.1, 0.1, 1);
    deletion_colour[species] = 0;
    uint span = (uint)config.trail_radius;
    
    for (uint u = pos.x - span; u <= uint(pos.x) + span; u++) {
        for (uint v = pos.y - span; v <= uint(pos.y) + span; v++) {
            if (u < 0 || v < 0 || u >= width || v >= height) {
                continue;
            }
            
            if (length(float2(u, v) - particle.position) < span) {
                half4 current_color = output.read(uint2(u,v));
                half4 output_color = current_color += trail_colour;
                output_color = current_color -= deletion_colour;
                output.write(clamp(output_color, half4(0), half4(1)), uint2(u, v));
            }
        }
    }
}


kernel void thirdPass(texture2d<half, access::write> output [[texture(InputTextureIndexDrawable)]],
                      device Particle *particles [[buffer(InputIndexParticles)]],
                      const device ParticleConfig& config [[ buffer(InputIndexConfig)]],
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
    uint span = (uint)config.draw_radius;
    
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
    
    float2 position = particle.position;
    float2 velocity = particle.velocity;
    half4 sensor_color = half4(1, 0, 0, 1);
    float sensor_angle = config.sensor_angle;
    float sensor_distance = config.sensor_distance;
    
    float2 center_direction = normalize(-velocity) * sensor_distance;
    float2 left_direction = rotate_vector(center_direction, sensor_angle);
    float2 right_direction = rotate_vector(center_direction, -sensor_angle);
    
    ushort2 center_coord = (ushort2)floor(position - center_direction);
    ushort2 left_coord = (ushort2)floor(position - left_direction);
    ushort2 right_coord = (ushort2)floor(position - right_direction);
    
    output.write(sensor_color, center_coord);
    output.write(sensor_color, left_coord);
    output.write(sensor_color, right_coord);

}

kernel void fourthPass(texture2d<half, access::write> output [[texture(InputTextureIndexDrawable)]],
                       texture2d<half, access::read_write> input [[texture(InputTextureIndexPathOutput)]],
                       uint2 gid [[ thread_position_in_grid ]]) {
    half4 color = input.read(gid);
    output.write(color, gid);
}

kernel void boxBlur(texture2d<half, access::write> output [[texture(InputTextureIndexPathOutput)]],
                       texture2d<half, access::read_write> input [[texture(InputTextureIndexPathInput)]],
                       const device ParticleConfig& config [[ buffer(InputIndexConfig)]],
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
    
    float cutoff = config.cutoff;
    if (finalColor[0] < cutoff) {
        finalColor[0] = 0;
    }
    if (finalColor[1] < cutoff) {
        finalColor[1] = 0;
    }
    if (finalColor[2] < cutoff) {
        finalColor[2] = 0;
    }
    
    float decay = 1 - config.falloff;
    finalColor[0] *= decay;
    finalColor[1] *= decay;
    finalColor[2] *= decay;

    output.write(finalColor, gid);
}

