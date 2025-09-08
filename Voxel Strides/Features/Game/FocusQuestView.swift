//
//  FocusQuestView.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import SwiftUI
import SwiftData
import Combine

struct FocusQuestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    
    @Bindable var task: Task
    
    // Timer settings
    @State private var selectedDuration: TimerDuration = .short
    @State private var timeRemaining: Int = 0
    @State private var isRunning = false
    @State private var particleOpacity: Double = 0
    @State private var showingDurationPicker = true
    
    // Collectible states
    @State private var newlyUnlockedCollectible: Collectible?
    @State private var showingCollectibleSheet = false
    
    // Timer publisher and cancellable
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var cancellables = Set<AnyCancellable>()
    
    // Allow dismissal flag
    @State private var allowDismissal = true
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.black, .indigo.opacity(0.5), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Glowing ring effect
            Circle()
                .stroke(lineWidth: 2)
                .fill(
                    RadialGradient(
                        colors: [.cyan.opacity(0.8), .cyan.opacity(0.2), .clear],
                        center: .center,
                        startRadius: 80,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .blur(radius: 10)
            
            // Particle effect when timer is low
            ZStack {
                ForEach(0..<20) { i in
                    Circle()
                        .fill(.cyan.opacity(Double.random(in: 0.1...0.3)))
                        .frame(width: Double.random(in: 4...8), height: Double.random(in: 4...8))
                        .offset(x: CGFloat.random(in: -100...100), y: CGFloat.random(in: -100...100))
                        .blur(radius: 2)
                }
            }
            .opacity(particleOpacity)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: particleOpacity)
            
            // Content
            VStack(spacing: 30) {
                Text("Focus Quest")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .shadow(color: .cyan.opacity(0.7), radius: 10)
                
                Text(task.title)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundStyle(.white)
                
                if showingDurationPicker {
                    // Duration selection
                    durationPickerView
                } else {
                    // Timer view
                    timerView
                }
            }
            .padding()
            .onAppear {
                // Check for saved timer when view appears
                checkForSavedTimer()
                
                // Start particle effect
                withAnimation {
                    particleOpacity = 0.7
                }
            }
            .onDisappear {
                if allowDismissal {
                    cancelTimer()
                }
            }
            .interactiveDismissDisabled(!allowDismissal)
        }
        .onChange(of: timeRemaining) { _, newValue in
            // Increase glow effect when timer is low
            if newValue <= 3 && isRunning {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            
            // Save current timer state
            if isRunning {
                saveTimerState()
            }
            
            // Check if timer completed
            if newValue <= 0 && isRunning {
                completeTask()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // App became active, check for saved timer
                checkForSavedTimer()
            } else if newPhase == .background {
                // App going to background, save state
                saveTimerState()
            }
        }
        .sheet(isPresented: $showingCollectibleSheet, onDismiss: {
            // Dismiss the main view after collectible sheet is closed
            allowDismissal = true
            cancelTimer()
            dismiss()
        }) {
            if let collectible = newlyUnlockedCollectible {
                CollectibleUnlockedView(collectible: collectible, isPresented: $showingCollectibleSheet)
            }
        }
        .onReceive(timer) { _ in
            guard isRunning else { return }
            
            if timeRemaining > 0 {
                timeRemaining -= 1
            }
        }
    }
    
    // Duration picker view
    private var durationPickerView: some View {
        VStack(spacing: 20) {
            Text("Choose Focus Duration")
                .font(.headline)
                .foregroundStyle(.white)
            
            VStack(spacing: 15) {
                ForEach(TimerDuration.allCases) { duration in
                    Button(action: {
                        selectedDuration = duration
                    }) {
                        HStack {
                            Image(systemName: duration.icon)
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text(duration.name)
                                    .font(.headline)
                                
                                Text(duration.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedDuration == duration {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.cyan)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedDuration == duration ? .cyan : .clear, lineWidth: 2)
                                )
                        )
                    }
                    .foregroundStyle(.white)
                }
            }
            
            Button(action: {
                // Set the time based on selection
                timeRemaining = selectedDuration.seconds
                showingDurationPicker = false
                allowDismissal = false
                startTimer()
            }) {
                Text("Start Focus")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.cyan)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.top)
        }
    }
    
    // Timer view
    private var timerView: some View {
        VStack {
            ZStack {
                // Background circle
                Circle()
                    .stroke(lineWidth: 20)
                    .opacity(0.2)
                    .foregroundStyle(.cyan)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(1 - Float(timeRemaining) / Float(selectedDuration.seconds)))
                    .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: timeRemaining)
                
                // Time text
                Text(timeString(time: timeRemaining))
                    .font(.system(size: 70, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .cyan.opacity(0.7), radius: timeRemaining < 3 ? 15 : 5)
            }
            .padding(40)
            
            // Control buttons
            HStack(spacing: 20) {
                // Stop button
                Button(action: {
                    allowDismissal = true
                    cancelTimer()
                    dismiss()
                }) {
                    Label("Stop", systemImage: "stop.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                // Minimize button
                Button(action: {
                    dismiss()
                }) {
                    Label("Minimize", systemImage: "arrow.down.right.and.arrow.up.left")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(.top)
        }
    }
    
    private func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func startTimer() {
        // Cancel any existing timer
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        isRunning = true
        
        // Save timer state
        saveTimerState()
    }
    
    private func cancelTimer() {
        timer.upstream.connect().cancel()
        isRunning = false
        clearSavedTimer()
    }
    
    private func completeTask() {
        withAnimation {
            task.isCompleted = true
        }
        
        // Play celebration sound when task is completed
        MusicManager.shared.playSound(.levelUp)
        
        // Update completed focus sessions count
        let currentCount = UserDefaults.standard.integer(forKey: "CompletedFocusSessions")
        let newCount = currentCount + 1
        UserDefaults.standard.set(newCount, forKey: "CompletedFocusSessions")
        
        // Clear saved timer
        clearSavedTimer()
        
        // Set notification for AR celebration
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowARCelebration"),
            object: nil,
            userInfo: ["taskId": task.id.uuidString]
        )
        
        // Check if a collectible should be unlocked
        if let collectible = CollectibleManager.items.first(where: { $0.requiredLevel == newCount }) {
            newlyUnlockedCollectible = collectible
            showingCollectibleSheet = true
        } else {
            // If no collectible, dismiss normally
            allowDismissal = true
            cancelTimer()
            dismiss()
        }
    }
    
    // Save current timer state using PersistenceManager
    private func saveTimerState() {
        if isRunning && timeRemaining > 0 {
            PersistenceManager.shared.saveFocusQuestState(
                taskId: task.id.uuidString,
                timeRemaining: timeRemaining,
                duration: selectedDuration.seconds,
                isRunning: isRunning
            )
        } else {
            clearSavedTimer()
        }
    }
    
    // Clear saved timer data
    private func clearSavedTimer() {
        PersistenceManager.shared.clearFocusQuestState()
    }
    
    // Check for a saved timer and restore it
    private func checkForSavedTimer() {
        // First check if there's a saved timer for this specific task
        if PersistenceManager.shared.hasActiveFocusQuest && 
           PersistenceManager.shared.activeTaskId == task.id.uuidString {
            
            // Calculate adjusted time remaining
            let adjustedTimeRemaining = PersistenceManager.shared.calculateAdjustedTimeRemaining()
            
            if adjustedTimeRemaining > 0 {
                // Restore timer state
                timeRemaining = adjustedTimeRemaining
                selectedDuration = TimerDuration(rawValue: PersistenceManager.shared.activeTaskDuration) ?? .short
                showingDurationPicker = false
                allowDismissal = false
                startTimer()
            } else {
                // Timer would have completed while app was closed
                completeTask()
            }
        }
    }
}

// Timer duration options
enum TimerDuration: Int, CaseIterable, Identifiable {
    case demo = 10
    case short = 300  // 5 minutes
    case medium = 900  // 15 minutes
    case long = 1500  // 25 minutes
    case extended = 3000  // 50 minutes
    
    var id: Int { self.rawValue }
    
    var name: String {
        switch self {
        case .demo: return "Demo (10s)"
        case .short: return "Short (5 min)"
        case .medium: return "Medium (15 min)"
        case .long: return "Standard (25 min)"
        case .extended: return "Extended (50 min)"
        }
    }
    
    var description: String {
        switch self {
        case .demo: return "Quick test of the focus timer"
        case .short: return "For small, quick tasks"
        case .medium: return "For medium-sized tasks"
        case .long: return "Standard pomodoro duration"
        case .extended: return "For deep work sessions"
        }
    }
    
    var icon: String {
        switch self {
        case .demo: return "bolt"
        case .short: return "hare"
        case .medium: return "clock"
        case .long: return "timer"
        case .extended: return "tortoise"
        }
    }
    
    var seconds: Int {
        return self.rawValue
    }
}

#Preview {
    FocusQuestView(task: Task(title: "Complete Demo", dueDate: Date()))
        .modelContainer(for: Task.self, inMemory: true)
} 