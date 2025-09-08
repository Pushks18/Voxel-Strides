//
//  StoreView.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import SwiftUI

struct StoreView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCollectible: Collectible?
    @State private var showingDetail = false
    @State private var showingPurchaseAlert = false
    @State private var purchaseSuccess = false
    @State private var purchaseMessage = ""
    @State private var coins = CoinManager.shared.coins
    
    // For animation
    @State private var showCoinAnimation = false
    @State private var animationAmount = 0.0
    
    // Static method to reset data
    static func resetData() {
        // This is just a placeholder since we don't need to reset anything specific to StoreView
        // All the relevant data is handled by CoinManager and CollectibleManager
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [.black, .indigo.opacity(0.5), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Coin balance
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
                            
                            // Animated coin for purchases
                            if showCoinAnimation {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.yellow)
                                    .scaleEffect(animationAmount)
                                    .opacity(2.0 - animationAmount)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Store title
                    Text("Collectibles Store")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top)
                    
                    Text("Purchase unique collectibles with your coins")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Collectibles grid
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 180))], spacing: 20) {
                            ForEach(CollectibleManager.items.sorted(by: { $0.price < $1.price })) { collectible in
                                storeItemCard(collectible)
                            }
                        }
                        .padding()
                        
                        // Add spacer at the bottom to prevent tab bar overlap
                        Spacer(minLength: 80)
                    }
                    
                    // Demo controls
                    VStack(spacing: 10) {
                        Text("Demo Controls")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.top)
                        
                        Button("Add 100 Coins") {
                            CoinManager.shared.coins += 100
                            updateCoins()
                            
                            // Play coin sound
                            MusicManager.shared.playSound(.notification)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        
                        Button("Reset Coins") {
                            CoinManager.shared.resetCoins()
                            updateCoins()
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .foregroundColor(.red)
                        
                        Button("Reset Purchases") {
                            CollectibleManager.shared.resetPurchases()
                            // Force refresh
                            NotificationCenter.default.post(name: NSNotification.Name("CollectiblePurchased"), object: nil)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding()
            }
            .navigationTitle("Store")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedCollectible) { collectible in
                StoreDetailView(collectible: collectible, onPurchase: {
                    purchaseCollectible(collectible)
                })
            }
            .alert(purchaseSuccess ? "Purchase Successful" : "Purchase Failed", isPresented: $showingPurchaseAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(purchaseMessage)
            }
            .onAppear {
                updateCoins()
            }
        }
    }
    
    // Individual store item card
    private func storeItemCard(_ collectible: Collectible) -> some View {
        let isPurchased = CollectibleManager.shared.isPurchased(collectible: collectible)
        let canAfford = coins >= collectible.price
        
        return Button(action: {
            if !isPurchased {
                selectedCollectible = collectible
            }
        }) {
            VStack {
                ZStack {
                    // Background for the model
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [colorFromString(collectible.color).opacity(0.7), .clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    // 3D Model view instead of icon
                    AnimatedCollectibleARView(modelFileName: collectible.modelFileName)
                        .frame(width: 100, height: 100)
                    
                    // Purchased badge
                    if isPurchased {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                    .background(
                                        Circle()
                                            .fill(.black)
                                            .frame(width: 20, height: 20)
                                    )
                            }
                        }
                        .frame(width: 90, height: 90)
                    }
                }
                .frame(height: 100)
                
                Text(collectible.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                
                // Price tag
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(.yellow)
                    
                    Text("\(collectible.price)")
                        .foregroundStyle(canAfford ? .white : .red)
                        .fontWeight(canAfford ? .regular : .bold)
                }
                .opacity(isPurchased ? 0.5 : 1.0)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.5))
                )
                
                // Status text
                Text(isPurchased ? "Owned" : (canAfford ? "Available" : "Not enough coins"))
                    .font(.caption)
                    .foregroundStyle(isPurchased ? .green : (canAfford ? .secondary : .red))
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isPurchased ? .green.opacity(0.5) : .clear, lineWidth: 2)
            )
            .opacity(isPurchased ? 0.8 : 1.0)
        }
        .disabled(isPurchased)
    }
    
    // Purchase a collectible
    private func purchaseCollectible(_ collectible: Collectible) {
        let success = CollectibleManager.shared.purchase(collectible: collectible)
        
        if success {
            // Show success animation and message
            purchaseSuccess = true
            purchaseMessage = "You've purchased \(collectible.name)!"
            
            // Update coin balance
            updateCoins()
            
            // Play purchase success sound
            MusicManager.shared.playSound(.success)
            
            // Post a notification that a purchase was made
            NotificationCenter.default.post(name: NSNotification.Name("CollectiblePurchased"), object: nil)
            
            // Show coin animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showCoinAnimation = true
                animationAmount = 2.0
            }
            
            // Hide coin animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    showCoinAnimation = false
                    animationAmount = 0.0
                }
            }
        } else {
            // Show failure message
            purchaseSuccess = false
            purchaseMessage = "Not enough coins to purchase this collectible."
        }
        
        showingPurchaseAlert = true
    }
    
    // Update coins from CoinManager
    private func updateCoins() {
        coins = CoinManager.shared.coins
    }
    
    // Helper to convert string color to SwiftUI Color
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "cyan": return .cyan
        case "orange": return .orange
        case "purple": return .purple
        case "gold": return .yellow
        case "green": return .green
        case "red": return .red
        default: return .cyan
        }
    }
}

// Detail view for a store item
struct StoreDetailView: View {
    let collectible: Collectible
    var onPurchase: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var coins = CoinManager.shared.coins
    
    // Color mapping from string to Color
    private var collectibleColor: Color {
        switch collectible.color.lowercased() {
        case "cyan": return .cyan
        case "orange": return .orange
        case "purple": return .purple
        case "gold": return .yellow
        case "green": return .green
        case "red": return .red
        default: return .cyan
        }
    }
    
    // Check if already owned
    private var isOwned: Bool {
        return CollectibleManager.shared.isPurchased(collectible: collectible)
    }
    
    // Check if user can afford
    private var canAfford: Bool {
        return coins >= collectible.price
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
            
            VStack(spacing: 30) {
                Text(collectible.name)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .shadow(color: collectibleColor.opacity(0.7), radius: 10)
                    .multilineTextAlignment(.center)
                    .padding(.top)
                
                // 3D model
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
                
                Text(collectible.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundStyle(.white)
                
                // Price tag or ownership status
                HStack {
                    if isOwned {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        
                        Text("Already Owned")
                            .font(.title3.bold())
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                        
                        Text("\(collectible.price) coins")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.5))
                )
                
                // Purchase button or owned indicator
                if isOwned {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Return to Store")
                            .font(.headline)
                            .padding()
                            .frame(width: 200)
                            .background(.ultraThinMaterial)
                            .foregroundStyle(.white)
                            .cornerRadius(15)
                    }
                } else {
                    // Purchase button
                    Button(action: {
                        onPurchase()
                        dismiss()
                    }) {
                        Text("Purchase")
                            .font(.headline)
                            .padding()
                            .frame(width: 200)
                            .background(canAfford ? collectibleColor : .gray)
                            .foregroundStyle(.white)
                            .cornerRadius(15)
                    }
                    .disabled(!canAfford)
                    
                    if !canAfford {
                        Text("Not enough coins")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                Button("Cancel") {
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom)
            }
            .padding()
            .onAppear {
                coins = CoinManager.shared.coins
            }
        }
    }
}

#Preview {
    StoreView()
} 