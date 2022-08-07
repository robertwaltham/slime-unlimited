//
//  ContentView.swift
//  SlimeUnlimited
//
//  Created by Robert Waltham on 2022-07-23.
//

import SwiftUI


struct ContentView: View {

    
    @State var started: Bool
    
    @StateObject var viewModel = ViewModel()

    var body: some View {
        
        if (started) {

            VStack {
                HStack {
                    Toggle("Draw Particles", isOn: $viewModel.drawParticles).padding(.horizontal)
                    Toggle("Draw Path", isOn: $viewModel.drawPath).padding(.horizontal)
                }
                
                HStack(alignment: .center, spacing: 15) {
                    VStack {
                        Text("Sensor Angle: \(viewModel.sensorAngle, specifier: "%.2f")")
                            .font(.title)
                        Slider(value: $viewModel.sensorAngle, in: 0...Float.pi / 2)
                    }
                    VStack {
                        Text("Distance: \(viewModel.sensorDistance, specifier: "%.2f")")
                            .font(.title)
                        Slider(value: $viewModel.sensorDistance, in: 0...15)
                    }
                    VStack {
                        Text("Turn Angle: \(viewModel.turnAngle, specifier: "%.2f")")
                            .font(.title)
                        Slider(value: $viewModel.turnAngle, in: 0...Float.pi / 4)
                    }
                }.padding(5)
                
                MetalView(viewModel: viewModel)
                
                HStack(alignment: .center, spacing: 15) {
                    VStack {
                        Text("Speed: \(viewModel.speedMultiplier, specifier: "%.2f")")
                            .font(.title)
                        Slider(value: $viewModel.speedMultiplier, in: 0...6)
                    }

                    VStack {
                        Text("Falloff: \(viewModel.falloff, specifier: "%.3f")")
                            .font(.title)
                        Slider(value: $viewModel.falloff, in: 0.001...0.1)
                    }
                    
                    VStack() {
                        Text("Trail Size: \(Int(viewModel.trailRadius))").font(.title)
                        Slider(value: $viewModel.trailRadius, in: 1...5)
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
                        
                        Text("FPS: \(viewModel.fps, specifier: "%.0f")")
                            .frame(width: 60, height: 26.5, alignment: .center)
                            .padding(3)
                    }
          
                }.padding(10)
            }
        } else {
            VStack() {
                LazyVStack() {

                    Text("Slime Count").font(.title)

                    Picker("Slime", selection: $viewModel.count) {
                        ForEach(viewModel.particleCounts, id: \.self) {
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

class ViewModel: ObservableObject {
    @Published var fps: Double = 0

    @Published var drawParticles: Bool = false
    @Published var drawPath: Bool = true
    
    @Published var sensorAngle: Float = Float.pi / 8
    @Published var sensorDistance: Float = 10
    @Published var turnAngle: Float = Float.pi / 16
    
    @Published var cutoff: Float = 0.01
    @Published var falloff: Float = 0.02
    @Published var trailRadius: Float = 2
    @Published var speedMultiplier: Float = 2
    
    
    let particleCounts = [2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288, 1048576]
    @Published var count = 8192
    
    @Published var bgColor = Color(.sRGB, red: 0, green: 0, blue: 0,opacity: 0)
    
    func particleConfig() -> ParticleConfig {
        return ParticleConfig(sensorAngle: sensorAngle,
                              sensorDistance: sensorDistance,
                              turnAngle: turnAngle,
                              drawRadius: 2,
                              trailRadius: trailRadius,
                              cutoff: cutoff,
                              falloff: falloff,
                              speedMultiplier: speedMultiplier)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(started: false)
        ContentView(started: true)
    }
}
