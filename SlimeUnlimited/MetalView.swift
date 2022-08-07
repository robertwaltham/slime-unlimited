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
    
    @ObservedObject var viewModel: ViewModel

    typealias UIViewType = MTKView
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
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
        mtkView.preferredFramesPerSecond = 60
        mtkView.isMultipleTouchEnabled = true
        context.coordinator.view = mtkView

        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.colours.background = viewModel.bgColor.float4()
        context.coordinator.drawParticles = viewModel.drawParticles
        context.coordinator.drawPath = viewModel.drawPath
        context.coordinator.particleCount = viewModel.count
        context.coordinator.config = viewModel.particleConfig()
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
        
        var particleCount = 0
        
        var maxSpeed: Float = 1
        var minSpeed: Float = 0.75
        
        var margin: Float = 50
        var radius: Float = 50
        
        var drawParticles = false
        var drawPath = false
        
        fileprivate var config = ParticleConfig()
        
        // skip all rendering, in the case the hardware doesn't support what we're doing (like in previews)
        var skipDraw = false
        
        var viewPortSize = vector_uint2(x: 0, y: 0)
        

        fileprivate var particles = [Particle]()
//        var obstacles = [Obstacle]()
        
        var colours = RenderColours()
        var viewModel: ViewModel
        
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
            viewModel.fps = 1 / start.timeIntervalSince(lastDraw)
            lastDraw = start
            
            draw()
        }
        
        init(_ parent: MetalView) {
            
            if let metalDevice = MTLCreateSystemDefaultDevice() {
                self.metalDevice = metalDevice
            }
            
            self.viewModel = parent.viewModel

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

// MARK: - Metal

extension MetalView.Coordinator {
    
    func wave(time: Double, phase: Double, phaseOffset: Double, magitude: Double, magnitudeOffset: Double) -> Float {
        return Float((sin(time * phase + phaseOffset) + magnitudeOffset) * magitude)
    }
    
    func draw() {
                
//        let time = Date().timeIntervalSince1970
//        viewModel.turnAngle = wave(time: time, phase: 4, phaseOffset: 0, magitude: 0.35, magnitudeOffset: 1.2)
//        viewModel.speedMultiplier = wave(time: time, phase: 3, phaseOffset: 0, magitude: 1.75, magnitudeOffset: 1.5)
//        viewModel.sensorDistance = wave(time: time, phase: 1, phaseOffset: 0, magitude: 5, magnitudeOffset: 2)
//        config = viewModel.particleConfig()
        
        initializeParticlesIfNeeded()
        
        if pathTextures.count == 0 {
            pathTextures.append(makeTexture(device: metalDevice, drawableSize: viewPortSize))
            pathTextures.append(makeTexture(device: metalDevice, drawableSize: viewPortSize))
        }
        let randomCount = 1024
        var random: [Float] = (0..<randomCount).map { _ in Float.random(in: 0...1) }

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
            commandEncoder.setBytes(&random, length: MemoryLayout<Float>.stride * randomCount, index: Int(InputIndexRandom.rawValue))

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
        
        let speedRange = minSpeed...maxSpeed
        let xRange = margin...(Float(viewPortSize.x) - margin)
        let yRange = margin...(Float(viewPortSize.y) - margin)

        for _ in 0 ..< particleCount {
            var speed = SIMD2<Float>(Float.random(in: speedRange), 0)
            let angle = Float.random(in: 0...Float.pi * 2)
            
            let rotation = simd_float2x2(SIMD2<Float>(cos(angle), -sin(angle)), SIMD2<Float>(sin(angle), cos(angle)))
            speed = rotation * speed
            
            let species = Float(Int.random(in: 0..<3))
            let position = SIMD2<Float>(Float.random(in: xRange), Float.random(in: yRange))
            let particle = Particle(position: position, velocity: speed, species: species)
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
    var trail = SIMD4<Float>(0.25,0.25,0.25,1)
    var particle = SIMD4<Float>(0.5,0.5,0.5,1)
}


struct MetalView_Previews: PreviewProvider {
    static var previews: some View {
        MetalView(viewModel: ViewModel())
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
    var species: Float
    var bytes: Float = 0
    
    var description: String {
        return "p<\(position.x),\(position.y)> v<\(velocity.x),\(velocity.y)> a<\(acceleration.x),\(acceleration.y)"
    }
}

struct ParticleConfig {
    var sensorAngle: Float = 0
    var sensorDistance: Float = 0
    var turnAngle: Float = 0
    var drawRadius: Float = 0
    var trailRadius: Float = 0
    var cutoff: Float = 0
    var falloff: Float = 0
    var speedMultiplier: Float = 0
}
