//
//  ContentView.swift
//  SlimeUnlimited
//
//  Created by Robert Waltham on 2022-07-23.
//

import SwiftUI


struct ContentView: View {
    
    @State var fps: Double = 0
    @State private var bgColor = Color(.sRGB, red: 0.7, green: 0.9, blue: 1, opacity: 1)
    
    var body: some View {
        VStack {
            Text("\(fps, specifier: "%.0f")")
            ColorPicker("Choose a background color", selection: $bgColor)
                .padding(.horizontal)
            MetalView(fps: $fps, background: $bgColor)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
