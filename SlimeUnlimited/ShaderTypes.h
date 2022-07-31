//
//  ShaderTypes.h
//  SlimeUnlimited
//
//  Created by Robert Waltham on 2022-07-23.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>


typedef enum InputIndex {
    InputIndexColours = 0,
    InputIndexParticles = 1,
    InputIndexParticleCount = 2,
    InputIndexConfig = 3
} InputIndex;

typedef enum InputTextureIndex {
    InputTextureIndexDrawable = 0,
    InputTextureIndexPathInput = 1,
    InputTextureIndexPathOutput = 2

} InputTextureIndex;


#endif /* ShaderTypes_h */
