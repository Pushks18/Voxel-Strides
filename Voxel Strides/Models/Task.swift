//
//  Task.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import Foundation
import SwiftUI
import SwiftData
import Observation

// Task priority levels
enum TaskPriority: Int, Codable, CaseIterable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2
    
    var id: Int { rawValue }
    
    var name: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
    
    var color: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low:
            return "arrow.down.circle"
        case .medium:
            return "equal.circle"
        case .high:
            return "exclamationmark.circle"
        }
    }
}

// Task category/tag with preset emojis
enum TaskCategory: String, Codable, CaseIterable, Identifiable {
    case exercise = "Exercise"
    case study = "Study"
    case work = "Work"
    case health = "Health"
    case travel = "Travel"
    case shopping = "Shopping"
    case home = "Home"
    case other = "Other"
    
    var id: String { rawValue }
    
    var emoji: String {
        switch self {
        case .exercise:
            return "🏋️"
        case .study:
            return "📚"
        case .work:
            return "💼"
        case .health:
            return "💊"
        case .travel:
            return "✈️"
        case .shopping:
            return "🛒"
        case .home:
            return "🏠"
        case .other:
            return "📌"
        }
    }
    
    var color: Color {
        switch self {
        case .exercise:
            return .orange
        case .study:
            return .blue
        case .work:
            return .indigo
        case .health:
            return .red
        case .travel:
            return .green
        case .shopping:
            return .purple
        case .home:
            return .brown
        case .other:
            return .gray
        }
    }
}

@Model
final class Task: Identifiable {
    var id: UUID
    var title: String
    var dueDate: Date
    var isCompleted: Bool
    
    // New properties
    var priorityValue: Int = TaskPriority.medium.rawValue
    var categoryValue: String = TaskCategory.other.rawValue
    var colorHex: String = "#00AEEF" // Default cyan color
    var notes: String = ""
    
    // Verification properties
    var requiresVerification: Bool = true
    var verificationStatus: Int = VerificationStatus.pending.rawValue
    var verificationImageData: Data? = nil
    var verificationFeedback: String = ""
    
    // Computed properties
    var priority: TaskPriority {
        get {
            return TaskPriority(rawValue: priorityValue) ?? .medium
        }
        set {
            priorityValue = newValue.rawValue
        }
    }
    
    var category: TaskCategory {
        get {
            return TaskCategory(rawValue: categoryValue) ?? .other
        }
        set {
            categoryValue = newValue.rawValue
        }
    }
    
    var color: Color {
        get {
            return Color(hex: colorHex) ?? .cyan
        }
        set {
            colorHex = newValue.toHex() ?? "#00AEEF"
        }
    }
    
    var verification: VerificationStatus {
        get {
            return VerificationStatus(rawValue: verificationStatus) ?? .pending
        }
        set {
            verificationStatus = newValue.rawValue
        }
    }
    
    init(id: UUID = UUID(), title: String, dueDate: Date, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
    }
    
    init(id: UUID = UUID(), title: String, dueDate: Date, priority: TaskPriority, category: TaskCategory, color: Color, notes: String = "", isCompleted: Bool = false, requiresVerification: Bool = true) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.priorityValue = priority.rawValue
        self.categoryValue = category.rawValue
        self.colorHex = color.toHex() ?? "#00AEEF"
        self.notes = notes
        self.isCompleted = isCompleted
        self.requiresVerification = requiresVerification
    }
}

// Task verification status
enum VerificationStatus: Int, Codable, CaseIterable {
    case pending = 0
    case verified = 1
    case rejected = 2
    
    var description: String {
        switch self {
        case .pending:
            return "Pending Verification"
        case .verified:
            return "Verified"
        case .rejected:
            return "Rejected"
        }
    }
    
    var color: Color {
        switch self {
        case .pending:
            return .yellow
        case .verified:
            return .green
        case .rejected:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .pending:
            return "clock.fill"
        case .verified:
            return "checkmark.seal.fill"
        case .rejected:
            return "xmark.seal.fill"
        }
    }
}

// Helper extensions for color conversion
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String? {
        let uiColor = UIColor(self)
        guard let components = uiColor.cgColor.components, components.count >= 3 else {
            return nil
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX", 
                     lroundf(r * 255), 
                     lroundf(g * 255), 
                     lroundf(b * 255))
    }
} 