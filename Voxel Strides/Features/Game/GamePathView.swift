//
//  GamePathView.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import SwiftUI

struct GamePathView: View {
    let completedTasks: Int
    @State private var characterPosition: CGPoint = .zero
    @State private var isAnimating = false
    @State private var coins = CoinManager.shared.coins
    @State private var showingCoinAnimation = false
    @State private var coinAnimationAmount = 0.0
    @State private var coinReward = 0
    
    // Static method to reset data
    static func resetData() {
        // This is just a placeholder since we don't need to reset anything specific to GamePathView
        // All the relevant data is handled by CoinManager
    }
    
    // Path configuration
    private let totalNodes = 50 // Total steps on the path
    private let nodeSize: CGFloat = 50
    private let pathSegmentHeight: CGFloat = 100
    private let zigZagWidth: CGFloat = 80
    
    // The user's current position on the path
    private var currentNode: Int {
        min(completedTasks, totalNodes)
    }
    
    // The user's current level (every 3 tasks = 1 level)
    private var currentLevel: Int {
        completedTasks / 3
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                ScrollView {
                    ZStack {
                        // Decorative background elements
                        backgroundDecorations
                        
                        // The path itself, composed of nodes
                        pathNodes
                        
                        // The user's character on the path
                        characterView
                        
                        // Add spacer at the bottom to prevent tab bar and stats overlay overlap
                        VStack {
                            Spacer()
                            Color.clear.frame(height: 150) // Increased from 80 to 150
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: pathHeight)
                    .onAppear {
                        // Set initial position and scroll to current node
                        let initialPosition = calculateNodePosition(for: currentNode)
                        characterPosition = initialPosition
                        proxy.scrollTo(currentNode, anchor: .center)
                        
                        // Update coin display
                        updateCoins()
                    }
                    .onChange(of: completedTasks) {
                        // Check for level changes
                        checkForLevelUp()
                        
                        // Animate character movement and scroll to the new node
                        withAnimation(.easeInOut(duration: 1.0)) {
                            characterPosition = calculateNodePosition(for: currentNode)
                            proxy.scrollTo(currentNode, anchor: .center)
                        }
                    }
                }
                
                // Coin balance display at the top
                VStack {
                    HStack {
                        Spacer()
                        
                        ZStack {
                            // Coin balance display
                            HStack {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.yellow)
                                
                                Text("\(coins)")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            
                            // Animated coin for rewards
                            if showingCoinAnimation {
                                HStack {
                                    Image(systemName: "dollarsign.circle.fill")
                                    Text("+\(coinReward)")
                                        .fontWeight(.bold)
                                }
                                .font(.title3)
                                .foregroundStyle(.yellow)
                                .scaleEffect(coinAnimationAmount)
                                .opacity(2.0 - coinAnimationAmount)
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
            }
        }
    }
    
    // Total height of the scrollable path area
    private var pathHeight: CGFloat {
        // Add extra padding to the total height to ensure proper spacing
        CGFloat(totalNodes) * pathSegmentHeight + 250 // Added 250 extra pixels for padding
    }
    
    // Decorative stars in the background
    private var backgroundDecorations: some View {
        ForEach(0..<totalNodes / 2) { i in
            Image(systemName: "sparkle")
                .font(.system(size: CGFloat.random(in: 10...20)))
                .foregroundStyle(.cyan.opacity(0.4))
                .position(
                    x: CGFloat.random(in: 20...UIScreen.main.bounds.width - 20),
                    y: CGFloat(i) * pathSegmentHeight * 2 + 50
                )
        }
    }
    
    // The nodes that make up the path (shoe prints)
    private var pathNodes: some View {
        ForEach(0...totalNodes, id: \.self) { index in
            nodeView(for: index)
                .position(calculateNodePosition(for: index))
                .id(index)
        }
    }
    
    // The user's character (a prominent shoe)
    private var characterView: some View {
        Image(systemName: "figure.walk.circle.fill")
            .font(.system(size: 60))
            .foregroundStyle(
                LinearGradient(
                    colors: [.cyan, .green],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: .cyan.opacity(0.8), radius: 10)
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .position(characterPosition)
            .onAppear {
                // Start a gentle pulsing animation for the character
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
    
    // A single node on the path (a shoe print)
    @ViewBuilder
    private func nodeView(for index: Int) -> some View {
        let isCompleted = index <= currentNode
        
        ZStack {
            Image(systemName: "shoeprints.fill")
                .font(.title)
                .foregroundStyle(isCompleted ? .cyan.opacity(0.8) : .gray.opacity(0.3))
                .rotationEffect(.degrees(index % 2 == 0 ? 20 : -20)) // Zig-zag rotation
            
            // Add a number to every 5th node
            nodeNumberLabel(for: index)
            
            // Show coin rewards at level milestones (every 3 tasks)
            if index > 0 && index % 3 == 0 {
                let level = index / 3
                
                // Check if this level has a special milestone reward
                let milestoneReward = getCoinRewardForLevel(level)
                
                // Show coin reward
                HStack(spacing: 2) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.caption)
                    
                    if milestoneReward > 0 {
                        // Special milestone reward
                        Text("+\(milestoneReward + 2)") // Base reward (2) + milestone reward
                    } else {
                        // Regular level reward
                        Text("+2") // Base reward for any level
                    }
                }
                .font(.caption.bold())
                .foregroundStyle(.yellow)
                .padding(4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            Capsule()
                                .strokeBorder(currentNode >= index ? .yellow : .gray.opacity(0.5), lineWidth: 1)
                        )
                )
                .offset(x: index % 2 == 0 ? 30 : -30, y: 20)
            }
        }
    }
    
    // Optional number label for certain nodes
    @ViewBuilder
    private func nodeNumberLabel(for index: Int) -> some View {
        if index > 0 && index % 5 == 0 {
            VStack(spacing: 2) {
                Text("Step")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.8))
                
                Text("\(index)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
            .padding(6)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                currentNode >= index ? .cyan : .gray.opacity(0.7),
                                currentNode >= index ? .blue.opacity(0.8) : .gray.opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: currentNode >= index ? .cyan.opacity(0.5) : .clear, radius: 3)
            )
            .offset(x: index % 2 == 0 ? -30 : 30, y: -20)
        }
    }
    
    // Calculates the screen position for a given node index
    private func calculateNodePosition(for index: Int) -> CGPoint {
        let screenWidth = UIScreen.main.bounds.width
        let centerX = screenWidth / 2
        
        // Stagger nodes in a zig-zag pattern
        let x = centerX + (index % 2 == 0 ? -zigZagWidth : zigZagWidth)
        
        // Position nodes from top to bottom, with extra spacing at the bottom
        // to ensure the first few nodes (including level 1) don't get hidden by the stats overlay
        let bottomPadding: CGFloat = 200 // Add padding to keep nodes above the stats box
        let y = pathHeight - bottomPadding - (CGFloat(index) * pathSegmentHeight)
        
        return CGPoint(x: x, y: y)
    }
    
    // Check if user has leveled up and award coins
    private func checkForLevelUp() {
        let previousLevel = (completedTasks - 1) / 3
        let newLevel = currentLevel
        
        if newLevel > previousLevel {
            // User has leveled up, award coins
            let result = CoinManager.shared.awardCoinsForLevel(level: newLevel)
            coinReward = result.awarded
            
            // Show coin animation
            showCoinAnimation()
            
            // Update coin display
            updateCoins()
        }
    }
    
    // Update coins from CoinManager
    private func updateCoins() {
        coins = CoinManager.shared.coins
    }
    
    // Show coin animation when earning coins
    private func showCoinAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showingCoinAnimation = true
            coinAnimationAmount = 2.0
        }
        
        // Hide coin animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showingCoinAnimation = false
                coinAnimationAmount = 0.0
            }
        }
    }
    
    // Helper to get coin reward for a specific level
    private func getCoinRewardForLevel(_ level: Int) -> Int {
        // Level milestone rewards from CoinManager
        let levelMilestones: [Int: Int] = [
            5: 10,    // Level 5: 10 bonus coins
            10: 25,   // Level 10: 25 bonus coins
            15: 50,   // Level 15: 50 bonus coins
            20: 100,  // Level 20: 100 bonus coins
            25: 150,  // Level 25: 150 bonus coins
        ]
        
        return levelMilestones[level] ?? 0
    }
}

#Preview {
    GamePathView(completedTasks: 5)
        .background(.black)
} 