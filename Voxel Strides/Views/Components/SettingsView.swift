//
//  SettingsView.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/17/25.
//

import SwiftUI
import UserNotifications
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
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
                    // Settings header
                    Text("Settings")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top)
                    
                    // Demo section
                    VStack(spacing: 15) {
                        Text("Demo Features")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        Button("Create Overdue Task") {
                            createOverdueTask()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        Button("Create Soon-to-be-Overdue Task") {
                            createSoonOverdueTask()
                        }
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        Text("For Demo: Create an overdue 'Go for a run' task. Then force-quit the app and reopen it to trigger the automatic accountability check.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(15)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.cyan)
                }
            }
        }
    }
    
    // Create an overdue "Go for a run" task
    func createOverdueTask() {
        // Create a date for yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        
        // Create the task
        let task = Task(
            title: "Go for a run",
            dueDate: yesterday,
            priority: .high,
            category: .exercise,
            color: .cyan,
            notes: "30 minute jog around the neighborhood"
        )
        
        // Add to model context
        modelContext.insert(task)
        
        // Show confirmation
        print("Created overdue 'Go for a run' task")
    }
    
    // Create a task that will become overdue in 1 minute
    func createSoonOverdueTask() {
        // Create a date that's 1 minute from now
        let oneMinuteFromNow = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
        
        // Create the task
        let task = Task(
            title: "Quick workout",
            dueDate: oneMinuteFromNow,
            priority: .high,
            category: .exercise,
            color: .orange,
            notes: "This task will become overdue in 1 minute for testing"
        )
        
        // Add to model context
        modelContext.insert(task)
        
        // Show confirmation alert
        print("Created task due in 1 minute: \(oneMinuteFromNow)")
        
        // Notify the user
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        let timeString = formatter.string(from: oneMinuteFromNow)
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { success, _ in
            if success {
                let content = UNMutableNotificationContent()
                content.title = "Task Created"
                content.body = "Task 'Quick workout' will be due at \(timeString). Close the app and wait for the overdue notification."
                
                let request = UNNotificationRequest(
                    identifier: "task-created-\(UUID().uuidString)",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                )
                
                UNUserNotificationCenter.current().add(request)
            }
        }
    }
}

#Preview {
    SettingsView()
} 