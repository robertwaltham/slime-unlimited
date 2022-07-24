//
//  ContentView.swift
//  SlimeUnlimited
//
//  Created by Robert Waltham on 2022-07-23.
//

import SwiftUI


struct ContentView: View {
    
    @State var fps: Double = 0
    @State private var bgColor = Color.blue.opacity(0.5)
    
    var body: some View {
        VStack {
            Text("\(fps, specifier: "%.0f")")
            ColorPicker("Choose a background color", selection: $bgColor)
                .padding(.horizontal)
            MetalView(fps: $fps)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
