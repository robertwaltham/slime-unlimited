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

    typealias UIViewType = MTKView
    
    init(fps: Binding<Double>, background: Binding<Color>) {
        self._fps = fps
        self._background = background
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
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator : NSObject, MTKViewDelegate {
        
        var view: MTKView?
        var metalDevice: MTLDevice!
        var metalCommandQueue: MTLCommandQueue!
        
        var firstState: MTLComputePipelineState!
        var secondState: MTLComputePipelineState!
        var thirdState: MTLComputePipelineState!
        
        var particleBuffer: MTLBuffer!
        
        var particleCount = 50
        
        var maxSpeed: Float = 10
        var margin: Float = 50
        var radius: Float = 50
        
        var drawRadius: Int = 4
        
        var viewPortSize: vector_uint2 = vector_uint2(x: 0, y: 0)

        fileprivate var particles = [Particle]()
//        var obstacles = [Obstacle]()
        
        var colours = RenderColours()

        @Binding var fps: Double
        
        
        private var lastDraw = Date()

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            viewPortSize = vector_uint2(x: UInt32(size.width), y: UInt32(size.height))
        }
        
        func draw(in view: MTKView) {
            
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

        let threadgroupSizeMultiplier = 1
        let maxThreads = 512
        let particleThreadsPerGroup = MTLSize(width: maxThreads, height: 1, depth: 1)
        let particleThreadGroupsPerGrid = MTLSize(width: (max(particleCount / (maxThreads * threadgroupSizeMultiplier), 1)), height: 1, depth:1)
        
        let w = firstState.threadExecutionWidth
        let h = firstState.maxTotalThreadsPerThreadgroup / w
        let textureThreadsPerGroup = MTLSizeMake(w, h, 1)
        let textureThreadgroupsPerGrid = MTLSize(width: (Int(viewPortSize.x) + w - 1) / w, height: (Int(viewPortSize.y) + h - 1) / h, depth: 1)
               
        
        if let commandBuffer = metalCommandQueue.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
            
            
            if let particleBuffer = particleBuffer {
                
                commandEncoder.setComputePipelineState(secondState)
                commandEncoder.setBuffer(particleBuffer, offset: 0, index: Int(InputIndexParticles.rawValue))
                commandEncoder.setBytes(&particleCount, length: MemoryLayout<Int>.stride, index: Int(InputIndexParticleCount.rawValue))
//                commandEncoder.setBytes(&maxSpeed, length: MemoryLayout<Float>.stride, index: Int(SecondPassInputIndexMaxSpeed.rawValue))
//                commandEncoder.setBytes(&margin, length: MemoryLayout<Int>.stride, index: Int(SecondPassInputIndexMargin.rawValue))
//                commandEncoder.setBytes(&alignCoefficient, length: MemoryLayout<Float>.stride, index: Int(SecondPassInputIndexAlign.rawValue))
//                commandEncoder.setBytes(&separateCoefficient, length: MemoryLayout<Float>.stride, index: Int(SecondPassInputIndexSeparate.rawValue))
//                commandEncoder.setBytes(&cohereCoefficient, length: MemoryLayout<Float>.stride, index: Int(SecondPassInputIndexCohere.rawValue))
//                commandEncoder.setBytes(&radius, length: MemoryLayout<Float>.stride, index: Int(SecondPassInputIndexRadius.rawValue))
//                commandEncoder.setBytes(&viewPortSize.x, length: MemoryLayout<UInt>.stride, index: Int(SecondPassInputIndexWidth.rawValue))
//                commandEncoder.setBytes(&viewPortSize.y, length: MemoryLayout<UInt>.stride, index: Int(SecondPassInputIndexHeight.rawValue))
//                commandEncoder.setBuffer(obstacleBuffer(), offset: 0, index: Int(SecondPassInputIndexObstacle.rawValue))
//                var count = obstacles.count
//                commandEncoder.setBytes(&count, length: MemoryLayout<Int>.stride, index: Int(SecondPassInputIndexObstacleCount.rawValue))

                commandEncoder.dispatchThreadgroups(particleThreadGroupsPerGrid, threadsPerThreadgroup: particleThreadsPerGroup)
            }
            
            if let drawable = view?.currentDrawable {
                
                // Draw Background Colour
                commandEncoder.setComputePipelineState(firstState)
                commandEncoder.setTexture(drawable.texture, index: Int(InputTextureIndexDrawable.rawValue))
                commandEncoder.setBytes(&colours, length: MemoryLayout<RenderColours>.stride, index: Int(InputIndexColours.rawValue))
                commandEncoder.dispatchThreadgroups(textureThreadgroupsPerGrid, threadsPerThreadgroup: textureThreadsPerGroup)
                
                // third pass - draw particles
                
                if let particleBuffer = particleBuffer {
                    commandEncoder.setComputePipelineState(thirdState)
                    commandEncoder.setTexture(drawable.texture, index: 0)
                    commandEncoder.setBuffer(particleBuffer, offset: 0, index: Int(InputIndexParticleCount.rawValue))
                    commandEncoder.setBytes(&drawRadius, length: MemoryLayout<Int>.stride, index: Int(InputIndexDrawSpan.rawValue))
                    commandEncoder.dispatchThreadgroups(particleThreadGroupsPerGrid, threadsPerThreadgroup: particleThreadsPerGroup)
                }
                
                commandEncoder.endEncoding()
                commandBuffer.present(drawable)
                
            } else {
                fatalError("no drawable")
            }
            commandBuffer.commit()
            extractParticles()
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
        
        guard let firstPass = library.makeFunction(name: "firstPass") else {
            fatalError("can't create first pass")
        }
        firstState = try device.makeComputePipelineState(function: firstPass)
        
        guard let secondPass = library.makeFunction(name: "secondPass") else {
            fatalError("can't create first pass")
        }
        secondState = try device.makeComputePipelineState(function: secondPass)

        guard let thirdPass = library.makeFunction(name: "thirdPass") else {
            fatalError("can't create first pass")
        }
        thirdState = try device.makeComputePipelineState(function: thirdPass)

    }
    
    
    func initializeParticlesIfNeeded() {
        
        guard particleBuffer == nil else {
            return
        }
        
        for _ in 0 ..< particleCount {
            let speed = SIMD2<Float>(Float.random(min: -maxSpeed, max: maxSpeed), Float.random(min: -maxSpeed, max: maxSpeed))
            let position = SIMD2<Float>(randomPosition(length: UInt(viewPortSize.x)), randomPosition(length: UInt(viewPortSize.y)))
            let particle = Particle(position: position, velocity: speed)
            particles.append(particle)
        }
        let size = particles.count * MemoryLayout<Particle>.size
        particleBuffer = metalDevice.makeBuffer(bytes: &particles, length: size, options: [])

    }
    
    private func randomPosition(length: UInt) -> Float {
        
        let maxSize = length - (UInt(margin) * 2)
        
        return Float(arc4random_uniform(UInt32(maxSize)) + UInt32(margin))
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

}

struct RenderColours {
    var background = SIMD4<Float>(0,0,0,0)
    var foreground = SIMD4<Float>(0,0,0,0)
}


struct MetalView_Previews: PreviewProvider {
    static var previews: some View {
        MetalView(fps: .constant(60), background: .constant(Color.gray))
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

private extension Float {

    static var random: Float {
        return Float(arc4random() / 0xFFFFFFFF) // TODO: Fix floating point representation warning, implement this properly
    }

    static func random(min: Float, max: Float) -> Float {
        return Float.random * (max - min) + min
    }
}


