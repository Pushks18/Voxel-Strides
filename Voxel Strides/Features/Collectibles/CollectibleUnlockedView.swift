//
//  CollectibleUnlockedView.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import SwiftUI
import RealityKit

struct CollectibleUnlockedView: View {
    let collectible: Collectible
    @Binding var isPresented: Bool
    
    // Animation states
    @State private var showTitle = false
    @State private var showModel = false
    @State private var showDescription = false
    @State private var showButton = false
    @State private var particleOpacity = 0.0
    
    // Color mapping from string to Color
    private var collectibleColor: Color {
        switch collectible.color.lowercased() {
        case "cyan": return .cyan
        case "orange": return .orange
        case "purple": return .purple
        case "gold": return .yellow
        default: return .cyan
        }
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.black, collectibleColor.opacity(0.3), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Particle effects
            ZStack {
                ForEach(0..<30) { i in
                    Circle()
                        .fill(collectibleColor.opacity(Double.random(in: 0.1...0.3)))
                        .frame(width: Double.random(in: 4...12), height: Double.random(in: 4...12))
                        .offset(x: CGFloat.random(in: -150...150), y: CGFloat.random(in: -300...300))
                        .blur(radius: 2)
                }
            }
            .opacity(particleOpacity)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: particleOpacity)
            
            // Content
            VStack(spacing: 30) {
                // Title animation
                if showTitle {
                    Text("New Collectible Unlocked!")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .shadow(color: collectibleColor.opacity(0.7), radius: 10)
                        .transition(.scale.combined(with: .opacity))
                    
                    Text(collectible.name)
                        .font(.title)
                        .foregroundStyle(collectibleColor)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // 3D model
                if showModel {
                    ZStack {
                        // Glowing background
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [collectibleColor.opacity(0.6), .clear],
                                    center: .center,
                                    startRadius: 50,
                                    endRadius: 150
                                )
                            )
                            .frame(width: 300, height: 300)
                            .blur(radius: 20)
                        
                        // AR view with 3D model
                        AnimatedCollectibleARView(modelFileName: collectible.modelFileName)
                            .frame(height: 300)
                            .cornerRadius(20)
                    }
                    .transition(.opacity)
                }
                
                // Description
                if showDescription {
                    Text(collectible.description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .foregroundStyle(.white)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Button
                if showButton {
                    Button(action: {
                        withAnimation {
                            isPresented = false
                        }
                    }) {
                        Text("Awesome!")
                            .font(.headline)
                            .padding()
                            .frame(width: 200)
                            .background(collectibleColor)
                            .foregroundStyle(.white)
                            .cornerRadius(15)
                    }
                    .transition(.scale)
                }
            }
            .padding()
        }
        .onAppear {
            // Staggered animations for a more dynamic reveal
            withAnimation(.easeOut(duration: 0.6)) {
                showTitle = true
                particleOpacity = 0.7
            }
            
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                showModel = true
            }
            
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                showDescription = true
            }
            
            withAnimation(.spring().delay(1.2)) {
                showButton = true
            }
        }
    }
}

// Helper method to get an icon for the collectible
private func collectibleIcon(for collectible: Collectible) -> String {
    switch collectible.name {
    case "Crystal of Focus": return "diamond.fill"
    case "The Phoenix Feather": return "flame.fill"
    case "Dragon Scale": return "shield.fill"
    case "Enchanted Hourglass": return "hourglass"
    default: return "star.fill"
    }
} 