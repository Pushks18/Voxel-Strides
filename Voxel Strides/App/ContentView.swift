//
//  ContentView.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import SwiftUI
import SwiftData
import AVFoundation
import ARKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Task.dueDate) private var tasks: [Task]
    @State private var showingAddTask = false
    @State private var showingFocusQuest = false
    @State private var showingTaskDetail = false
    @State private var selectedTask: Task?
    @State private var showingARView = false
    @State private var completedTaskCount = 0
    @State private var showingLadderAnimation = false
    @State private var showingGamePath = false
    @State private var showingVerification = false
    @State private var isLoadingTask = false
    
    // For checking active focus quest
    @State private var checkingForActiveFocusQuest = true
    
    // Add this environment variable to watch the app's state
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // Neon background
            LinearGradient(
                colors: [.black, .indigo.opacity(0.4), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Main content
            TabView {
                // Tasks tab
                tasksView
                    .tabItem {
                        Label("Tasks", systemImage: "checklist")
                    }
                    .onAppear {
                        MusicManager.shared.playSound(.select)
                    }
                
                // Progress tab with Duolingo-style path
                progressView
                    .tabItem {
                        Label("Journey", systemImage: "map")
                    }
                    .onAppear {
                        MusicManager.shared.playSound(.select)
                    }
                
                // Store tab
                StoreView()
                    .tabItem {
                        Label("Store", systemImage: "bag.fill")
                    }
                    .onAppear {
                        MusicManager.shared.playSound(.select)
                    }
                
                // Collectibles tab
                CollectiblesView()
                    .tabItem {
                        Label("Collection", systemImage: "trophy.fill")
                    }
                    .onAppear {
                        MusicManager.shared.playSound(.select)
                    }
            }
            .tint(.cyan)
            .safeAreaInset(edge: .bottom) {
                // Add a small invisible spacer to ensure content doesn't get hidden behind the tab bar
                Color.clear.frame(height: 0)
            }
            
            // Ladder animation overlay when advancing
            if showingLadderAnimation {
                VStack {
                    Image(systemName: "ladder")
                        .font(.system(size: 80))
                        .foregroundStyle(.cyan)
                        .shadow(color: .cyan.opacity(0.8), radius: 10)
                    
                    Text("Level Up!")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                        .shadow(color: .cyan.opacity(0.8), radius: 5)
                }
                .transition(.scale.combined(with: .opacity))
                .zIndex(2)
            }

            // Milestone celebration overlay
            if showingMilestone {
                VStack(spacing: 15) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.8), radius: 10)
                    
                    Text("Milestone Reached!")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                        .shadow(color: .yellow.opacity(0.8), radius: 5)
                    
                    Text(milestoneMessage)
                        .font(.title3)
                        .foregroundStyle(.white)
                    
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.title)
                            .foregroundStyle(.yellow)
                        
                        Text("+\(milestoneCoins)")
                            .font(.title.bold())
                            .foregroundStyle(.yellow)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(15)
                }
                .padding(30)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(radius: 20)
                .transition(.scale.combined(with: .opacity))
                .zIndex(3)
            }
        }
        .onAppear {
            // Reset all app data for a fresh start
            resetAppData()
            
            // Set task count to 0
            completedTaskCount = 0
            
            // Request music authorization when app starts
            MusicManager.shared.requestMusicAuthorization()
            
            // Check for active focus quest
            checkForActiveFocusQuest()
            
            // Request notification permissions and schedule notifications for tasks
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.scheduleTaskNotifications()
                    }
                }
            }
            
            // Add observer for AR celebration notification
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowARCelebration"),
                object: nil,
                queue: .main
            ) { notification in
                // Get task ID from notification
                if let taskId = notification.userInfo?["taskId"] as? String,
                   let uuid = UUID(uuidString: taskId),
                   let task = self.tasks.first(where: { $0.id == uuid }) {
                    self.selectedTask = task
                    
                    // Show ladder animation first
                    withAnimation(.spring) {
                        self.showingLadderAnimation = true
                    }
                    
                    // Then show AR view after delay
                    if ARWorldTrackingConfiguration.isSupported {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.showingARView = true
                            self.showingLadderAnimation = false
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.showingLadderAnimation = false
                        }
                    }
                }
            }
        }
        .onChange(of: tasks) {
            updateCompletedTaskCount()
            scheduleTaskNotifications()
        }
        // Add this modifier to trigger the accountability check when the app becomes active
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                print("App became active. Agent is checking for overdue tasks...")
                checkAccountability()
                
                // Also reschedule notifications for any new or modified tasks
                scheduleTaskNotifications()
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(isPresented: $showingAddTask)
        }
        .sheet(isPresented: $showingFocusQuest, onDismiss: {
            if let task = selectedTask, task.isCompleted {
                // Show celebration and update ladder progress
                withAnimation(.spring) {
                    showingLadderAnimation = true
                    completedTaskCount += 1
                    
                    // Play level up sound
                    MusicManager.shared.playSound(.levelUp)
                }
                
                // Only show AR view if supported
                if ARWorldTrackingConfiguration.isSupported {
                    // Show AR view after brief delay to see ladder animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showingARView = true
                        showingLadderAnimation = false
                    }
                } else {
                    // Just hide the ladder animation after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showingLadderAnimation = false
                    }
                }
            }
        }) {
            if let task = selectedTask {
                FocusQuestView(task: task)
            }
        }
        .sheet(isPresented: $showingARView) {
            if ARWorldTrackingConfiguration.isSupported {
                if let task = selectedTask {
                    ARCompanionView(isTaskOverdue: task.dueDate < Date() && !task.isCompleted)
                } else {
                    ARCompanionView()
                }
            } else {
                // Fallback view when AR is not available
                VStack(spacing: 20) {
                    Text("AR Not Available")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text("Your device doesn't support AR features.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Button("Close") {
                        showingARView = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [.black, .indigo.opacity(0.4), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .sheet(isPresented: $showingTaskDetail, onDismiss: {
            // Reset selected task when dismissing
            if !showingFocusQuest {
                selectedTask = nil
            }
        }) {
            if let task = selectedTask {
                TaskView(task: task, onStartFocusQuest: {
                    showingTaskDetail = false
                    // Small delay to ensure proper transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingFocusQuest = true
                    }
                })
            } else {
                // Fallback loading view
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                    Text("Loading task...")
                        .foregroundStyle(.secondary)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [.black, .indigo.opacity(0.4), .black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                )
            }
        }
        .sheet(isPresented: $showingVerification) {
            if let task = selectedTask {
                TaskVerificationView(task: task)
            }
        }
    }
    
    // Check for active focus quest
    private func checkForActiveFocusQuest() {
        // Check if there's an active focus quest
        if PersistenceManager.shared.hasActiveFocusQuest,
           let taskId = PersistenceManager.shared.activeTaskId,
           let uuid = UUID(uuidString: taskId),
           let task = AccountabilityAgent.shared.findTask(withId: uuid) {
            
            // Set the selected task and show the focus quest
            selectedTask = task
            
            // Use a small delay to ensure the view is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingFocusQuest = true
            }
        }
        
        checkingForActiveFocusQuest = false
    }
    
    // Add the accountability check function
    private func checkAccountability() {
        // Check if we have any overdue tasks
        let overdueTasks = tasks.filter { !$0.isCompleted && $0.dueDate < Date() }
        
        if !overdueTasks.isEmpty {
            // For demo purposes, we'll focus on exercise tasks
            let exerciseTasks = overdueTasks.filter { $0.category == .exercise }
            
            if let exerciseTask = exerciseTasks.first {
                // We found an overdue exercise task, schedule a notification
                scheduleAccountabilityNotification(for: exerciseTask)
            } else if let firstOverdueTask = overdueTasks.first {
                // If no exercise tasks, use the first overdue task
                scheduleAccountabilityNotification(for: firstOverdueTask)
            }
        }
    }
    
    // Schedule the accountability notification
    private func scheduleAccountabilityNotification(for task: Task) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                let content = UNMutableNotificationContent()
                content.title = "Voxel Strides Accountability"
                content.subtitle = "A little help from your companion!"
                content.body = "I noticed we missed our '\(task.title)' quest. Should we try again this afternoon?"
                content.sound = UNNotificationSound.default
                
                // Add category for actions
                content.categoryIdentifier = "RESCHEDULE_CATEGORY"
                
                // Add the task ID to the notification
                content.userInfo = [
                    "taskId": task.id.uuidString,
                    "suggestedTime": Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!.timeIntervalSince1970
                ]
                
                // Show notification in 5 seconds for the demo
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                
                // Create and add the request
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                
                // Set up notification categories with actions
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
                
                // Add the notification request
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Error scheduling notification: \(error)")
                    } else {
                        print("SUCCESS: Proactive notification scheduled automatically!")
                    }
                }
            } else if let error = error {
                print("Notification permissions denied: \(error.localizedDescription)")
            }
        }
    }
    
    // Schedule notifications for upcoming tasks
    private func scheduleTaskNotifications() {
        // First, remove any existing notifications for tasks
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Get all incomplete tasks
        let incompleteTasks = tasks.filter { !$0.isCompleted }
        
        for task in incompleteTasks {
            // Skip tasks that are already overdue
            if task.dueDate < Date() {
                continue
            }
            
            // Schedule a notification for when the task becomes due
            let content = UNMutableNotificationContent()
            content.title = "Task Due: \(task.title)"
            content.body = "Your task is now due. Don't forget to complete it!"
            content.sound = UNNotificationSound.default
            content.categoryIdentifier = "TASK_DUE"
            
            // Create a calendar trigger for the exact due date
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: task.dueDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            // Create the notification request
            let request = UNNotificationRequest(
                identifier: "task-due-\(task.id.uuidString)",
                content: content,
                trigger: trigger
            )
            
            // Add the notification request
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling task notification: \(error)")
                } else {
                    print("Scheduled notification for task: \(task.title) at \(task.dueDate)")
                }
            }
            
            // Also schedule an overdue notification for 1 minute after the due date
            let overdueContent = UNMutableNotificationContent()
            overdueContent.title = "Missed Task: \(task.title)"
            overdueContent.subtitle = "A little help from your companion!"
            overdueContent.body = "I noticed we missed our '\(task.title)' quest. Should we try again this afternoon?"
            overdueContent.sound = UNNotificationSound.default
            overdueContent.categoryIdentifier = "RESCHEDULE_CATEGORY"
            overdueContent.userInfo = [
                "taskId": task.id.uuidString,
                "suggestedTime": Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!.timeIntervalSince1970
            ]
            
            // Create a calendar trigger for 1 minute after the due date
            var overdueDate = task.dueDate
            overdueDate = Calendar.current.date(byAdding: .minute, value: 1, to: overdueDate)!
            let overdueComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: overdueDate)
            let overdueTrigger = UNCalendarNotificationTrigger(dateMatching: overdueComponents, repeats: false)
            
            // Create the notification request
            let overdueRequest = UNNotificationRequest(
                identifier: "task-overdue-\(task.id.uuidString)",
                content: overdueContent,
                trigger: overdueTrigger
            )
            
            // Add the notification request
            UNUserNotificationCenter.current().add(overdueRequest) { error in
                if let error = error {
                    print("Error scheduling overdue notification: \(error)")
                } else {
                    print("Scheduled overdue notification for task: \(task.title) at \(overdueDate)")
                }
            }
        }
    }
    
    // Tasks view (first tab)
    private var tasksView: some View {
        NavigationStack {
            ZStack {
                // App content
                VStack {
                    // App logo/header
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .foregroundStyle(.cyan)
                            .shadow(color: .cyan.opacity(0.6), radius: 5)
                        
                        Text("Voxel Strides")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        // Verification button
                        Button(action: {
                            if let firstTask = tasks.first(where: { !$0.isCompleted }) {
                                selectedTask = firstTask
                                showingVerification = true
                            }
                        }) {
                            Image(systemName: "camera.viewfinder")
                                .foregroundStyle(.cyan)
                        }
                        .disabled(tasks.filter({ !$0.isCompleted }).isEmpty)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Task summary
                    HStack(spacing: 30) {
                        taskStatView(
                            count: tasks.filter { !$0.isCompleted }.count,
                            title: "Pending",
                            color: .cyan
                        )
                        
                        taskStatView(
                            count: tasks.filter { !$0.isCompleted && $0.dueDate < Date() }.count,
                            title: "Overdue",
                            color: .red
                        )
                        
                        taskStatView(
                            count: tasks.filter { $0.isCompleted }.count,
                            title: "Completed",
                            color: .green
                        )
                    }
                    .padding(.vertical, 10)
                    
                    if tasks.isEmpty {
                        Spacer()
                        emptyStateView
                        Spacer()
                    } else {
                        taskListView
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Label("Add Task", systemImage: "plus")
                            .foregroundStyle(.cyan)
                    }
                }
            }
        }
    }
    
    // Function to add a demo task
    private func addDemoTask() {
        let demoTask = Task(
            title: "Demo Task",
            dueDate: Date().addingTimeInterval(3600), // Due in 1 hour
            priority: .medium,
            category: .other,
            color: .cyan,
            notes: "This is a demo task for demonstration purposes"
        )
        
        modelContext.insert(demoTask)
        
        // Play notification sound
        MusicManager.shared.playSound(.notification)
    }

    // Function to add an overdue task for the accountability agent demo
    private func addOverdueTask() {
        let overdueTask = Task(
            title: "Overdue Demo Task",
            dueDate: Date().addingTimeInterval(-3600), // Overdue by 1 hour
            priority: .high,
            category: .exercise,
            color: .red,
            notes: "This task is overdue for the accountability agent demo."
        )
        
        modelContext.insert(overdueTask)
        
        // Play notification sound
        MusicManager.shared.playSound(.notification)
    }
    
    // Function to add a focus quest task
    private func addFocusQuestTask() {
        // Keep this function as it's still used by the "Start Focus Quest" button in demo controls
        let focusQuestTask = Task(
            title: "Focus Quest",
            dueDate: Date().addingTimeInterval(300), // Due in 5 minutes
            priority: .high,
            category: .exercise,
            color: .cyan,
            notes: "Complete this quest to earn coins and advance in the game."
        )
        
        modelContext.insert(focusQuestTask)
        
        // Select this task and start focus quest immediately
        selectedTask = focusQuestTask
        
        // Start focus quest after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingFocusQuest = true
        }
        
        // Play notification sound
        MusicManager.shared.playSound(.notification)
    }
    
    // Task statistics view
    private func taskStatView(count: Int, title: String, color: Color) -> some View {
        VStack {
            Text("\(count)")
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
    
    // Progress view with Duolingo-style path (second tab)
    private var progressView: some View {
        NavigationStack {
            ZStack {
                // Game path in the background
                GamePathView(completedTasks: completedTaskCount)
                    .padding()
                    .zIndex(1)
                
                // Task stats at the bottom with higher z-index to ensure visibility
                VStack {
                    Spacer()
                    
                    HStack(spacing: 20) {
                        statsBox(
                            icon: "checkmark.circle.fill", 
                            value: "\(completedTaskCount)",
                            label: "Completed"
                        )
                        
                        statsBox(
                            icon: "dollarsign.circle.fill", 
                            value: "\(CoinManager.shared.coins)",
                            label: "Coins"
                        )
                        
                        statsBox(
                            icon: "star.fill", 
                            value: "\(calculateCurrentLevel())",
                            label: "Levels"
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.3), radius: 10)
                    )
                    .cornerRadius(15)
                    .padding(.horizontal)
                    .padding(.bottom, 20) // Add extra padding at the bottom
                }
                .zIndex(2) // Ensure stats are above the game path
            }
            .navigationTitle("Your Progress")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                // Add a small invisible spacer to ensure content doesn't get hidden behind the tab bar
                Color.clear.frame(height: 10)
            }
        }
    }
    
    // Calculate current level based on completed tasks
    private func calculateCurrentLevel() -> Int {
        // Every 3 completed tasks = 1 level
        return max(1, completedTaskCount / 3)
    }
    
    private func statsBox(icon: String, value: String, label: String) -> some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.cyan)
            
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 80)
        .padding(.vertical, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.clipboard")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundStyle(.cyan)
                .shadow(color: .cyan.opacity(0.6), radius: 10)
            
            Text("No tasks yet")
                .font(.title2)
                .foregroundStyle(.primary)
            
            Text("Tap the + button to add your first task")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingAddTask = true }) {
                Label("Add Your First Task", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .shadow(color: .cyan.opacity(0.6), radius: 5)
            .padding(.top)
        }
        .padding()
    }
    
    @State private var showingMilestone = false
    @State private var milestoneMessage = ""
    @State private var milestoneCoins = 0

    private func showMilestoneCelebration(taskCount: Int, coinReward: Int) {
        milestoneMessage = "You've completed \(taskCount) tasks!"
        milestoneCoins = coinReward
        
        // Play celebration sound
        MusicManager.shared.playSound(.newNotification)
        
        withAnimation {
            showingMilestone = true
        }
        
        // Hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showingMilestone = false
            }
        }
    }

    // Function to reset all app data
    private func resetAppData() {
        // Clear all data in SwiftData
        let fetchDescriptor = FetchDescriptor<Task>()
        let fetchResult = try? modelContext.fetch(fetchDescriptor)
        if let tasks = fetchResult {
            for task in tasks {
                modelContext.delete(task)
            }
        }
        
        // Reset task count
        completedTaskCount = 0
        
        // Clear all data in UserDefaults
        UserDefaults.standard.removeObject(forKey: "CompletedTaskCount")
        UserDefaults.standard.removeObject(forKey: "CompletedFocusSessions")
        
        // Clear task completion records
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            if key.starts(with: "TaskCompletion_") || key.starts(with: "TaskOverdue_") {
                defaults.removeObject(forKey: key)
            }
        }
        
        // Reset coin manager
        CoinManager.shared.resetCoins()
        
        // Reset collectibles data
        CollectibleManager.shared.resetPurchases()
        
        // Reset focus quest data
        PersistenceManager.shared.clearFocusQuestState()
        
        // Reset accountability agent
        AccountabilityAgent.shared.reset()
        
        // Reset music manager
        MusicManager.shared.reset()
        
        // Reset game path data
        GamePathView.resetData()
        
        // Reset collectibles view data
        CollectiblesView.resetData()
        
        // Reset store view data
        StoreView.resetData()
        
        // Reset notification permissions
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        print("App data reset successfully.")
    }

    private var taskListView: some View {
        List {
            Section("Upcoming Tasks") {
                ForEach(getUpcomingTasks()) { task in
                    TaskRowView(
                        task: task, 
                        onStartFocusQuest: {
                            selectedTask = task
                            showingFocusQuest = true
                        },
                        onTap: {
                            selectedTask = task
                            showingTaskDetail = true
                        }
                    )
                }
                .onDelete(perform: deleteTasks)
            }
            
            if !tasks.filter({ $0.isCompleted }).isEmpty {
                Section("Completed") {
                    ForEach(tasks.filter { $0.isCompleted }) { task in
                        TaskRowView(
                            task: task, 
                            onStartFocusQuest: {
                                // Can't start focus quest on completed task
                            },
                            onTap: {
                                selectedTask = task
                                showingTaskDetail = true
                            }
                        )
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.black.opacity(0.6))
                    }
                }
            }
            
            // Add spacer section at the bottom to prevent tab bar overlap
            Section {
                Color.clear
                    .frame(height: 50)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
    }

    // Helper method to get sorted upcoming tasks
    private func getUpcomingTasks() -> [Task] {
        let currentDate = Date()
        
        return tasks.filter { !$0.isCompleted }
            .sorted { task1, task2 in
                // First sort by overdue status
                let task1Overdue = Calendar.current.compare(task1.dueDate, to: currentDate, toGranularity: .second) == .orderedAscending
                let task2Overdue = Calendar.current.compare(task2.dueDate, to: currentDate, toGranularity: .second) == .orderedAscending
                
                if task1Overdue && !task2Overdue {
                    return true // Overdue tasks first
                } else if !task1Overdue && task2Overdue {
                    return false
                } else {
                    // Then sort by priority if same overdue status
                    if task1.priorityValue != task2.priorityValue {
                        return task1.priorityValue > task2.priorityValue
                    } else {
                        // Finally sort by due date if same priority
                        return task1.dueDate < task2.dueDate
                    }
                }
        }
    }

    private func deleteTasks(offsets: IndexSet) {
        let tasksToDelete = getUpcomingTasks()
        
        withAnimation {
            for index in offsets {
                modelContext.delete(tasksToDelete[index])
            }
        }
    }
    
    // Update the task completion logic to award coins
    private func updateCompletedTaskCount() {
        let count = tasks.filter { $0.isCompleted }.count
        
        // Check if the count increased (a task was completed)
        if count > completedTaskCount {
            // Award coins for task completion
            let result = CoinManager.shared.awardCoinsForTaskCompletion(taskCount: count)
            
            // Show milestone celebration if needed
            if result.milestone {
                // Show celebration for milestone with coin reward
                showMilestoneCelebration(taskCount: count, coinReward: result.milestoneAmount)
            }
            
            // Find newly completed tasks and record them in the Accountability Agent
            let newlyCompletedTasks = tasks.filter { 
                $0.isCompleted && 
                !UserDefaults.standard.bool(forKey: "TaskCompletion_\($0.id.uuidString)")
            }
            
            for task in newlyCompletedTasks {
                // Record the task completion
                AccountabilityAgent.shared.recordTaskCompletion(task: task, wasCompleted: true)
                
                // Mark this task as recorded to avoid duplicate records
                UserDefaults.standard.set(true, forKey: "TaskCompletion_\(task.id.uuidString)")
            }
        }
        
        // Check for overdue tasks that haven't been recorded yet
        let now = Date()
        let overdueTasks = tasks.filter {
            !$0.isCompleted && 
            $0.dueDate < now && 
            !UserDefaults.standard.bool(forKey: "TaskOverdue_\($0.id.uuidString)")
        }
        
        for task in overdueTasks {
            // Record the task failure
            AccountabilityAgent.shared.recordTaskCompletion(task: task, wasCompleted: false)
            
            // Mark this task as recorded to avoid duplicate records
            UserDefaults.standard.set(true, forKey: "TaskOverdue_\(task.id.uuidString)")
        }
        
        completedTaskCount = count
        
        // Also save to UserDefaults to persist across app restarts
        UserDefaults.standard.set(count, forKey: "CompletedTaskCount")
        
        // Make sure focus sessions count is at least as high as completed tasks
        let focusSessions = UserDefaults.standard.integer(forKey: "CompletedFocusSessions")
        if count > focusSessions {
            UserDefaults.standard.set(count, forKey: "CompletedFocusSessions")
        }
    }
}

struct TaskRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task
    var onStartFocusQuest: () -> Void
    var onTap: () -> Void
    @State private var showingVerification = false
    
    // Fix the isOverdue calculation
    private var isOverdue: Bool {
        // A task is overdue if it's not completed and the due date is in the past
        let currentDate = Date()
        let taskDueDate = task.dueDate
        
        // Use calendar comparison to ensure proper date handling
        return !task.isCompleted && Calendar.current.compare(taskDueDate, to: currentDate, toGranularity: .second) == .orderedAscending
    }
    
    var body: some View {
        HStack {
            // Category emoji
            Text(task.category.emoji)
                .font(.title2)
                .frame(width: 40)
                .padding(.trailing, 5)
            
            VStack(alignment: .leading, spacing: 4) {
                // Title with priority indicator
                titleView
                
                // Metadata row
                metadataView
                
                // Overdue indicator
                if isOverdue && !task.isCompleted {
                    Text("Overdue")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
                
                // Verification status
                if task.requiresVerification && !task.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.caption2)
                        Text("Requires photo verification")
                            .font(.caption2)
                    }
                    .foregroundStyle(.cyan)
                }
                
                // Verification feedback if available
                if !task.verificationFeedback.isEmpty {
                    Text(task.verificationFeedback)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Action buttons
            if !task.isCompleted {
                actionButtons
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            // Ensure task is properly loaded before opening detail view
            withAnimation {
                onTap()
            }
        }
        .listRowBackground(rowBackground)
        .sheet(isPresented: $showingVerification) {
            TaskVerificationView(task: task)
        }
    }
    
    // Title with priority indicator
    private var titleView: some View {
        HStack {
            // Priority indicator
            Circle()
                .fill(task.priority.color)
                .frame(width: 8, height: 8)
            
            Text(task.title)
                .font(.headline)
                .strikethrough(task.isCompleted)
                .foregroundColor(task.isCompleted ? .secondary : isOverdue ? .red : .primary)
        }
    }
    
    // Metadata row with due date, priority, category
    private var metadataView: some View {
        HStack(spacing: 10) {
            // Due date
            Text(task.dueDate, format: Date.FormatStyle(date: .numeric, time: .shortened))
                .font(.caption)
                .foregroundColor(isOverdue ? .red : .secondary)
            
            // Priority label
            if !task.isCompleted {
                priorityLabel
            }
            
            // Category tag
            categoryTag
        }
    }
    
    // Priority label
    private var priorityLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: task.priority.icon)
                .font(.caption2)
            Text(task.priority.name)
                .font(.caption2)
        }
        .foregroundStyle(task.priority.color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(task.priority.color.opacity(0.1))
        )
    }
    
    // Category tag
    private var categoryTag: some View {
        HStack(spacing: 3) {
            Text(task.category.rawValue)
                .font(.caption2)
        }
        .foregroundStyle(task.category.color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(task.category.color.opacity(0.1))
        )
    }
    
    // Action buttons
    private var actionButtons: some View {
        HStack {
            Button(action: {
                onStartFocusQuest()
            }) {
                Label("Start Focus", systemImage: "timer")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .tint(isOverdue ? .orange : task.color)
            
            Button(action: {
                if task.requiresVerification {
                    // Show verification view
                    showingVerification = true
                } else {
                    // Mark as completed directly
                    withAnimation {
                        task.isCompleted = true
                        
                        // Play celebration sound when completing a task
                        MusicManager.shared.playSound(.success)
                    }
                }
            }) {
                Label("Complete", systemImage: task.requiresVerification ? "camera.viewfinder" : "checkmark.circle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .tint(.green)
        }
    }
    
    // Row background
    private var rowBackground: Color {
        if task.isCompleted {
            return Color.black.opacity(0.6)
        } else if isOverdue {
            return Color.red.opacity(0.15)
        } else {
            return task.color.opacity(0.15)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Task.self, inMemory: true)
}
