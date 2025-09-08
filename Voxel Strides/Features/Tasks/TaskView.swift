//
//  TaskView.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import SwiftUI
import SwiftData

struct TaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var task: Task
    @State private var isOverdue: Bool = false
    @State private var showingOverdueAnimation = false
    @State private var showingEditView = false
    @State private var showingCoinReward = false
    @State private var coinRewardAmount = 0
    @State private var coinScale: CGFloat = 1.0
    @State private var showingVerification = false
    @State private var isLoading = true
    
    var onStartFocusQuest: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient with task color
                LinearGradient(
                    colors: [.black, task.color.opacity(0.3), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isLoading {
                    // Loading view
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: task.color))
                            .scaleEffect(1.5)
                        
                        Text("Loading task details...")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                } else {
                    // Task details
                    ScrollView {
                        VStack(spacing: 25) {
                            // Header with category emoji
                            VStack(spacing: 10) {
                                // Category emoji
                                Text(task.category.emoji)
                                    .font(.system(size: 60))
                                    .shadow(color: task.category.color.opacity(0.7), radius: 5)
                                
                                Text(task.title)
                                    .font(.title.bold())
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                // Task metadata
                                HStack(spacing: 15) {
                                    // Due date
                                    VStack(spacing: 4) {
                                        Label(
                                            title: { Text(task.dueDate, style: .date) },
                                            icon: { Image(systemName: "calendar") }
                                        )
                                        .foregroundStyle(isOverdue ? .red : .primary)
                                        .font(.subheadline)
                                        
                                        if isOverdue && !task.isCompleted {
                                            Text("Overdue")
                                                .foregroundStyle(.red)
                                                .font(.caption.bold())
                                        }
                                    }
                                    
                                    // Priority
                                    VStack(spacing: 4) {
                                        Label(
                                            title: { Text(task.priority.name) },
                                            icon: { Image(systemName: task.priority.icon) }
                                        )
                                        .foregroundStyle(task.priority.color)
                                        .font(.subheadline)
                                        
                                        Text("Priority")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    }
                                    
                                    // Category
                                    VStack(spacing: 4) {
                                        Text(task.category.rawValue)
                                            .foregroundStyle(task.category.color)
                                            .font(.subheadline)
                                        
                                        Text("Category")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .shadow(color: isOverdue ? .red.opacity(0.5) : task.color.opacity(0.4), radius: 10)
                            
                            // Task status display
                            ZStack {
                                // Status circle background
                                Circle()
                                    .stroke(lineWidth: 12)
                                    .opacity(0.3)
                                    .foregroundStyle(statusColor)
                                
                                // Status icon
                                Image(systemName: statusIcon)
                                    .font(.system(size: 60))
                                    .foregroundStyle(statusColor)
                                    .symbolEffect(
                                        .bounce.byLayer,
                                        options: .repeating,
                                        value: showingOverdueAnimation
                                    )
                            }
                            .frame(width: 120, height: 120)
                            
                            // Notes section if available
                            if !task.notes.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Notes")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                    
                                    Text(task.notes)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                            
                            // Action buttons
                            VStack(spacing: 15) {
                                if !task.isCompleted {
                                    Button(action: {
                                        onStartFocusQuest()
                                    }) {
                                        Label("Start Focus Quest", systemImage: "timer")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(
                                                LinearGradient(
                                                    colors: [task.color, task.color.opacity(0.7)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .foregroundStyle(.white)
                                            .cornerRadius(12)
                                            .shadow(color: task.color.opacity(0.6), radius: 5)
                                    }
                                    
                                    Button(action: {
                                        if task.requiresVerification {
                                            // Show verification view
                                            showingVerification = true
                                        } else {
                                            withAnimation {
                                                task.isCompleted = true
                                            }
                                            
                                            // Play celebration sound
                                            MusicManager.shared.playCelebration()
                                            
                                            // Award coins for task completion
                                            let completedCount = UserDefaults.standard.integer(forKey: "CompletedTaskCount") + 1
                                            let result = CoinManager.shared.awardCoinsForTaskCompletion(taskCount: completedCount)
                                            
                                            // Record task completion in Accountability Agent
                                            AccountabilityAgent.shared.recordTaskCompletion(task: task, wasCompleted: true)
                                            
                                            // Show coin reward toast
                                            showCoinReward(amount: result.awarded)
                                            
                                            // Return to previous view after a short delay
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                dismiss()
                                            }
                                        }
                                    }) {
                                        Label(task.requiresVerification ? "Verify Completion" : "Mark as Completed", 
                                              systemImage: task.requiresVerification ? "camera.viewfinder" : "checkmark.circle")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(
                                                LinearGradient(
                                                    colors: [.green, .mint],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .foregroundStyle(.white)
                                            .cornerRadius(12)
                                            .shadow(color: .green.opacity(0.6), radius: 5)
                                    }
                                } else {
                                    // If already completed
                                    VStack(spacing: 8) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 36))
                                            .foregroundStyle(.green)
                                        
                                        Text("Completed!")
                                            .font(.title3.bold())
                                            .foregroundStyle(.green)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(12)
                                }
                                
                                // Edit task button
                                Button(action: {
                                    showingEditView = true
                                }) {
                                    Label("Edit Task", systemImage: "pencil")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(.ultraThinMaterial)
                                        .foregroundStyle(task.color)
                                        .cornerRadius(12)
                                }
                                
                                // Delete task button
                                Button(action: {
                                    withAnimation {
                                        modelContext.delete(task)
                                        dismiss()
                                    }
                                }) {
                                    Label("Delete Task", systemImage: "trash")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(.ultraThinMaterial)
                                        .foregroundStyle(.red)
                                        .cornerRadius(12)
                                }
                                
                                // Test button for Accountability Agent (for demo purposes)
                                if !task.isCompleted && task.title.lowercased().contains("run") {
                                    Button(action: {
                                        // Simulate a pattern of missed runs
                                        simulateMissedRunPattern(for: task)
                                        
                                        // Show a confirmation
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                    }) {
                                        Label("Test Accountability Agent", systemImage: "brain.head.profile")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(.ultraThinMaterial)
                                            .foregroundStyle(.purple)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                    }
                    .overlay {
                        // Coin reward overlay
                        if showingCoinReward {
                            VStack {
                                HStack {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .font(.title)
                                        .foregroundStyle(.yellow)
                                    
                                    Text("+\(coinRewardAmount)")
                                        .font(.title.bold())
                                        .foregroundStyle(.yellow)
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(15)
                                .scaleEffect(coinScale)
                                .shadow(color: .yellow.opacity(0.6), radius: 10)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.4))
                            .transition(.opacity)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(task.color)
                }
            }
            .onAppear {
                // Add a small delay before showing content to ensure smooth transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    checkIfOverdue()
                    withAnimation(.easeIn(duration: 0.3)) {
                        isLoading = false
                    }
                }
            }
            .sheet(isPresented: $showingEditView, onDismiss: {
                // Re-check overdue status when returning from edit
                checkIfOverdue()
            }) {
                EditTaskView(task: task)
            }
            .sheet(isPresented: $showingVerification) {
                TaskVerificationView(task: task)
            }
        }
    }
    
    // Check if task is overdue
    private func checkIfOverdue() {
        // Check if task is overdue (due date is before current date)
        let isNowOverdue = !task.isCompleted && task.dueDate < Date()
        
        // Only trigger animation if the status is changing to overdue
        if isNowOverdue && !isOverdue {
            withAnimation {
                showingOverdueAnimation = true
            }
        } else if !isNowOverdue && isOverdue {
            // Task is no longer overdue (date was changed to future)
            withAnimation {
                showingOverdueAnimation = false
            }
        }
        
        // Update overdue status
        isOverdue = isNowOverdue
    }
    
    // Task status color based on state
    private var statusColor: Color {
        if task.isCompleted {
            return .green
        } else if isOverdue {
            return .red
        } else {
            return task.color
        }
    }
    
    // Task status icon based on state
    private var statusIcon: String {
        if task.isCompleted {
            return "checkmark.circle.fill"
        } else if isOverdue {
            return "exclamationmark.circle.fill"
        } else {
            return "hourglass"
        }
    }
    
    // Show coin reward
    private func showCoinReward(amount: Int) {
        coinRewardAmount = amount
        showingCoinReward = true
        
        // Animate the coin
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            coinScale = 2.0
        }
        
        // Hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                showingCoinReward = false
                coinScale = 1.0
            }
        }
    }
    
    // Simulate a pattern of missed runs for testing the Accountability Agent
    private func simulateMissedRunPattern(for task: Task) {
        // Create a few fake records of missed morning runs
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day, .hour], from: task.dueDate)
        
        // Make sure the hour is set to morning (8 AM)
        dateComponents.hour = 8
        
        guard let morningDate = calendar.date(from: dateComponents) else { return }
        
        // Create 3 missed task records at 8 AM
        for dayOffset in [-3, -2, -1] {
            guard let pastDate = calendar.date(byAdding: .day, value: dayOffset, to: morningDate) else { continue }
            
            let record = AccountabilityAgent.TaskCompletionRecord(
                taskTitle: task.title,
                taskCategory: task.categoryValue,
                scheduledTime: pastDate,
                wasCompleted: false,
                recordDate: Date().addingTimeInterval(Double(dayOffset * 86400))
            )
            
            // Add to history
            var history = AccountabilityAgent.shared.getTaskCompletionHistory()
            history.append(record)
            
            // Save updated history
            if let encoded = try? JSONEncoder().encode(history) {
                UserDefaults.standard.set(encoded, forKey: "TaskCompletionHistory")
            }
        }
        
        // Create 2 successful afternoon completions
        dateComponents.hour = 17 // 5 PM
        guard let afternoonDate = calendar.date(from: dateComponents) else { return }
        
        for dayOffset in [-6, -4] {
            guard let pastDate = calendar.date(byAdding: .day, value: dayOffset, to: afternoonDate) else { continue }
            
            let record = AccountabilityAgent.TaskCompletionRecord(
                taskTitle: task.title,
                taskCategory: task.categoryValue,
                scheduledTime: pastDate,
                wasCompleted: true,
                recordDate: Date().addingTimeInterval(Double(dayOffset * 86400))
            )
            
            // Add to history
            var history = AccountabilityAgent.shared.getTaskCompletionHistory()
            history.append(record)
            
            // Save updated history
            if let encoded = try? JSONEncoder().encode(history) {
                UserDefaults.standard.set(encoded, forKey: "TaskCompletionHistory")
            }
        }
        
        // Trigger the analysis
        AccountabilityAgent.shared.analyzeTaskPatterns()
    }
}

// Task edit view
struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: Task
    
    @State private var title: String
    @State private var dueDate: Date
    @State private var selectedPriority: TaskPriority
    @State private var selectedCategory: TaskCategory
    @State private var taskColor: Color
    @State private var notes: String
    @State private var activeTab = 0
    @State private var showingColorPicker = false
    @State private var requiresVerification: Bool
    
    init(task: Task) {
        self.task = task
        _title = State(initialValue: task.title)
        _dueDate = State(initialValue: task.dueDate)
        _selectedPriority = State(initialValue: task.priority)
        _selectedCategory = State(initialValue: task.category)
        _taskColor = State(initialValue: task.color)
        _notes = State(initialValue: task.notes)
        _requiresVerification = State(initialValue: task.requiresVerification)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.black, taskColor.opacity(0.3), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Content
                VStack(spacing: 0) {
                    // Tab selector
                    HStack(spacing: 0) {
                        tabButton(title: "Details", index: 0)
                        tabButton(title: "Category", index: 1)
                        tabButton(title: "Priority", index: 2)
                        tabButton(title: "Style", index: 3)
                    }
                    .background(Color.black.opacity(0.6))
                    
                    // Tab content
                    TabView(selection: $activeTab) {
                        basicDetailsTab
                            .tag(0)
                        
                        categoryTab
                            .tag(1)
                        
                        priorityTab
                            .tag(2)
                        
                        styleTab
                            .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: activeTab)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.cyan)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateTask()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                    .foregroundStyle(title.isEmpty ? .gray : .cyan)
                }
            }
        }
    }
    
    // Tab button
    private func tabButton(title: String, index: Int) -> some View {
        Button(action: {
            activeTab = index
        }) {
            Text(title)
                .font(.subheadline)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .foregroundStyle(activeTab == index ? taskColor : .gray)
        }
        .background(
            activeTab == index ?
            LinearGradient(colors: [taskColor.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom) : nil
        )
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundStyle(activeTab == index ? taskColor : .clear)
                .padding(.top, 30),
            alignment: .bottom
        )
    }
    
    // Basic details tab
    private var basicDetailsTab: some View {
        Form {
            Section {
                TextField("Task Title", text: $title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    .foregroundStyle(.white)
                    .tint(taskColor)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .cornerRadius(8)
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.black.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Toggle(isOn: $requiresVerification) {
                    Label("Require Photo Verification", systemImage: "camera.viewfinder")
                        .foregroundStyle(.white)
                }
                .tint(taskColor)
            }
            .listRowBackground(Color.black.opacity(0.6))
        }
        .scrollContentBackground(.hidden)
    }
    
    // Category tab
    private var categoryTab: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(TaskCategory.allCases) { category in
                    categoryButton(category: category)
                }
            }
            .padding()
        }
        .background(Color.black.opacity(0.6))
    }
    
    private func categoryButton(category: TaskCategory) -> some View {
        Button(action: {
            selectedCategory = category
        }) {
            VStack(spacing: 12) {
                Text(category.emoji)
                    .font(.system(size: 40))
                
                Text(category.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                
                if selectedCategory == category {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(taskColor)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedCategory == category ? category.color : .clear, lineWidth: 2)
                    )
            )
        }
    }
    
    // Priority tab
    private var priorityTab: some View {
        VStack(spacing: 24) {
            ForEach(TaskPriority.allCases) { priority in
                priorityButton(priority: priority)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.6))
    }
    
    private func priorityButton(priority: TaskPriority) -> some View {
        Button(action: {
            selectedPriority = priority
        }) {
            HStack(spacing: 15) {
                Image(systemName: priority.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(priority.color)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(priority.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(priorityDescription(priority))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if selectedPriority == priority {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(taskColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedPriority == priority ? priority.color : .clear, lineWidth: 2)
                    )
            )
        }
    }
    
    private func priorityDescription(_ priority: TaskPriority) -> String {
        switch priority {
        case .low:
            return "Can wait if needed"
        case .medium:
            return "Should be done soon"
        case .high:
            return "Urgent and important"
        }
    }
    
    // Style tab
    private var styleTab: some View {
        VStack(spacing: 30) {
            // Color preview
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(taskColor)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: taskColor.opacity(0.6), radius: 10)
                
                Text(title.isEmpty ? "Task Preview" : title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)
            
            // Color picker
            VStack {
                Text("Choose a color")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.bottom, 5)
                
                // Preset colors
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 15) {
                    colorButton(color: .cyan, name: "Cyan")
                    colorButton(color: .purple, name: "Purple")
                    colorButton(color: .pink, name: "Pink")
                    colorButton(color: .green, name: "Green")
                    colorButton(color: .orange, name: "Orange")
                    colorButton(color: .blue, name: "Blue")
                    colorButton(color: .yellow, name: "Yellow")
                    colorButton(color: .red, name: "Red")
                    colorButton(color: .mint, name: "Mint")
                    colorButton(color: .indigo, name: "Indigo")
                }
                .padding(.horizontal)
                
                // Custom color button
                Button(action: { showingColorPicker = true }) {
                    Text("Custom Color")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .sheet(isPresented: $showingColorPicker) {
                    ColorPicker("Select a color", selection: $taskColor)
                        .presentationDetents([.medium])
                        .presentationBackground(.ultraThinMaterial)
                }
            }
            
            Spacer()
        }
        .padding(.top)
        .background(Color.black.opacity(0.6))
    }
    
    private func colorButton(color: Color, name: String) -> some View {
        Button(action: {
            taskColor = color
        }) {
            VStack {
                Circle()
                    .fill(color)
                    .frame(width: 35, height: 35)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        Circle()
                            .stroke(taskColor == color ? .white : .clear, lineWidth: 2)
                    )
                    .shadow(color: color.opacity(0.6), radius: 3)
                
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // Update task with new values
    private func updateTask() {
        task.title = title
        task.dueDate = dueDate
        task.priority = selectedPriority
        task.category = selectedCategory
        task.color = taskColor
        task.notes = notes
        task.requiresVerification = requiresVerification
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)
    
    let task = Task(title: "Complete the app", dueDate: Date())
    
    return TaskView(task: task, onStartFocusQuest: {})
        .modelContainer(container)
} 