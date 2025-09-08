//
//  CoinManager.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import Foundation
import SwiftUI

class CoinManager {
    static let shared = CoinManager()
    
    private let coinKey = "UserCoins"
    private let milestoneKey = "CompletedTaskMilestones"
    private let levelMilestoneKey = "CompletedLevelMilestones"
    
    // Milestone rewards - tasks completed: coins awarded
    private let milestones: [Int: Int] = [
        5: 50,    // 5 tasks: 50 bonus coins
        10: 100,  // 10 tasks: 100 bonus coins
        20: 200,  // 20 tasks: 200 bonus coins
        50: 500,  // 50 tasks: 500 bonus coins
        100: 1000 // 100 tasks: 1000 bonus coins
    ]
    
    // Level milestone rewards - level: coins awarded
    private let levelMilestones: [Int: Int] = [
        5: 10,    // Level 5: 10 bonus coins
        10: 25,   // Level 10: 25 bonus coins
        15: 50,   // Level 15: 50 bonus coins
        20: 100,  // Level 20: 100 bonus coins
        25: 150,  // Level 25: 150 bonus coins
    ]
    
    // Get current coin balance
    var coins: Int {
        get {
            return UserDefaults.standard.integer(forKey: coinKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: coinKey)
        }
    }
    
    // Get completed milestones
    private var completedMilestones: [Int] {
        get {
            return UserDefaults.standard.array(forKey: milestoneKey) as? [Int] ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: milestoneKey)
        }
    }
    
    // Get completed level milestones
    private var completedLevelMilestones: [Int] {
        get {
            return UserDefaults.standard.array(forKey: levelMilestoneKey) as? [Int] ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: levelMilestoneKey)
        }
    }
    
    // Award coins for completing a task
    func awardCoinsForTaskCompletion(taskCount: Int) -> (awarded: Int, milestone: Bool, milestoneAmount: Int) {
        // Base reward for any task completion
        let baseReward = 10
        var milestoneReward = 0
        var hitMilestone = false
        
        // Check if any milestone was reached
        for (milestone, reward) in milestones.sorted(by: { $0.key < $1.key }) {
            if taskCount == milestone && !completedMilestones.contains(milestone) {
                milestoneReward = reward
                hitMilestone = true
                
                // Mark milestone as completed
                var updatedMilestones = completedMilestones
                updatedMilestones.append(milestone)
                completedMilestones = updatedMilestones
                break
            }
        }
        
        // Add coins to balance
        let totalReward = baseReward + milestoneReward
        coins += totalReward
        
        return (awarded: totalReward, milestone: hitMilestone, milestoneAmount: milestoneReward)
    }
    
    // Award coins for reaching a new level
    func awardCoinsForLevel(level: Int) -> (awarded: Int, milestone: Bool, milestoneAmount: Int) {
        // Base reward for any level
        let baseReward = 2
        var milestoneReward = 0
        var hitMilestone = false
        
        // Check if any milestone was reached
        for (milestone, reward) in levelMilestones.sorted(by: { $0.key < $1.key }) {
            if level == milestone && !completedLevelMilestones.contains(milestone) {
                milestoneReward = reward
                hitMilestone = true
                
                // Mark milestone as completed
                var updatedMilestones = completedLevelMilestones
                updatedMilestones.append(milestone)
                completedLevelMilestones = updatedMilestones
                break
            }
        }
        
        // Add coins to balance
        let totalReward = baseReward + milestoneReward
        coins += totalReward
        
        return (awarded: totalReward, milestone: hitMilestone, milestoneAmount: milestoneReward)
    }
    
    // Spend coins
    func spendCoins(_ amount: Int) -> Bool {
        if coins >= amount {
            coins -= amount
            return true
        }
        return false
    }
    
    // Reset all coins and milestones (for debugging)
    func resetCoins() {
        coins = 0
        completedMilestones = []
        completedLevelMilestones = []
    }
} 