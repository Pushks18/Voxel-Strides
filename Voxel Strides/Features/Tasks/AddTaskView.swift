//
//  AddTaskView.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    
    // Basic task properties
    @State private var title = ""
    @State private var dueDate = Date()
    
    // New task properties
    @State private var selectedPriority = TaskPriority.medium
    @State private var selectedCategory = TaskCategory.other
    @State private var taskColor = Color.cyan
    @State private var notes = ""
    @State private var requiresVerification = true
    
    // UI states
    @State private var showingColorPicker = false
    @State private var activeTab = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.black, .indigo.opacity(0.5), .black],
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
            .navigationTitle("Add New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundStyle(.cyan)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTask()
                        isPresented = false
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
                .foregroundStyle(activeTab == index ? .cyan : .gray)
        }
        .background(
            activeTab == index ?
            LinearGradient(colors: [.cyan.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom) : nil
        )
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundStyle(activeTab == index ? .cyan : .clear)
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
                    .tint(.cyan)
                
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
                .tint(.cyan)
            }
            .listRowBackground(Color.black.opacity(0.6))
            
            Section {
                agentButton
            }
            .listRowBackground(Color.black.opacity(0.6))
        }
        .scrollContentBackground(.hidden)
    }

    // Agent planning button
    private var agentButton: some View {
        Button(action: {
            // Run the async planning function in a Swift Concurrency Task
            _Concurrency.Task { // <--- CORRECTED
                await planWithAgent()
            }
        }) {
            HStack {
                Image(systemName: "wand.and.stars")
                Text("Plan with Agent")
            }
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .foregroundStyle(title.isEmpty ? .gray : .cyan) // This was missing in your original snippet, I've re-added it
        .disabled(title.isEmpty)
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
                        .foregroundStyle(.cyan)
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
                        .foregroundStyle(.cyan)
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
        case .high: return "For very important, time-sensitive tasks."
        case .medium: return "For regular tasks that need attention."
        case .low: return "For minor tasks or long-term goals."
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
    
    // Add task to database
    private func addTask() {
        let newTask = Task(
            title: title,
            dueDate: dueDate,
            priority: selectedPriority,
            category: selectedCategory,
            color: taskColor,
            notes: notes,
            isCompleted: false,
            requiresVerification: requiresVerification
        )
        
        modelContext.insert(newTask)
        
        // Play notification sound
        MusicManager.shared.playSound(.notification)
    }

    // Use the agent to generate and add tasks
    private func planWithAgent() async {
        let agent = PlanningAgent()
        do {
            let subTasks = try await agent.generatePlan(for: title)
            
            // If the agent returns a plan, add the tasks
            if !subTasks.isEmpty {
                for task in subTasks {
                    modelContext.insert(task)
                }
            } else {
                // If the agent doesn't have a plan, just add the original task
                addTask()
            }
        } catch {
            print("Error generating plan: \(error)")
            // On error, just add the original task as a fallback
            addTask()
        }
        
        isPresented = false
    }
}

//#Preview {
//    AddTaskView(isPresented: .constant(true))
//        .modelContainer(for: Task.self, inMemory: true)
//} 
 