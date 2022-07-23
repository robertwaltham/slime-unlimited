//
//  MetalView.swift
//  SlimeUnlimited
//
//  Created by Robert Waltham on 2022-07-23.
//

import Foundation
import MetalKit
import SwiftUI

struct MetalView: UIViewRepresentable {
    
    typealias UIViewType = MTKView

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKViewWithTouches()
        mtkView.delegate = context.coordinator
        
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            mtkView.device = metalDevice
        }
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
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
        
        var view: MTKView!
        var metalDevice: MTLDevice!
        var metalCommandQueue: MTLCommandQueue!
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            
        }
        
        func draw(in view: MTKView) {
            
            if let commandBuffer = metalCommandQueue.makeCommandBuffer(),
               let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
                
                if let drawable = view.currentDrawable {
                    
                    commandEncoder.endEncoding()
                    commandBuffer.present(drawable)
                }
                
            }
        }
        
        init(_ parent: MetalView) {
            
            if let metalDevice = MTLCreateSystemDefaultDevice() {
                self.metalDevice = metalDevice
            }
            
            self.metalCommandQueue = metalDevice.makeCommandQueue()!
            super.init()
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

struct MetalView_Previews: PreviewProvider {
    static var previews: some View {
        MetalView()
    }
}
