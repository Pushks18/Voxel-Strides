//
//  NeonBackgroundView.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import SwiftUI

struct NeonBackgroundView: View {
    @State private var animateGradient = false
    @State private var particles: [ParticleModel] = []
    
    let colors: [Color] = [.purple, .blue, .cyan]
    let taskCompletionCount: Int
    let maxLadderHeight: CGFloat = 10
    
    init(taskCompletionCount: Int) {
        self.taskCompletionCount = taskCompletionCount
        
        // Create initial particles
        _particles = State(initialValue: (0..<15).map { _ in
            ParticleModel(
                position: CGPoint(
                    x: CGFloat.random(in: 0...1),
                    y: CGFloat.random(in: 0...1)
                ),
                size: CGFloat.random(in: 3...8),
                speed: CGFloat.random(in: 0.005...0.01),
                opacity: Double.random(in: 0.3...0.8),
                color: [.cyan, .purple, .blue, .pink].randomElement() ?? .blue
            )
        })
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: animateGradient ? [.black, .indigo.opacity(0.6), .black] : [.black, .purple.opacity(0.6), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(
                Animation.easeInOut(duration: 5)
                    .repeatForever(autoreverses: true),
                value: animateGradient
            )
            .onAppear {
                animateGradient = true
            }
            
            // Floating particles
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(
                            x: particle.position.x * UIScreen.main.bounds.width,
                            y: particle.position.y * UIScreen.main.bounds.height
                        )
                        .opacity(particle.opacity)
                        .blur(radius: 1)
                }
            }
            .drawingGroup() // Performance optimization
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                    updateParticles()
                }
            }
            
            // Ladder on the right side
            VStack(spacing: 0) {
                ForEach(0..<Int(maxLadderHeight), id: \.self) { index in
                    LadderRungView(
                        isActive: taskCompletionCount > index,
                        isTopRung: index == Int(maxLadderHeight) - 1
                    )
                }
            }
            .frame(width: 50, height: UIScreen.main.bounds.height * 0.8)
            .position(x: UIScreen.main.bounds.width - 40, y: UIScreen.main.bounds.height / 2)
        }
    }
    
    private func updateParticles() {
        for i in particles.indices {
            // Move particles upward slowly
            var newPosition = particles[i].position
            newPosition.y -= particles[i].speed
            
            // Reset position if it goes off screen
            if newPosition.y < 0 {
                newPosition.y = 1
                newPosition.x = CGFloat.random(in: 0...1)
                particles[i].size = CGFloat.random(in: 3...8)
                particles[i].opacity = Double.random(in: 0.3...0.8)
            }
            
            particles[i].position = newPosition
        }
    }
}

struct LadderRungView: View {
    let isActive: Bool
    let isTopRung: Bool
    
    @State private var glowIntensity: CGFloat = 0.5
    
    var body: some View {
        ZStack {
            // The rung of the ladder
            RoundedRectangle(cornerRadius: 3)
                .fill(isActive ? Color.cyan : Color.gray.opacity(0.5))
                .frame(width: 40, height: 8)
                .shadow(color: isActive ? Color.cyan.opacity(glowIntensity) : .clear, radius: 5)
            
            // Star at the top of the ladder
            if isTopRung && isActive {
                Image(systemName: "star.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(glowIntensity), radius: 8)
                    .offset(y: -20)
            }
        }
        .padding(.vertical, 15)
        .animation(.easeInOut, value: isActive)
        .onAppear {
            if isActive {
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.8
                }
            }
        }
    }
}

struct ParticleModel: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    let speed: CGFloat
    var opacity: Double
    let color: Color
}

#Preview {
    NeonBackgroundView(taskCompletionCount: 3)
} 