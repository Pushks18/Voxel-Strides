//
//  AccountabilityAgent.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/17/25.
//

import Foundation
import SwiftUI
import UserNotifications
import SwiftData

class AccountabilityAgent {
    static let shared = AccountabilityAgent()
    
    // Keys for UserDefaults
    private let taskCompletionHistoryKey = "TaskCompletionHistory"
    private let taskReschedulingHistoryKey = "TaskReschedulingHistory"
    private let lastAnalysisDateKey = "LastAccountabilityAnalysisDate"
    
    // Thresholds for pattern detection
    private let missedTaskThreshold = 3 // Number of times a task must be missed to trigger a suggestion
    private let analysisFrequencyDays = 1 // How often to analyze patterns (in days)
    
    // Structure to track task completion history
    struct TaskCompletionRecord: Codable {
        let taskTitle: String
        let taskCategory: String
        let scheduledTime: Date
        let wasCompleted: Bool
        let recordDate: Date
    }
    
    // Structure to track task rescheduling history
    struct TaskReschedulingRecord: Codable {
        let taskTitle: String
        let originalTime: Date
        let newTime: Date
        let rescheduleDate: Date
        let wasSuccessful: Bool? // nil if not yet determined
    }
    
    private init() {
        requestNotificationPermissions()
    }
    
    // Request notification permissions
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted")
            } else if let error = error {
                print("Notification permissions denied: \(error.localizedDescription)")
            }
        }
    }
    
    // Record a task completion or failure
    func recordTaskCompletion(task: Task, wasCompleted: Bool) {
        let record = TaskCompletionRecord(
            taskTitle: task.title,
            taskCategory: task.categoryValue,
            scheduledTime: task.dueDate,
            wasCompleted: wasCompleted,
            recordDate: Date()
        )
        
        var history = getTaskCompletionHistory()
        history.append(record)
        
        // Save updated history
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: taskCompletionHistoryKey)
        }
        
        // Check if we should analyze patterns
        checkAndAnalyzePatterns()
    }
    
    // Get task completion history from UserDefaults
    func getTaskCompletionHistory() -> [TaskCompletionRecord] {
        guard let data = UserDefaults.standard.data(forKey: taskCompletionHistoryKey),
              let history = try? JSONDecoder().decode([TaskCompletionRecord].self, from: data) else {
            return []
        }
        return history
    }
    
    // Record a task rescheduling
    func recordTaskRescheduling(task: Task, newTime: Date) {
        let record = TaskReschedulingRecord(
            taskTitle: task.title,
            originalTime: task.dueDate,
            newTime: newTime,
            rescheduleDate: Date(),
            wasSuccessful: nil // Will be updated later when we know if the rescheduled task was completed
        )
        
        var history = getTaskReschedulingHistory()
        history.append(record)
        
        // Save updated history
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: taskReschedulingHistoryKey)
        }
    }
    
    // Update rescheduling record with success/failure
    func updateReschedulingSuccess(taskTitle: String, newTime: Date, wasSuccessful: Bool) {
        var history = getTaskReschedulingHistory()
        
        // Find and update the matching record
        for (index, record) in history.enumerated() {
            if record.taskTitle == taskTitle && 
               Calendar.current.isDate(record.newTime, inSameDayAs: newTime) &&
               record.wasSuccessful == nil {
                history[index] = TaskReschedulingRecord(
                    taskTitle: record.taskTitle,
                    originalTime: record.originalTime,
                    newTime: record.newTime,
                    rescheduleDate: record.rescheduleDate,
                    wasSuccessful: wasSuccessful
                )
                break
            }
        }
        
        // Save updated history
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: taskReschedulingHistoryKey)
        }
    }
    
    // Get task rescheduling history from UserDefaults
    func getTaskReschedulingHistory() -> [TaskReschedulingRecord] {
        guard let data = UserDefaults.standard.data(forKey: taskReschedulingHistoryKey),
              let history = try? JSONDecoder().decode([TaskReschedulingRecord].self, from: data) else {
            return []
        }
        return history
    }
    
    // Check if we should analyze patterns and do so if needed
    func checkAndAnalyzePatterns() {
        let lastAnalysis = UserDefaults.standard.object(forKey: lastAnalysisDateKey) as? Date ?? Date.distantPast
        let daysSinceLastAnalysis = Calendar.current.dateComponents([.day], from: lastAnalysis, to: Date()).day ?? 0
        
        if daysSinceLastAnalysis >= analysisFrequencyDays {
            analyzeTaskPatterns()
            UserDefaults.standard.set(Date(), forKey: lastAnalysisDateKey)
        }
    }
    
    // Analyze task completion patterns to find consistently missed tasks
    func analyzeTaskPatterns() {
        let history = getTaskCompletionHistory()
        let groupedByTitle = Dictionary(grouping: history) { $0.taskTitle }
        
        for (title, records) in groupedByTitle {
            // Only analyze tasks with enough history
            if records.count >= missedTaskThreshold {
                // Calculate completion rate
                let completionCount = records.filter { $0.wasCompleted }.count
                let completionRate = Double(completionCount) / Double(records.count)
                
                // If completion rate is low, check for time patterns
                if completionRate < 0.5 {
                    analyzeTimePatterns(for: title, records: records)
                }
            }
        }
    }
    
    // Analyze time patterns for a specific task
    func analyzeTimePatterns(for taskTitle: String, records: [TaskCompletionRecord]) {
        // Group records by hour of the day
        let calendar = Calendar.current
        var hourlyCompletion: [Int: (total: Int, completed: Int)] = [:]
        
        for record in records {
            let hour = calendar.component(.hour, from: record.scheduledTime)
            
            if let existing = hourlyCompletion[hour] {
                hourlyCompletion[hour] = (
                    total: existing.total + 1,
                    completed: existing.completed + (record.wasCompleted ? 1 : 0)
                )
            } else {
                hourlyCompletion[hour] = (
                    total: 1,
                    completed: record.wasCompleted ? 1 : 0
                )
            }
        }
        
        // Find problematic hours (low completion rate)
        var problematicHours: [Int] = []
        for (hour, stats) in hourlyCompletion {
            if stats.total >= missedTaskThreshold {
                let hourlyCompletionRate = Double(stats.completed) / Double(stats.total)
                if hourlyCompletionRate < 0.3 { // Less than 30% completion rate
                    problematicHours.append(hour)
                }
            }
        }
        
        // Find better hours (high completion rate)
        var betterHours: [Int] = []
        for (hour, stats) in hourlyCompletion {
            if stats.total >= 2 { // Need at least some data
                let hourlyCompletionRate = Double(stats.completed) / Double(stats.total)
                if hourlyCompletionRate > 0.7 { // More than 70% completion rate
                    betterHours.append(hour)
                }
            }
        }
        
        // If we have both problematic and better hours, suggest a change
        if !problematicHours.isEmpty {
            // Either use a better hour from history or suggest afternoon (5 PM)
            let suggestedHour = betterHours.first ?? 17 // Default to 5 PM if no better hour found
            
            // Find the most recent instance of this task
            if let mostRecentTask = findMostRecentTask(withTitle: taskTitle) {
                suggestTimeChange(for: mostRecentTask, fromHour: problematicHours.first!, toHour: suggestedHour)
            }
        }
    }
    
    // Find the most recent instance of a task with a given title
    func findMostRecentTask(withTitle title: String) -> Task? {
        let modelContext = PersistenceManager.shared.getModelContext()
        let currentDate = Date() // Store the current date in a variable
        
        do {
            let descriptor = FetchDescriptor<Task>(
                predicate: #Predicate<Task> { task in
                    task.title == title && !task.isCompleted && task.dueDate > currentDate
                },
                sortBy: [SortDescriptor(\.dueDate, order: .forward)]
            )
            
            let tasks = try modelContext.fetch(descriptor)
            return tasks.first
        } catch {
            print("Error fetching tasks: \(error)")
            return nil
        }
    }
    
    // Suggest a time change for a task
    func suggestTimeChange(for task: Task, fromHour: Int, toHour: Int) {
        // Create a new date with the suggested hour
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        var suggestedComponents = calendar.dateComponents([.year, .month, .day], from: task.dueDate)
        suggestedComponents.hour = toHour
        suggestedComponents.minute = 0
        
        guard let suggestedDate = calendar.date(from: suggestedComponents) else { return }
        
        // Check weather if it's an outdoor activity
        let isOutdoorActivity = task.category == .exercise || task.title.lowercased().contains("run") || 
                               task.title.lowercased().contains("walk") || task.title.lowercased().contains("jog")
        
        var message = "Hey! I've noticed we've been struggling with our \(calendar.component(.hour, from: task.dueDate)):00 \(task.title)."
        
        if isOutdoorActivity {
            message += " The weather forecast shows it's going to be better this afternoon."
        } else {
            message += " You seem to complete similar tasks better later in the day."
        }
        
        message += " Should we move this quest to \(toHour):00 instead?"
        
        // Schedule notification
        scheduleRescheduleSuggestion(
            taskId: task.id.uuidString,
            taskTitle: task.title,
            message: message,
            suggestedTime: suggestedDate
        )
    }
    
    // Schedule a notification suggesting to reschedule a task
    func scheduleRescheduleSuggestion(taskId: String, taskTitle: String, message: String, suggestedTime: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Voxel Companion Suggestion"
        content.body = message
        content.sound = .default
        
        // Add the task ID and suggested time to the notification
        content.userInfo = [
            "taskId": taskId,
            "suggestedTime": suggestedTime.timeIntervalSince1970,
            "taskTitle": taskTitle
        ]
        
        // Create a category with actions
        let rescheduleAction = UNNotificationAction(
            identifier: "RESCHEDULE_ACTION",
            title: "Reschedule",
            options: .foreground
        )
        
        let keepAction = UNNotificationAction(
            identifier: "KEEP_ACTION",
            title: "Keep as is",
            options: .foreground
        )
        
        let category = UNNotificationCategory(
            identifier: "RESCHEDULE_CATEGORY",
            actions: [rescheduleAction, keepAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "RESCHEDULE_CATEGORY"
        
        // Schedule for a reasonable time (now or soon)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false) // For testing, 5 seconds
        
        let request = UNNotificationRequest(
            identifier: "reschedule-\(taskId)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    // Handle the user's response to a rescheduling suggestion
    func handleReschedulingResponse(taskId: String, suggestedTime: Date, accepted: Bool) {
        guard let uuid = UUID(uuidString: taskId),
              let task = findTask(withId: uuid) else {
            return
        }
        
        if accepted {
            // Update the task's due date
            rescheduleTask(task, to: suggestedTime)
            
            // Record the rescheduling
            recordTaskRescheduling(task: task, newTime: suggestedTime)
        }
    }
    
    // Find a task by ID
    func findTask(withId id: UUID) -> Task? {
        let modelContext = PersistenceManager.shared.getModelContext()
        
        do {
            let descriptor = FetchDescriptor<Task>(
                predicate: #Predicate<Task> { task in
                    task.id == id
                }
            )
            
            let tasks = try modelContext.fetch(descriptor)
            return tasks.first
        } catch {
            print("Error fetching task: \(error)")
            return nil
        }
    }
    
    // Reschedule a task
    func rescheduleTask(_ task: Task, to newDate: Date) {
        task.dueDate = newDate
        
        // Save changes
        do {
            try PersistenceManager.shared.getModelContext().save()
        } catch {
            print("Error saving task changes: \(error)")
        }
    }
    
    // Reset all accountability data
    func reset() {
        // Clear task completion history
        UserDefaults.standard.removeObject(forKey: taskCompletionHistoryKey)
        
        // Clear task rescheduling history
        UserDefaults.standard.removeObject(forKey: taskReschedulingHistoryKey)
        
        // Clear last analysis date
        UserDefaults.standard.removeObject(forKey: lastAnalysisDateKey)
    }
}

// Helper class to access ModelContext outside of SwiftUI views
class PersistenceManager {
    static let shared = PersistenceManager()
    
    private var modelContext: ModelContext?
    
    // Keys for UserDefaults
    private let activeTaskIdKey = "ActiveFocusTaskId"
    private let activeTaskTimerKey = "ActiveFocusTaskTimer"
    private let activeTaskStartDateKey = "ActiveFocusTaskStartDate"
    private let activeTaskDurationKey = "ActiveFocusTaskDuration"
    private let activeTaskIsRunningKey = "ActiveFocusTaskIsRunning"
    
    // Focus quest state
    private(set) var activeTaskId: String?
    private(set) var activeTaskTimeRemaining: Int = 0
    private(set) var activeTaskStartDate: Date?
    private(set) var activeTaskDuration: Int = 0
    private(set) var activeTaskIsRunning: Bool = false
    
    private init() {
        loadFocusQuestState()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func getModelContext() -> ModelContext {
        guard let context = modelContext else {
            fatalError("ModelContext not set. Call setModelContext first.")
        }
        return context
    }
    
    // Save focus quest state to UserDefaults
    func saveFocusQuestState(taskId: String, timeRemaining: Int, duration: Int, isRunning: Bool) {
        // Save to instance variables
        activeTaskId = taskId
        activeTaskTimeRemaining = timeRemaining
        activeTaskStartDate = Date()
        activeTaskDuration = duration
        activeTaskIsRunning = isRunning
        
        // Save to UserDefaults
        UserDefaults.standard.set(taskId, forKey: activeTaskIdKey)
        UserDefaults.standard.set(timeRemaining, forKey: activeTaskTimerKey)
        UserDefaults.standard.set(Date(), forKey: activeTaskStartDateKey)
        UserDefaults.standard.set(duration, forKey: activeTaskDurationKey)
        UserDefaults.standard.set(isRunning, forKey: activeTaskIsRunningKey)
    }
    
    // Load focus quest state from UserDefaults
    func loadFocusQuestState() {
        activeTaskId = UserDefaults.standard.string(forKey: activeTaskIdKey)
        activeTaskTimeRemaining = UserDefaults.standard.integer(forKey: activeTaskTimerKey)
        activeTaskStartDate = UserDefaults.standard.object(forKey: activeTaskStartDateKey) as? Date
        activeTaskDuration = UserDefaults.standard.integer(forKey: activeTaskDurationKey)
        activeTaskIsRunning = UserDefaults.standard.bool(forKey: activeTaskIsRunningKey)
    }
    
    // Clear focus quest state
    func clearFocusQuestState() {
        activeTaskId = nil
        activeTaskTimeRemaining = 0
        activeTaskStartDate = nil
        activeTaskDuration = 0
        activeTaskIsRunning = false
        
        UserDefaults.standard.removeObject(forKey: activeTaskIdKey)
        UserDefaults.standard.removeObject(forKey: activeTaskTimerKey)
        UserDefaults.standard.removeObject(forKey: activeTaskStartDateKey)
        UserDefaults.standard.removeObject(forKey: activeTaskDurationKey)
        UserDefaults.standard.removeObject(forKey: activeTaskIsRunningKey)
    }
    
    // Check if there is an active focus quest
    var hasActiveFocusQuest: Bool {
        return activeTaskId != nil && activeTaskIsRunning
    }
    
    // Calculate the adjusted time remaining based on when the app was closed
    func calculateAdjustedTimeRemaining() -> Int {
        guard let startDate = activeTaskStartDate, activeTaskIsRunning else {
            return activeTaskTimeRemaining
        }
        
        let elapsedSeconds = Int(Date().timeIntervalSince(startDate))
        return max(0, activeTaskTimeRemaining - elapsedSeconds)
    }
} 