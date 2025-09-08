//
//  ARCompanionView.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import SwiftUI
import ARKit
import RealityKit

struct ARCompanionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showInstructions = true
    @State private var showConfetti = false
    @State private var instructionStep = 0
    
    // Determines whether to show celebration or disappointment
    var isTaskOverdue: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(isTaskOverdue: isTaskOverdue)
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    showConfetti ? ConfettiView() : nil
                )
            
            // Instructions overlay
            if showInstructions {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 15) {
                        Text(instructionTexts[instructionStep])
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            
                        if instructionStep < instructionTexts.count - 1 {
                            Button("Next") {
                                withAnimation {
                                    instructionStep += 1
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.cyan)
                        } else {
                            Button("Start") {
                                withAnimation {
                                    showInstructions = false
                                    if !isTaskOverdue {
                                        showConfetti = true
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                    }
                    .padding()
                    .transition(.opacity)
                }
            }
            
            VStack(spacing: 20) {
                Text(isTaskOverdue ? "😔 Oh no!" : "🎉 Congratulations! 🎉")
                    .font(.title)
                    .foregroundStyle(.white)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 10)
                
                Text(isTaskOverdue ? "You missed this deadline." : "Task completed successfully!")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial.opacity(0.7))
                    .cornerRadius(10)
                
                Button(isTaskOverdue ? "I'll do better next time" : "Awesome!") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(isTaskOverdue ? .red : .cyan)
                .controlSize(.large)
                .shadow(radius: 5)
                .padding(.bottom, 30)
            }
            .padding()
        }
        .onAppear {
            if !isTaskOverdue {
                // Start confetti after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation {
                        showConfetti = true
                    }
                }
            }
            
            // Auto-dismiss instructions after a delay if user doesn't interact
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                withAnimation {
                    showInstructions = false
                }
            }
        }
    }
    
    // Instructions for the AR experience
    private let instructionTexts = [
        "Point your camera at a flat surface to place your companion",
        "Your companion will celebrate your task completion with you",
        "You can tap on your companion to interact with it"
    ]
}

// Confetti animation for celebration
struct ConfettiView: View {
    @State private var particles: [(id: Int, position: CGPoint, color: Color)] = []
    
    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: CGFloat.random(in: 5...10), height: CGFloat.random(in: 5...10))
                    .position(particle.position)
            }
        }
        .onAppear {
            generateParticles()
        }
    }
    
    func generateParticles() {
        for i in 0..<100 {
            let screenWidth = UIScreen.main.bounds.width
            let screenHeight = UIScreen.main.bounds.height
            
            let x = CGFloat.random(in: 0...screenWidth)
            let y = CGFloat.random(in: 0...screenHeight/3)
            
            let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]
            let randomColor = colors.randomElement()!
            
            let particle = (id: i, position: CGPoint(x: x, y: y), color: randomColor)
            particles.append(particle)
            
            // Animate particles falling down
            withAnimation(Animation.easeOut(duration: Double.random(in: 1...3))) {
                if let index = particles.firstIndex(where: { $0.id == i }) {
                    particles[index].position.y += screenHeight
                }
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    let isTaskOverdue: Bool
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session with improved tracking
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        // Set higher frame rate for better experience
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        
        // Run session with options for better reliability
        arView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
        
        // Create an anchor for the model
        let anchor = AnchorEntity(world: [0, 0, -1.5])
        
        // Add our companion
        loadCompanion(in: arView, anchor: anchor)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    private func loadCompanion(in arView: ARView, anchor: AnchorEntity) {
        // Create a placeholder companion by default
        let companionEntity = CompanionUtility.createPlaceholderCompanion()
        
        // Make it larger and position for better visibility
        companionEntity.scale = [1.5, 1.5, 1.5]
        companionEntity.position = [0, -0.5, -1.0]
        
        // Add animations based on task status
        if isTaskOverdue {
            addDisappointmentAnimations(to: companionEntity)
        } else {
            addCelebrationAnimations(to: companionEntity)
        }
        
        // Add directly to the scene rather than an anchor for better positioning
        anchor.addChild(companionEntity)
        arView.scene.anchors.append(anchor)
        
        // Add tap gesture to interact with companion
        arView.installGestures(.all, for: companionEntity)
    }
    
    // Enhanced celebration animations
    private func addCelebrationAnimations(to entity: Entity) {
        // Create animation to rotate the entity
        var rotateTransform = entity.transform
        rotateTransform.rotation = simd_quatf(angle: .pi * 2, axis: [0, 1, 0])
        
        // Create animation to move the entity up and down
        var jumpUpTransform = entity.transform
        jumpUpTransform.translation.y += 0.3 // Higher jump
        
        // Make the entity more noticeable by scaling it during animation
        var scaleUpTransform = entity.transform
        scaleUpTransform.scale *= 1.3
        
        // Schedule the animations with more dramatic effects
        entity.move(to: rotateTransform, relativeTo: entity, duration: 2.0, timingFunction: .easeInOut)
        
        // Jump animation sequence with scaling
        let jumpDuration = 0.4
        
        // Create a repeating jump animation for more excitement
        func performJumpSequence(repeatCount: Int = 3) {
            guard repeatCount > 0 else { return }
            
            // Jump up
            entity.move(to: jumpUpTransform, relativeTo: nil, duration: jumpDuration)
            entity.move(to: scaleUpTransform, relativeTo: nil, duration: jumpDuration * 0.8)
            
            // Jump down
            DispatchQueue.main.asyncAfter(deadline: .now() + jumpDuration) {
                var downTransform = entity.transform
                downTransform.translation.y -= 0.3
                var scaleDownTransform = entity.transform
                scaleDownTransform.scale /= 1.3
                
                entity.move(to: downTransform, relativeTo: nil, duration: jumpDuration)
                entity.move(to: scaleDownTransform, relativeTo: nil, duration: jumpDuration * 0.8)
                
                // Repeat with a small delay
                DispatchQueue.main.asyncAfter(deadline: .now() + jumpDuration + 0.1) {
                    performJumpSequence(repeatCount: repeatCount - 1)
                }
            }
        }
        
        // Start the jump sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            performJumpSequence()
            
            // Add a final spin at the end
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                var spinTransform = entity.transform
                spinTransform.rotation = simd_quatf(angle: .pi * 4, axis: [0, 1, 0])
                entity.move(to: spinTransform, relativeTo: entity, duration: 1.5, timingFunction: .easeInOut)
                
                // Add arm wave animation
                if let leftArm = entity.findEntity(named: "leftArm") as? ModelEntity,
                   let rightArm = entity.findEntity(named: "rightArm") as? ModelEntity {
                    
                    // Wave left arm
                    var leftWaveTransform = leftArm.transform
                    leftWaveTransform.rotation = simd_quatf(angle: -1.2, axis: [0, 0, 1])
                    leftArm.move(to: leftWaveTransform, relativeTo: nil, duration: 0.5)
                    
                    // Wave right arm
                    var rightWaveTransform = rightArm.transform
                    rightWaveTransform.rotation = simd_quatf(angle: 1.2, axis: [0, 0, 1])
                    rightArm.move(to: rightWaveTransform, relativeTo: nil, duration: 0.5)
                    
                    // Return arms to normal position
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        var leftNormalTransform = leftArm.transform
                        leftNormalTransform.rotation = simd_quatf(angle: -0.3, axis: [0, 0, 1])
                        leftArm.move(to: leftNormalTransform, relativeTo: nil, duration: 0.5)
                        
                        var rightNormalTransform = rightArm.transform
                        rightNormalTransform.rotation = simd_quatf(angle: 0.3, axis: [0, 0, 1])
                        rightArm.move(to: rightNormalTransform, relativeTo: nil, duration: 0.5)
                    }
                }
            }
        }
    }
    
    // Enhanced disappointment animations for overdue tasks
    private func addDisappointmentAnimations(to entity: Entity) {
        // Create more dramatic head shake and body movement
        var shakeLeftTransform = entity.transform
        shakeLeftTransform.rotation = simd_quatf(angle: .pi * 0.15, axis: [0, 1, 0])
        
        var shakeRightTransform = entity.transform
        shakeRightTransform.rotation = simd_quatf(angle: .pi * -0.15, axis: [0, 1, 0])
        
        // Deeper slouch
        var slouchTransform = entity.transform
        slouchTransform.translation.y -= 0.1
        slouchTransform.rotation = simd_quatf(angle: .pi * 0.1, axis: [1, 0, 0])
        
        // Schedule the animations with more noticeable timing
        entity.move(to: slouchTransform, relativeTo: nil, duration: 1.0, timingFunction: .easeIn)
        
        // Head shake sequence - slower and more pronounced
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            entity.move(to: shakeLeftTransform, relativeTo: nil, duration: 0.4)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                entity.move(to: shakeRightTransform, relativeTo: nil, duration: 0.8)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    entity.move(to: shakeLeftTransform, relativeTo: nil, duration: 0.8)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        // Return to center with a final slump
                        var finalSlouchTransform = entity.transform
                        finalSlouchTransform.translation.y -= 0.05
                        entity.move(to: finalSlouchTransform, relativeTo: nil, duration: 0.5, timingFunction: .easeOut)
                    }
                }
            }
        }
    }
}

#Preview {
    ARCompanionView()
} 