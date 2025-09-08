//
//  Collectible.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import Foundation

// A struct to represent a single collectible item
struct Collectible: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let modelFileName: String // The name of the .usdz file (e.g., "MagicCrystal.usdz")
    let requiredLevel: Int
    let color: String // For visual styling
    let price: Int // Price in coins
    var isPurchased: Bool = false // Whether the user has purchased this collectible
}

// A manager to hold all available collectibles in your app
class CollectibleManager {
    static let shared = CollectibleManager()
    
    static let items: [Collectible] = [
        Collectible(
            name: "Crystal of Focus",
            description: "A gem that sharpens the mind. Awarded for completing 5 focus sessions.",
            modelFileName: "stylized_crystal_cluster",
            requiredLevel: 5,
            color: "cyan",
            price: 100
        ),
        
        Collectible(
            name: "The Phoenix Feather",
            description: "A symbol of resilience and rebirth. Awarded for completing 10 focus sessions.",
            modelFileName: "magical_staff",
            requiredLevel: 10,
            color: "orange",
            price: 250
        ),
        
        Collectible(
            name: "Dragon Scale",
            description: "A rare artifact of power and protection. Awarded for completing 15 focus sessions.",
            modelFileName: "the_ethereal_sword_crystal_version",
            requiredLevel: 15,
            color: "purple",
            price: 400
        ),
        
        Collectible(
            name: "Enchanted Hourglass",
            description: "Master of time itself. Awarded for completing 20 focus sessions.",
            modelFileName: "fantasy_compass",
            requiredLevel: 20,
            color: "gold",
            price: 500
        ),
        
        // Additional collectibles
        Collectible(
            name: "Crystal Lantern",
            description: "Illuminates the path to productivity. Earned after 25 focus sessions.",
            modelFileName: "crystal_jack_o_lantern___free_download",
            requiredLevel: 25,
            color: "orange",
            price: 650
        ),
        
        Collectible(
            name: "Energy Axe",
            description: "Cuts through distractions with ease. Earned after 30 focus sessions.",
            modelFileName: "energy_axe",
            requiredLevel: 30,
            color: "green",
            price: 800
        ),
        
        Collectible(
            name: "Ice Blade",
            description: "Forged in the coldest focus. Keeps your mind cool under pressure.",
            modelFileName: "ice_sword",
            requiredLevel: 35,
            color: "cyan",
            price: 950
        ),
        
        Collectible(
            name: "Amethyst Fossil",
            description: "Ancient wisdom crystallized. Represents your enduring dedication.",
            modelFileName: "ammonite_surrounded_by_amethyst_crystals",
            requiredLevel: 40,
            color: "purple",
            price: 1100
        ),
        
        Collectible(
            name: "Fantasy Hammer",
            description: "Powerful enough to forge new habits. Awarded for true dedication.",
            modelFileName: "fantasy_hammer",
            requiredLevel: 45,
            color: "red",
            price: 1250
        ),
        
        Collectible(
            name: "Crystal Pendant",
            description: "Wear the symbol of your focus mastery. A rare and precious reward.",
            modelFileName: "crystal_pendant_updated_2022",
            requiredLevel: 50,
            color: "cyan",
            price: 1500
        )
    ]
    
    // User's collection of unlocked items
    private var purchasedCollectibles: Set<String> = []
    
    init() {
        loadPurchasedCollectibles()
    }
    
    // Load purchased collectibles from UserDefaults
    private func loadPurchasedCollectibles() {
        if let savedItems = UserDefaults.standard.array(forKey: "PurchasedCollectibles") as? [String] {
            purchasedCollectibles = Set(savedItems)
        }
    }
    
    // Check if a collectible is purchased
    func isPurchased(collectible: Collectible) -> Bool {
        return purchasedCollectibles.contains(collectible.name)
    }
    
    // Purchase a collectible
    func purchase(collectible: Collectible) -> Bool {
        // First check if already purchased to prevent double-purchasing
        if isPurchased(collectible: collectible) {
            return false
        }
        
        if CoinManager.shared.spendCoins(collectible.price) {
            purchasedCollectibles.insert(collectible.name)
            saveState()
            return true
        }
        return false
    }
    
    // Save purchased collectibles to UserDefaults
    private func saveState() {
        UserDefaults.standard.set(Array(purchasedCollectibles), forKey: "PurchasedCollectibles")
    }
    
    // Find a collectible for a specific level
    func collectibleForLevel(_ level: Int) -> Collectible? {
        return CollectibleManager.items.first { $0.requiredLevel == level }
    }
    
    // Reset all purchases (for debugging)
    func resetPurchases() {
        purchasedCollectibles.removeAll()
        saveState()
        print("DEBUG: All purchased collectibles have been reset")
    }
    
    // Debug: Print current purchased collectibles
    func printPurchasedCollectibles() {
        print("DEBUG: Currently purchased collectibles: \(purchasedCollectibles)")
    }
} 