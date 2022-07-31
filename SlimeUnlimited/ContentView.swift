//
//  ContentView.swift
//  SlimeUnlimited
//
//  Created by Robert Waltham on 2022-07-23.
//

import SwiftUI


struct ContentView: View {
    
    @State var fps: Double = 0
    @State var drawParticles: Bool = false
    @State var drawPath: Bool = true
    
    @State var sensorAngle: Float = Float.pi / 8
    @State var sensorDistance: Float = 10
    @State var turnAngle: Float = Float.pi / 32
    
    @State var cutoff: Float = 0.01
    @State var falloff: Float = 0.05
    @State var trailRadius: Float = 1

    @State private var bgColor = Color(.sRGB, red: 0, green: 0, blue: 0,opacity: 0)
    
    @State var started: Bool
    
    var particleCounts = [1024, 2048, 8192, 16384, 32768, 65536, 131072, 262144, 524288]
    @State var count = 8192

    var body: some View {
        
        if (started) {

            VStack {
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
                        Slider(value: $turnAngle, in: 0...Float.pi / 8)
                    }
                }.padding(5)
                
                MetalView(fps: $fps,
                          background: $bgColor,
                          drawParticles: $drawParticles,
                          drawPath: $drawPath,
                          sensorAngle: $sensorAngle,
                          sensorDistance: $sensorDistance,
                          turnAngle: $turnAngle,
                          count: $count,
                          falloff: $falloff,
                          cutoff: $cutoff,
                          trailRadius: $trailRadius)
                
                HStack(alignment: .center, spacing: 15) {
                    VStack {
                        Text("Cutoff: \(cutoff, specifier: "%.2f")")
                            .font(.title)
                        Slider(value: $cutoff, in: 0...0.2)
                    }

                    VStack {
                        Text("Falloff: \(falloff, specifier: "%.2f")")
                            .font(.title)
                        Slider(value: $falloff, in: 0.001...0.1)
                    }
                    
                    VStack() {
                        Text("Trail Size: \(Int(trailRadius))").font(.title)
                        Slider(value: $trailRadius, in: 1...5)
                    }

                    VStack() {
                        Button(action: {
                            started = false
                        }) {
                            HStack {
                                Image(systemName: "stop")
                                    .font(.title)
                            }
                            .padding(10)
                            .foregroundColor(.white)
                            .background(Color.gray)
                            .cornerRadius(40)
                        }
                        
                        Text("FPS: \(fps, specifier: "%.0f")")
                    }
          
                }.padding(10)
            }
        } else {
            VStack() {
                LazyVStack() {

                    Text("Slime Count").font(.title)

                    Picker("Slime", selection: $count) {
                        ForEach(particleCounts, id: \.self) {
                            Text("\($0.formatted(.number.grouping(.never)))")
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .padding(20)
                }.padding([.trailing, .leading], 100)

                    
                Button(action: {
                    started = true
                }) {
                    HStack {
                        Image(systemName: "play")
                            .font(.title)
                        Text("Start")
                            .fontWeight(.semibold)
                            .font(.title)
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(40)
                }
                          
            }
        }
    
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(started: false)
        ContentView(started: true)
    }
}
