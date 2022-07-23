//
//  MTKViewWithTouches.swift
//  SlimeUnlimited
//
//  Created by Robert Waltham on 2022-07-23.
//

import Foundation
import MetalKit

class MTKViewWithTouches: MTKView {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let renderer = self.delegate as? MetalView.Coordinator {
            renderer.touchesBegan(touches, with: event)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let renderer = self.delegate as? MetalView.Coordinator {
            renderer.touchesMoved(touches, with: event)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let renderer = self.delegate as? MetalView.Coordinator {
            renderer.touchesEnded(touches, with: event)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let renderer = self.delegate as? MetalView.Coordinator {
            renderer.touchesCancelled(touches, with: event)
        }
    }
}
