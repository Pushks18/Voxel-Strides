//
//  CollectiblesView.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import SwiftUI
import RealityKit
import SceneKit

struct CollectiblesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCollectible: Collectible?
    @State private var showingDetail = false
    @State private var completedFocusSessions = UserDefaults.standard.integer(forKey: "CompletedFocusSessions")
    
    // For preview and testing
    @State private var previewUnlockAll: Bool
    
    // Add state variable to force refresh when purchases change
    @State private var purchasedCollectibles: [String] = []
    
    // Static method to reset data
    static func resetData() {
        // Reset focus sessions in UserDefaults
        UserDefaults.standard.set(0, forKey: "CompletedFocusSessions")
    }
    
    // Add initializer with default parameter
    init(previewUnlockAll: Bool = false) {
        self._previewUnlockAll = State(initialValue: previewUnlockAll)
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
                    // Progress header
                    VStack(spacing: 5) {
                        Text("Focus Sessions Completed")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("\(completedFocusSessions)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        // Next collectible progress
                        if let nextCollectible = findNextCollectible() {
                            let remaining = nextCollectible.requiredLevel - completedFocusSessions
                            
                            Text("\(remaining) more to unlock \(nextCollectible.name)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, 5)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(15)
                    
                    // Collectibles grid
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 180))], spacing: 20) {
                            ForEach(CollectibleManager.items.sorted(by: { $0.requiredLevel < $1.requiredLevel })) { collectible in
                                collectibleCard(collectible)
                            }
                        }
                        .padding()
                        
                        // Add spacer at the bottom to prevent tab bar overlap
                        Spacer(minLength: 80)
                    }
                    
                    // Debug controls for demonstration
                    VStack(spacing: 10) {
                        Text("Demo Controls")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.top)
                        
                        Button("Add Focus Session") {
                            // Limit to maximum 55 to avoid memory issues
                            if completedFocusSessions < 55 {
                                completedFocusSessions += 1
                                UserDefaults.standard.set(completedFocusSessions, forKey: "CompletedFocusSessions")
                                checkForNewCollectible()
                                
                                // Play level up sound
                                MusicManager.shared.playSound(.levelUp)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        
                        Button("Reset Focus Progress") {
                            completedFocusSessions = 0
                            UserDefaults.standard.set(0, forKey: "CompletedFocusSessions")
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding()
            }
            .navigationTitle("Collectibles")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedCollectible) { collectible in
                CollectibleDetailView(collectible: collectible)
            }
            .onAppear {
                // Refresh focus sessions count
                completedFocusSessions = UserDefaults.standard.integer(forKey: "CompletedFocusSessions")
                
                checkForNewCollectible()
                refreshCollectibles()
                
                // Add notification observer for purchases
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("CollectiblePurchased"),
                    object: nil,
                    queue: .main
                ) { _ in
                    refreshCollectibles()
                }
            }
            .onDisappear {
                // Remove notification observer
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSNotification.Name("CollectiblePurchased"),
                    object: nil
                )
            }
        }
    }
    
    // Add a function to refresh the purchased collectibles
    private func refreshCollectibles() {
        // Get the current list of purchased collectibles from UserDefaults
        if let savedItems = UserDefaults.standard.array(forKey: "PurchasedCollectibles") as? [String] {
            purchasedCollectibles = savedItems
        } else {
            purchasedCollectibles = []
        }
    }
    
    // Individual collectible card
    private func collectibleCard(_ collectible: Collectible) -> some View {
        // Use the purchasedCollectibles array to force view updates when purchases change
        let isPurchased = purchasedCollectibles.contains(collectible.name)
        let isUnlocked = previewUnlockAll || 
                         completedFocusSessions >= collectible.requiredLevel || 
                         isPurchased
        
        // For the initial app state, force all collectibles to be locked
        let forceAllLocked = !previewUnlockAll && completedFocusSessions < collectible.requiredLevel && !isPurchased
        
        return Button(action: {
            if !forceAllLocked {
                selectedCollectible = collectible
            }
        }) {
            VStack {
                ZStack {
                    // Background for the icon
                    Circle()
                        .fill(
                            forceAllLocked ?
                            RadialGradient(
                                colors: [Color.gray.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            ) :
                            RadialGradient(
                                colors: [colorFromString(collectible.color).opacity(0.7), .clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    if forceAllLocked {
                        // Locked icon
                        Image(systemName: "lock.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.gray)
                    } else {
                        // 3D Model view instead of icon
                        AnimatedCollectibleARView(modelFileName: collectible.modelFileName)
                            .frame(width: 100, height: 100)
                    }
                }
                .frame(height: 100)
                
                Text(forceAllLocked ? "Locked" : collectible.name)
                    .font(.headline)
                    .foregroundStyle(forceAllLocked ? .gray : .white)
                    .multilineTextAlignment(.center)
                
                if !forceAllLocked {
                    // Show "Purchased" for store-bought items
                    if isPurchased && completedFocusSessions < collectible.requiredLevel {
                        Text("Purchased")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("Level \(collectible.requiredLevel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Unlocks at Level \(collectible.requiredLevel)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(15)
        }
    }
    
    // Find the next collectible to unlock
    private func findNextCollectible() -> Collectible? {
        return CollectibleManager.items
            .filter { $0.requiredLevel > completedFocusSessions }
            .min { $0.requiredLevel < $1.requiredLevel }
    }
    
    // Check if a new collectible should be unlocked
    private func checkForNewCollectible() {
        // Find all collectibles that match the current level
        let newCollectibles = CollectibleManager.items.filter { $0.requiredLevel == completedFocusSessions }
        
        // If any found, show the first one
        if let collectible = newCollectibles.first {
            selectedCollectible = collectible
        }
    }
    
    // Helper to convert string color to SwiftUI Color
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "cyan": return .cyan
        case "orange": return .orange
        case "purple": return .purple
        case "gold": return .yellow
        default: return .cyan
        }
    }
}

// Detail view when a collectible is selected
struct CollectibleDetailView: View {
    let collectible: Collectible
    @Environment(\.dismiss) private var dismiss
    
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
                
                Button("Close") {
                    dismiss()
                }
                .font(.headline)
                .padding()
                .frame(width: 200)
                .background(collectibleColor)
                .foregroundStyle(.white)
                .cornerRadius(15)
                .padding(.bottom)
            }
            .padding()
        }
    }
}

#Preview {
    CollectiblesView(previewUnlockAll: true)
} 