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

    typealias UIViewType = MTKView
    
    init(fps: Binding<Double>) {
        self._fps = fps
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
        
        var particleCount = 0
        var viewPortSize: vector_uint2 = vector_uint2(x: 0, y: 0)
        

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
        
        var colours = RenderColours(background: SIMD4<Float>(0.5,0.5,0.5,1), foreground: SIMD4<Float>(0,0,0,0))
        
        
//        let threadgroupSizeMultiplier = 1
//        let maxThreads = 512
//        let particleThreadsPerGroup = MTLSize(width: maxThreads, height: 1, depth: 1)
//        let particleThreadGroupsPerGrid = MTLSize(width: (max(particleCount / (maxThreads * threadgroupSizeMultiplier), 1)), height: 1, depth:1)
        
        let w = firstState.threadExecutionWidth
        let h = firstState.maxTotalThreadsPerThreadgroup / w
        let textureThreadsPerGroup = MTLSizeMake(w, h, 1)
        let textureThreadgroupsPerGrid = MTLSize(width: (Int(viewPortSize.x) + w - 1) / w, height: (Int(viewPortSize.y) + h - 1) / h, depth: 1)
               
        
        if let commandBuffer = metalCommandQueue.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
            
            if let drawable = view?.currentDrawable {
                
                commandEncoder.setComputePipelineState(firstState)
                commandEncoder.setTexture(drawable.texture, index: Int(InputTextureIndexDrawable.rawValue))
                commandEncoder.setBytes(&colours, length: MemoryLayout<RenderColours>.stride, index: Int(InputIndexColours.rawValue))

                commandEncoder.dispatchThreadgroups(textureThreadgroupsPerGrid, threadsPerThreadgroup: textureThreadsPerGroup)
                
                
                commandEncoder.endEncoding()
                commandBuffer.present(drawable)
                
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
        
        guard let firstPass = library.makeFunction(name: "firstPass") else {
            fatalError("can't create first pass")
        }
        firstState = try device.makeComputePipelineState(function: firstPass)
        
//        guard let secondPass = library.makeFunction(name: "secondPass") else {
//            fatalError("can't create first pass")
//        }
//        secondState = try device.makeComputePipelineState(function: secondPass)
//
//        guard let thirdPass = library.makeFunction(name: "thirdPass") else {
//            fatalError("can't create first pass")
//        }
//        thirdState = try device.makeComputePipelineState(function: thirdPass)

    }
}

struct RenderColours {
    var background: SIMD4<Float>
    var foreground: SIMD4<Float>
}


struct MetalView_Previews: PreviewProvider {
    static var previews: some View {
        MetalView(fps: .constant(60))
    }
}
