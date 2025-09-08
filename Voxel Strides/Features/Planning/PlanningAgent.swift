//
//  PlanningAgent.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import Foundation
import CoreML
import NaturalLanguage
import SwiftUI // Added SwiftUI import for Color type

struct PlanningAgent {
    
    /// Generates a list of sub-tasks for a given high-level goal using an on-device LLM.
    ///
    /// - Parameter goal: The user's high-level goal.
    /// - Returns: An array of `Task` objects representing the generated plan.
    /// - Throws: An error if the model fails to generate a plan.
    func generatePlan(for goal: String) async throws -> [Task] {
        // Use the dynamic planning system
        return try await generateDynamicPlan(for: goal)
    }
    
    /// Generates a dynamic plan based on the goal context using Apple's NL framework
    private func generateDynamicPlan(for goal: String) async throws -> [Task] {
        // Use NLEmbedding to understand the semantic context of the goal
        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else {
            print("Failed to load word embedding model.")
            return generateHardcodedPlan(for: goal)
        }
        
        // Extract keywords from the goal
        let keywords = extractKeywords(from: goal)
        
        // Determine task categories based on goal keywords
        let (primaryCategory, color, priority) = determineTaskAttributes(for: goal, keywords: keywords)
        
        // Generate dynamic task list based on the goal's domain
        var tasks: [Task] = []
        
        if goal.localizedCaseInsensitiveContains("learn") || goal.localizedCaseInsensitiveContains("study") {
            tasks = generateLearningPlan(goal: goal, keywords: keywords, category: primaryCategory, color: color)
        } else if goal.localizedCaseInsensitiveContains("build") || goal.localizedCaseInsensitiveContains("create") || goal.localizedCaseInsensitiveContains("develop") {
            tasks = generateCreationPlan(goal: goal, keywords: keywords, category: primaryCategory, color: color)
        } else if goal.localizedCaseInsensitiveContains("fitness") || goal.localizedCaseInsensitiveContains("exercise") || goal.localizedCaseInsensitiveContains("workout") {
            tasks = generateFitnessPlan(goal: goal, keywords: keywords, category: primaryCategory, color: color)
        } else if goal.localizedCaseInsensitiveContains("cook") || goal.localizedCaseInsensitiveContains("bake") || goal.localizedCaseInsensitiveContains("recipe") {
            tasks = generateCookingPlan(goal: goal, keywords: keywords, category: primaryCategory, color: color)
        } else {
            // For other types of goals, generate a generic plan with more varied actions
            tasks = generateGenericActionPlan(goal: goal, keywords: keywords, category: primaryCategory, color: color)
        }
        
        return tasks
    }
    
    /// Extract relevant keywords from the goal
    private func extractKeywords(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass])
        tagger.string = text
        
        var keywords: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameTypeOrLexicalClass) { tag, range in
            if let tag = tag, (tag == .noun || tag == .verb || tag == .adjective) {
                let word = String(text[range]).lowercased()
                if word.count > 2 && !stopWords.contains(word) {
                    keywords.append(word)
                }
            }
            return true
        }
        
        return keywords
    }
    
    /// Determine task category, color and priority based on goal context
    private func determineTaskAttributes(for goal: String, keywords: [String]) -> (TaskCategory, Color, TaskPriority) {
        var category = TaskCategory.other
        var color: Color = .cyan
        var priority: TaskPriority = .medium
        
        // Detect most likely category
        if keywords.contains(where: { $0.contains("learn") || $0.contains("study") || $0.contains("read") || $0.contains("research") }) {
            category = .study
            color = .blue
        } else if keywords.contains(where: { $0.contains("run") || $0.contains("exercise") || $0.contains("workout") || $0.contains("fitness") }) {
            category = .exercise
            color = .orange
        } else if keywords.contains(where: { $0.contains("meeting") || $0.contains("email") || $0.contains("report") || $0.contains("project") }) {
            category = .work
            color = .indigo
        } else if keywords.contains(where: { $0.contains("doctor") || $0.contains("medicine") || $0.contains("health") }) {
            category = .health
            color = .red
        } else if keywords.contains(where: { $0.contains("travel") || $0.contains("trip") || $0.contains("vacation") }) {
            category = .travel
            color = .green
        } else if keywords.contains(where: { $0.contains("buy") || $0.contains("purchase") || $0.contains("shop") }) {
            category = .shopping
            color = .purple
        } else if keywords.contains(where: { $0.contains("clean") || $0.contains("repair") || $0.contains("home") }) {
            category = .home
            color = .brown
        }
        
        // Detect priority
        if goal.localizedCaseInsensitiveContains("urgent") || goal.localizedCaseInsensitiveContains("important") {
            priority = .high
        } else if goal.localizedCaseInsensitiveContains("maybe") || goal.localizedCaseInsensitiveContains("optional") {
            priority = .low
        }
        
        return (category, color, priority)
    }
    
    /// Common stopwords to filter out from keyword extraction
    private let stopWords: Set<String> = ["the", "and", "to", "of", "a", "in", "for", "on", "is", "that", "by", "this", "with", "i", "you", "it"]
    
    /// Generate a learning plan with diverse activities
    private func generateLearningPlan(goal: String, keywords: [String], category: TaskCategory, color: Color) -> [Task] {
        let topic = extractTopicFromGoal(goal: goal, keywords: keywords)
        
        // Create a more diverse set of learning tasks
        let learningVerbs = ["Research", "Study", "Investigate", "Explore", "Analyze", "Examine", "Learn about"]
        let learningFormats = ["video tutorial", "article", "book chapter", "podcast episode", "interactive demo", "webinar"]
        let learningActions = ["Take notes on", "Summarize key concepts from", "Create a mind map of", "Practice exercises on", "Quiz yourself on"]
        let applicationActions = ["Apply your knowledge by", "Create a small project about", "Teach someone else about", "Write a blog post about", "Design a visual representation of"]
        
        var tasks: [Task] = []
        
        // Day 1: Initial learning task
        let verb1 = learningVerbs.randomElement() ?? "Research"
        let format1 = learningFormats.randomElement() ?? "article"
        tasks.append(Task(
            title: "\(verb1) the basics of \(topic) through a \(format1)",
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400),
            priority: .high,
            category: category,
            color: color,
            notes: "Begin your journey into \(topic) with foundational knowledge."
        ))
        
        // Day 2: Deeper exploration
        let verb2 = learningVerbs.randomElement() ?? "Explore"
        let format2 = learningFormats.randomElement() ?? "book chapter"
        tasks.append(Task(
            title: "\(verb2) advanced concepts in \(topic) using a \(format2)",
            dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date().addingTimeInterval(86400 * 2),
            priority: .medium,
            category: category,
            color: color,
            notes: "Deepen your understanding of \(topic) with more complex material."
        ))
        
        // Day 3: Active learning
        let action = learningActions.randomElement() ?? "Take notes on"
        tasks.append(Task(
            title: "\(action) what you've learned about \(topic)",
            dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date().addingTimeInterval(86400 * 3),
            priority: .medium,
            category: category,
            color: color,
            notes: "Solidify your knowledge through active engagement with the material."
        ))
        
        // Day 4: Find real-world examples
        tasks.append(Task(
            title: "Find 3 real-world applications of \(topic)",
            dueDate: Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date().addingTimeInterval(86400 * 4),
            priority: .medium,
            category: category,
            color: color,
            notes: "Connect theoretical knowledge to practical applications."
        ))
        
        // Day 5: Application
        let application = applicationActions.randomElement() ?? "Apply your knowledge by"
        tasks.append(Task(
            title: "\(application) creating something related to \(topic)",
            dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date().addingTimeInterval(86400 * 5),
            priority: .low,
            category: category,
            color: color,
            notes: "Demonstrate and reinforce your understanding through practical application."
        ))
        
        return tasks
    }
    
    /// Generate a creation plan for building or creating something
    private func generateCreationPlan(goal: String, keywords: [String], category: TaskCategory, color: Color) -> [Task] {
        let project = extractTopicFromGoal(goal: goal, keywords: keywords)
        
        return [
            Task(title: "Brainstorm ideas for your \(project)",
                 dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400),
                 priority: .high, category: category, color: color,
                 notes: "Generate at least 5 different concepts or approaches."),
                 
            Task(title: "Research existing \(project)s for inspiration",
                 dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date().addingTimeInterval(86400 * 2),
                 priority: .medium, category: category, color: color,
                 notes: "Find examples that can guide your work."),
                 
            Task(title: "Create a plan or outline for your \(project)",
                 dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date().addingTimeInterval(86400 * 3),
                 priority: .high, category: category, color: color,
                 notes: "Break down the project into manageable steps."),
                 
            Task(title: "Gather resources and tools for your \(project)",
                 dueDate: Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date().addingTimeInterval(86400 * 4),
                 priority: .medium, category: category, color: color,
                 notes: "Ensure you have everything needed to begin work."),
                 
            Task(title: "Begin work on your \(project)",
                 dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date().addingTimeInterval(86400 * 5),
                 priority: .medium, category: category, color: color,
                 notes: "Start implementing your plan.")
        ]
    }
    
    /// Generate a fitness plan
    private func generateFitnessPlan(goal: String, keywords: [String], category: TaskCategory, color: Color) -> [Task] {
        let activity = extractTopicFromGoal(goal: goal, keywords: keywords)
        
        return [
            Task(title: "Research proper form for \(activity)",
                 dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400),
                 priority: .high, category: category, color: color,
                 notes: "Safety first - learn the right technique."),
                 
            Task(title: "Create a beginner-friendly \(activity) schedule",
                 dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date().addingTimeInterval(86400 * 2),
                 priority: .medium, category: category, color: color,
                 notes: "Plan your first week of activity."),
                 
            Task(title: "Complete your first \(activity) session",
                 dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date().addingTimeInterval(86400 * 3),
                 priority: .high, category: category, color: color,
                 notes: "Start with an achievable goal."),
                 
            Task(title: "Track your progress and how you feel after \(activity)",
                 dueDate: Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date().addingTimeInterval(86400 * 4),
                 priority: .low, category: category, color: color,
                 notes: "Keep a simple journal of your experience."),
                 
            Task(title: "Find a \(activity) buddy or community",
                 dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date().addingTimeInterval(86400 * 5),
                 priority: .low, category: category, color: color,
                 notes: "Social support increases long-term success.")
        ]
    }
    
    /// Generate a cooking or recipe plan
    private func generateCookingPlan(goal: String, keywords: [String], category: TaskCategory, color: Color) -> [Task] {
        let dish = extractTopicFromGoal(goal: goal, keywords: keywords)
        
        return [
            Task(title: "Find a beginner-friendly \(dish) recipe",
                 dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400),
                 priority: .high, category: category, color: color,
                 notes: "Look for recipes with clear instructions and common ingredients."),
                 
            Task(title: "Create a shopping list for \(dish) ingredients",
                 dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date().addingTimeInterval(86400 * 2),
                 priority: .medium, category: .shopping, color: .purple,
                 notes: "Check what you already have and what you need to buy."),
                 
            Task(title: "Buy ingredients for \(dish)",
                 dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date().addingTimeInterval(86400 * 3),
                 priority: .medium, category: .shopping, color: .purple,
                 notes: "Get everything you need for your recipe."),
                 
            Task(title: "Prepare and cook \(dish)",
                 dueDate: Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date().addingTimeInterval(86400 * 4),
                 priority: .high, category: category, color: color,
                 notes: "Follow your recipe carefully and enjoy the process."),
                 
            Task(title: "Evaluate your \(dish) and plan improvements",
                 dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date().addingTimeInterval(86400 * 5),
                 priority: .low, category: category, color: color,
                 notes: "Note what went well and what you could do differently next time.")
        ]
    }
    
    /// Generate a generic action plan with diverse tasks
    private func generateGenericActionPlan(goal: String, keywords: [String], category: TaskCategory, color: Color) -> [Task] {
        let topic = extractTopicFromGoal(goal: goal, keywords: keywords)
        
        // More diverse action verbs
        let actionVerbs = [
            "Research", "Investigate", "Explore", "Analyze", "Plan", 
            "Organize", "Prepare", "Contact", "Schedule", "Create",
            "Develop", "Design", "Build", "Implement", "Write",
            "Brainstorm", "Evaluate", "Test", "Review", "Finalize"
        ]
        
        // Generate 5 unique tasks using different action verbs
        var tasks: [Task] = []
        var usedVerbs = Set<String>()
        
        for i in 1...5 {
            // Get unused verbs
            let availableVerbs = actionVerbs.filter { !usedVerbs.contains($0) }
            let verb = availableVerbs.randomElement() ?? "Work on"
            usedVerbs.insert(verb)
            
            // Create task title with some variety
            var title: String
            switch i {
            case 1:
                title = "\(verb) the initial phase of \(topic)"
            case 2:
                title = "\(verb) key aspects of \(topic)"
            case 3:
                title = "\(verb) practical approaches to \(topic)"
            case 4:
                title = "\(verb) resources needed for \(topic)"
            case 5:
                title = "\(verb) next steps for \(topic)"
            default:
                title = "\(verb) \(topic)"
            }
            
            // Assign varied priorities
            let taskPriority: TaskPriority
            if i == 1 {
                taskPriority = .high
            } else if i == 5 {
                taskPriority = .low
            } else {
                taskPriority = .medium
            }
            
            tasks.append(Task(
                title: title,
                dueDate: Calendar.current.date(byAdding: .day, value: i, to: Date()) ?? Date().addingTimeInterval(86400 * Double(i)),
                priority: taskPriority,
                category: category,
                color: color,
                notes: "Task \(i) of 5 for your goal: \(goal)"
            ))
        }
        
        return tasks
    }
    
    /// Extract the main topic from the goal
    private func extractTopicFromGoal(goal: String, keywords: [String]) -> String {
        // Remove common action verbs from the goal to get the topic
        let cleanedGoal = goal
            .replacingOccurrences(of: "learn", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "research", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "study", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "build", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "create", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "develop", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "make", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "cook", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "bake", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "how to", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "about", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !cleanedGoal.isEmpty {
            return cleanedGoal
        }
        
        // If the cleaned goal is empty, try to use keywords
        if !keywords.isEmpty {
            return keywords.joined(separator: " ")
        }
        
        // Fallback to the original goal
        return goal
    }
    
    // The previous hardcoded plans now serve as a fallback.
    private func generateHardcodedPlan(for goal: String) -> [Task] {
        if goal.localizedCaseInsensitiveContains("learn about the history of japan") {
            return generateJapanHistoryPlan()
        } else if goal.localizedCaseInsensitiveContains("learn to bake") {
            return generateBakingPlan(goal: goal)
        } else if goal.localizedCaseInsensitiveContains("learn") || goal.localizedCaseInsensitiveContains("research") {
            return generateGenericLearningPlan(goal: goal)
        }
        
        // If no specific plan matches, return an empty array.
        return []
    }
    
    /// Creates a specific plan for learning Japanese history.
    private func generateJapanHistoryPlan() -> [Task] {
        // Create tasks with staggered due dates
        let tasks = [
            Task(title: "Watch a documentary on the Sengoku period", 
                 dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400), 
                 priority: .high, category: .study, color: .blue, 
                 notes: "Generated by AI Agent"),
                 
            Task(title: "Read a summary of the Meiji Restoration", 
                 dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date().addingTimeInterval(86400 * 2), 
                 priority: .medium, category: .study, color: .blue, 
                 notes: "Generated by AI Agent"),
                 
            Task(title: "Research the influence of the Samurai", 
                 dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date().addingTimeInterval(86400 * 3), 
                 priority: .medium, category: .study, color: .blue, 
                 notes: "Generated by AI Agent"),
                 
            Task(title: "Explore the cultural impact of the Edo period", 
                 dueDate: Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date().addingTimeInterval(86400 * 4), 
                 priority: .low, category: .study, color: .blue, 
                 notes: "Generated by AI Agent"),
                 
            Task(title: "Find a recipe for traditional ramen", 
                 dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date().addingTimeInterval(86400 * 5), 
                 priority: .low, category: .study, color: .orange, 
                 notes: "Generated by AI Agent")
        ]
        return tasks
    }
    
    /// Creates a plan for learning to bake something.
    private func generateBakingPlan(goal: String) -> [Task] {
        // Extracts the item to bake from the goal, e.g., "bread" from "learn to bake bread"
        let itemToBake = goal.replacingOccurrences(of: "learn to bake", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
        
        let tasks = [
            Task(title: "Find a beginner's recipe for \(itemToBake)", 
                 dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400), 
                 priority: .high, category: .home, color: .green, 
                 notes: "Generated by AI Agent"),
                 
            Task(title: "Buy ingredients for \(itemToBake)", 
                 dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date().addingTimeInterval(86400 * 2), 
                 priority: .medium, category: .shopping, color: .purple, 
                 notes: "Generated by AI Agent"),
                 
            Task(title: "Prepare the dough/batter for \(itemToBake)", 
                 dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date().addingTimeInterval(86400 * 3), 
                 priority: .medium, category: .home, color: .green, 
                 notes: "Generated by AI Agent"),
                 
            Task(title: "Bake your first \(itemToBake)", 
                 dueDate: Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date().addingTimeInterval(86400 * 4), 
                 priority: .low, category: .home, color: .green, 
                 notes: "Generated by AI Agent"),
                 
            Task(title: "Ask for feedback and ways to improve", 
                 dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date().addingTimeInterval(86400 * 5), 
                 priority: .low, category: .other, color: .gray, 
                 notes: "Generated by AI Agent")
        ]
        return tasks
    }
    
    /// Creates a generic learning plan for a given topic.
    private func generateGenericLearningPlan(goal: String) -> [Task] {
        let topic = goal.replacingOccurrences(of: "learn", with: "", options: .caseInsensitive)
                         .replacingOccurrences(of: "research", with: "", options: .caseInsensitive)
                         .trimmingCharacters(in: .whitespaces)
        
        let tasks = [
            Task(title: "Watch a 10-minute introduction video on \(topic)", 
                 dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400), 
                 priority: .high, category: .study, color: .blue, 
                 notes: "Generated by AI Agent"),
                 
            Task(title: "Read a 'for beginners' article about \(topic)", 
                 dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date().addingTimeInterval(86400 * 2), 
                 priority: .medium, category: .study, color: .blue, 
                 notes: "Generated by AI Agent"),
                 
            Task(title: "Find 3 key concepts related to \(topic)", 
                 dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date().addingTimeInterval(86400 * 3), 
                 priority: .medium, category: .study, color: .blue, 
                 notes: "Generated by AI Agent"),
                 
            Task(title: "Summarize what you've learned about \(topic) in a few sentences", 
                 dueDate: Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date().addingTimeInterval(86400 * 4), 
                 priority: .low, category: .study, color: .blue, 
                 notes: "Generated by AI Agent"),
                 
            Task(title: "Apply your knowledge with a simple project related to \(topic)", 
                 dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date().addingTimeInterval(86400 * 5), 
                 priority: .low, category: .study, color: .blue, 
                 notes: "Generated by AI Agent")
        ]
        return tasks
    }
} 