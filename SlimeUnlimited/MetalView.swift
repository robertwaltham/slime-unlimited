//
//  MetalView.swift
//  SlimeUnlimited
//
//  Created by Robert Waltham on 2022-07-23.
//

import Foundation
import MetalKit
import SwiftUI
import simd

struct MetalView: UIViewRepresentable {
    
    @Binding var fps: Double
    @Binding var background: Color
    @Binding var drawParticles: Bool
    @Binding var drawPath: Bool
    
    @Binding var sensorAngle: Float
    @Binding var sensorDistance: Float
    @Binding var turnAngle: Float

    typealias UIViewType = MTKView
    
    init(fps: Binding<Double>, background: Binding<Color>, drawParticles: Binding<Bool> , drawPath: Binding<Bool>,
         sensorAngle: Binding<Float>, sensorDistance: Binding<Float>, turnAngle: Binding<Float>) {
        self._fps = fps
        self._background = background
        self._drawParticles = drawParticles
        self._drawPath = drawPath
        
        self._sensorAngle = sensorAngle
        self._sensorDistance = sensorDistance
        self._turnAngle = turnAngle
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKViewWithTouches()
        mtkView.delegate = context.coordinator
        
        mtkView.enableSetNeedsDisplay = true
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            mtkView.device = metalDevice
        }
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        mtkView.drawableSize = mtkView.frame.size
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 30
        mtkView.isMultipleTouchEnabled = true
        context.coordinator.view = mtkView

        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.colours.background = background.float4()
        context.coordinator.drawParticles = drawParticles
        context.coordinator.drawPath = drawPath
        
        context.coordinator.config = ParticleConfig(sensorAngle: sensorAngle,
                                                    sensorDistance: sensorDistance,
                                                    turnAngle: turnAngle,
                                                    drawRadius: 5,
                                                    trailRadius: 5)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator : NSObject, MTKViewDelegate {
        
        var view: MTKView?
        var metalDevice: MTLDevice!
        var metalCommandQueue: MTLCommandQueue!
        
        var pathTextures: [MTLTexture] = []
        
        var states: [MTLComputePipelineState] = []
        
        var particleBuffer: MTLBuffer!
        
        var particleCount = 128
        
        var maxSpeed: Float = 5
        var margin: Float = 50
        var radius: Float = 50
        
        var drawParticles = false
        var drawPath = false
        
        fileprivate var config = ParticleConfig(sensorAngle: Float.pi / 8,
                                    sensorDistance: 10,
                                    turnAngle: Float.pi / 16,
                                    drawRadius: 5,
                                    trailRadius: 5)
        
        
        // skip all rendering, in the case the hardware doesn't support what we're doing (like in previews)
        var skipDraw = false
        
        var viewPortSize = vector_uint2(x: 0, y: 0)
        

        fileprivate var particles = [Particle]()
//        var obstacles = [Obstacle]()
        
        var colours = RenderColours()

        @Binding var fps: Double
        
        
        private var lastDraw = Date()

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            viewPortSize = vector_uint2(x: UInt32(size.width), y: UInt32(size.height))
        }
        
        func draw(in view: MTKView) {
            
            guard !skipDraw else {
                return
            }
            
            self.view = view
            
            let start = Date()
            fps = 1 / start.timeIntervalSince(lastDraw)
            lastDraw = start
            
            draw()
        }
        
        init(_ parent: MetalView) {
            
            if let metalDevice = MTLCreateSystemDefaultDevice() {
                self.metalDevice = metalDevice
            }
            
 
            
            self._fps = parent._fps
            super.init()
            
            guard self.metalDevice.supportsFamily(.common3) || self.metalDevice.supportsFamily(.apple4) else {
                print("doesn't support read_write textures")
                skipDraw = true
                return
            }
            
            buildPipeline()
            
        }
    }
}

// MARK: - Touches

extension MetalView.Coordinator {
    
    func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {

    }
    
    func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {

    }
    
    func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
    }
    
    func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {

    }
}

// MARK:  - Metal

extension MetalView.Coordinator {
    
    func draw() {
        
        initializeParticlesIfNeeded()
        if pathTextures.count == 0 {
            pathTextures.append(makeTexture(device: metalDevice, drawableSize: viewPortSize))
            pathTextures.append(makeTexture(device: metalDevice, drawableSize: viewPortSize))
        }

        let threadgroupSizeMultiplier = 1
        let maxThreads = 512
        let particleThreadsPerGroup = MTLSize(width: maxThreads, height: 1, depth: 1)
        let particleThreadGroupsPerGrid = MTLSize(width: (max(particleCount / (maxThreads * threadgroupSizeMultiplier), 1)), height: 1, depth:1)
        
        let w = states[0].threadExecutionWidth
        let h = states[0].maxTotalThreadsPerThreadgroup / w
        let textureThreadsPerGroup = MTLSizeMake(w, h, 1)
        let textureThreadgroupsPerGrid = MTLSize(width: (Int(viewPortSize.x) + w - 1) / w, height: (Int(viewPortSize.y) + h - 1) / h, depth: 1)
               
        
        if let commandBuffer = metalCommandQueue.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
            
            commandEncoder.setTexture(pathTextures[0], index: Int(InputTextureIndexPathInput.rawValue))
            commandEncoder.setTexture(pathTextures[1], index: Int(InputTextureIndexPathOutput.rawValue))
            commandEncoder.setBytes(&config, length: MemoryLayout<ParticleConfig>.stride, index: Int(InputIndexConfig.rawValue))

            if let particleBuffer = particleBuffer {
                
                // update particles and draw on path
                commandEncoder.setComputePipelineState(states[1])
                commandEncoder.setBuffer(particleBuffer, offset: 0, index: Int(InputIndexParticles.rawValue))
                commandEncoder.setBytes(&particleCount, length: MemoryLayout<Int>.stride, index: Int(InputIndexParticleCount.rawValue))
                commandEncoder.setBytes(&colours, length: MemoryLayout<RenderColours>.stride, index: Int(InputIndexColours.rawValue))
                commandEncoder.dispatchThreadgroups(particleThreadGroupsPerGrid, threadsPerThreadgroup: particleThreadsPerGroup)
                
                // blur path and copy to second path buffer
                commandEncoder.setComputePipelineState(states[4])
                commandEncoder.dispatchThreadgroups(textureThreadgroupsPerGrid, threadsPerThreadgroup: textureThreadsPerGroup)
            }
            
            if let drawable = view?.currentDrawable {
                
                // Draw Background Colour
                commandEncoder.setComputePipelineState(states[0])
                commandEncoder.setTexture(drawable.texture, index: Int(InputTextureIndexDrawable.rawValue))
                commandEncoder.dispatchThreadgroups(textureThreadgroupsPerGrid, threadsPerThreadgroup: textureThreadsPerGroup)
                                
                if drawPath {
                    commandEncoder.setComputePipelineState(states[3])
                    commandEncoder.dispatchThreadgroups(textureThreadgroupsPerGrid, threadsPerThreadgroup: textureThreadsPerGroup)
                }
                
                if drawParticles, let particleBuffer = particleBuffer {
                    commandEncoder.setComputePipelineState(states[2])
                    commandEncoder.setBuffer(particleBuffer, offset: 0, index: Int(InputIndexParticleCount.rawValue))
                    commandEncoder.dispatchThreadgroups(particleThreadGroupsPerGrid, threadsPerThreadgroup: particleThreadsPerGroup)
                }
                
                commandEncoder.endEncoding()
                commandBuffer.present(drawable)
                
            } else {
                fatalError("no drawable")
            }
            commandBuffer.addCompletedHandler { buffer in
                self.pathTextures.reverse()
//                self.extractParticles()
            }
            commandBuffer.commit()
        }
    }
    
    func buildPipeline() {
        
        // make Command queue
        guard let queue = metalDevice.makeCommandQueue() else {
            fatalError("can't make queue")
        }
        metalCommandQueue = queue

        
        // pipeline state
        do {
            try buildRenderPipelineWithDevice(device: metalDevice)
        } catch {
            fatalError("Unable to compile render pipeline state.  Error info: \(error)")
        }

    }

    
    func buildRenderPipelineWithDevice(device: MTLDevice) throws {
        /// Build a render state pipeline object
        
        guard let library = device.makeDefaultLibrary() else {
            fatalError("can't create libray")
        }
        
        states = try ["firstPass", "secondPass", "thirdPass", "fourthPass", "boxBlur"].map {
            guard let function = library.makeFunction(name: $0) else {
                fatalError("Can't make function \($0)")
            }
            return try device.makeComputePipelineState(function: function)
        }
    }
    
    
    private func initializeParticlesIfNeeded() {
        guard particleBuffer == nil else {
            return
        }
        
        let speedRange = -maxSpeed...maxSpeed
        let xRange = margin...(Float(viewPortSize.x) - margin)
        let yRange = margin...(Float(viewPortSize.y) - margin)

        for _ in 0 ..< particleCount {
            let speed = SIMD2<Float>(Float.random(in: speedRange), Float.random(in: speedRange))
            let position = SIMD2<Float>(Float.random(in: xRange), Float.random(in: yRange))
            let particle = Particle(position: position, velocity: speed)
            particles.append(particle)
        }
        let size = particles.count * MemoryLayout<Particle>.size
        particleBuffer = metalDevice.makeBuffer(bytes: &particles, length: size, options: [])

    }
    
    private func extractParticles() {
        
        guard particleBuffer != nil else {
            return
        }
        
        particles = []
        for i in 0..<particleCount {
            particles.append((particleBuffer.contents() + (i * MemoryLayout<Particle>.size)).load(as: Particle.self))
        }
    }
    
    private func makeTexture(device: MTLDevice, drawableSize: vector_uint2) -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        
        descriptor.storageMode = .private
        descriptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.shaderRead.rawValue)
        descriptor.width = Int(drawableSize.x)
        descriptor.height = Int(drawableSize.y)
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("can't make texture")
        }

        return texture
    }

}

struct RenderColours {
    var background = SIMD4<Float>(0,0,0,0)
    var trail = SIMD4<Float>(0.5,0.5,0.5,1)
    var particle = SIMD4<Float>(0.5,0.5,0.5,1)
}


struct MetalView_Previews: PreviewProvider {
    static var previews: some View {
        MetalView(fps: .constant(60),
                  background: .constant(Color.gray),
                  drawParticles: .constant(false),
                  drawPath: .constant(true),
                  sensorAngle: .constant(0.5),
                  sensorDistance: .constant(0.5),
                  turnAngle: .constant(0.5))
    }
}

private extension Color {
    func float4() -> SIMD4<Float> {
        if let components = cgColor?.components {
            return SIMD4<Float>(Float(components[0]),
                                Float(components[1]),
                                Float(components[2]),
                                Float(components[3]))
        }
        return SIMD4<Float>(0,0,0,0)
    }
}

private struct Particle {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var acceleration: SIMD2<Float> = SIMD2<Float>(0,0)
    var force: SIMD2<Float> = SIMD2<Float>(0,0)

    var description: String {
        return "p<\(position.x),\(position.y)> v<\(velocity.x),\(velocity.y)> a<\(acceleration.x),\(acceleration.y) f<\(force.x),\(force.y)>"
    }
}

private struct ParticleConfig {
    var sensorAngle: Float
    var sensorDistance: Float
    var turnAngle: Float
    var drawRadius: Int
    var trailRadius: Int
}
