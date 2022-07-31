//
//  ContentView.swift
//  SlimeUnlimited
//
//  Created by Robert Waltham on 2022-07-23.
//

import SwiftUI


struct ContentView: View {
    
    @State var fps: Double = 0
    @State var drawParticles: Bool = true
    @State var drawPath: Bool = true

    @State private var bgColor = Color(.sRGB, red: 0, green: 0, blue: 0,opacity: 0)
    
    var body: some View {
        VStack {
            Text("FPS: \(fps, specifier: "%.0f")")
//            ColorPicker("Choose a background color", selection: $bgColor)
//                .padding(.horizontal)
            HStack {
                Toggle("Draw Particles", isOn: $drawParticles).padding(.horizontal)
                Toggle("Draw Path", isOn: $drawPath).padding(.horizontal)
            }
            MetalView(fps: $fps, background: $bgColor, drawParticles: $drawParticles, drawPath: $drawPath)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
