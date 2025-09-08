//
//  LaunchScreen.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import SwiftUI

struct LaunchScreen: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundStyle(.blue)
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .animation(.easeInOut(duration: 1.5).repeatForever(), value: isAnimating)
            
            Text("Voxel Strides")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            Text("Your tasks, gamified")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    LaunchScreen()
} 