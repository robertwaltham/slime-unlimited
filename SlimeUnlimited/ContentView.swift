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
    
    @State var sensorAngle: Float = Float.pi / 8
    @State var sensorDistance: Float = 10
    @State var turnAngle: Float = Float.pi / 16

    @State private var bgColor = Color(.sRGB, red: 0, green: 0, blue: 0,opacity: 0)
    
    var body: some View {
        VStack {
//            Text("FPS: \(fps, specifier: "%.0f")")
//            ColorPicker("Choose a background color", selection: $bgColor)
//                .padding(.horizontal)
            HStack {
                Toggle("Draw Particles", isOn: $drawParticles).padding(.horizontal)
                Toggle("Draw Path", isOn: $drawPath).padding(.horizontal)
            }
            
            HStack(alignment: .center, spacing: 15) {
                VStack {
                    Text("Sensor Angle: \(sensorAngle, specifier: "%.2f")")
                        .font(.title)
                    Slider(value: $sensorAngle, in: 0...Float.pi / 2)
                }
                VStack {
                    Text("Distance: \(sensorDistance, specifier: "%.2f")")
                        .font(.title)
                    Slider(value: $sensorDistance, in: 0...15)
                }
                VStack {
                    Text("Turn Angle: \(turnAngle, specifier: "%.2f")")
                        .font(.title)
                    Slider(value: $turnAngle, in: 0...Float.pi / 4)
                }
            }.padding(5)
            
            
            MetalView(fps: $fps,
                      background: $bgColor,
                      drawParticles: $drawParticles,
                      drawPath: $drawPath,
                      sensorAngle: $sensorAngle,
                      sensorDistance: $sensorDistance,
                      turnAngle: $turnAngle)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
