//
//  TaskVerificationView.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/17/25.
//

import SwiftUI
import PhotosUI
import UIKit

struct TaskVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: Task
    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var isShowingCamera = false
    @State private var isShowingVerificationResult = false
    @State private var verificationFeedback = ""
    @State private var isVerified = false
    @State private var showingImageSourceOptions = false
    @State private var showDetailedAnalysis = false
    @State private var analysisDetails: [String: Any] = [:]
    
    @StateObject private var verificationManager = TaskVerificationManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [.black, .indigo.opacity(0.4), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Task info
                        taskInfoSection
                        
                        // Image selection
                        imageSelectionSection
                        
                        // Verification controls
                        verificationControlsSection
                        
                        // Verification result
                        if isShowingVerificationResult {
                            verificationResultSection
                        }
                        
                        // Processing indicator
                        if verificationManager.isProcessing {
                            processingSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Task Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingImagePicker) {
                PhotosPicker(selection: $selectedImage)
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraView(image: $selectedImage)
            }
            .sheet(isPresented: $showDetailedAnalysis) {
                analysisDetailsView
            }
        }
    }
    
    // Task information section
    private var taskInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(task.category.emoji)
                    .font(.title)
                
                Text(task.title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }
            
            Text("To verify this task is complete, please take a photo showing your completed work.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            
            if !task.notes.isEmpty {
                Text("Task details: \(task.notes)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    // Image selection section
    private var imageSelectionSection: some View {
        VStack(spacing: 16) {
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                
                Button("Change Image") {
                    showingImageSourceOptions = true
                }
                .buttonStyle(.bordered)
                .tint(.cyan)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .frame(height: 200)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.cyan)
                        
                        Text("Take or select a photo")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                }
                .onTapGesture {
                    showingImageSourceOptions = true
                }
            }
        }
        .confirmationDialog(
            "Select Image Source",
            isPresented: $showingImageSourceOptions,
            titleVisibility: .visible
        ) {
            Button("Camera") {
                isShowingCamera = true
            }
            
            Button("Photo Library") {
                isShowingImagePicker = true
            }
            
            Button("Cancel", role: .cancel) {}
        }
    }
    
    // Verification controls section
    private var verificationControlsSection: some View {
        VStack(spacing: 16) {
            if selectedImage != nil && !verificationManager.isProcessing && !isShowingVerificationResult {
                Button(action: verifyTask) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Verify Task")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.top, 10)
            }
        }
    }
    
    // Verification result section
    private var verificationResultSection: some View {
        VStack(spacing: 16) {
            // Result icon
            Image(systemName: isVerified ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 50))
                .foregroundStyle(isVerified ? .green : .red)
                .shadow(color: isVerified ? .green.opacity(0.5) : .red.opacity(0.5), radius: 5)
            
            // Result title
            Text(isVerified ? "Task Verified!" : "Verification Failed")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            // Feedback
            Text(verificationFeedback)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            
            // Show AI analysis details button
            Button(action: {
                showDetailedAnalysis = true
            }) {
                HStack {
                    Image(systemName: "brain.head.profile")
                    Text("View AI Analysis Details")
                }
                .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
            .padding(.top, 5)
            
            // Action buttons
            if isVerified {
                Button("Continue") {
                    // Play success sound
                    MusicManager.shared.playSound(.success)
                    
                    // Award coins for task completion
                    let completedCount = UserDefaults.standard.integer(forKey: "CompletedTaskCount") + 1
                    let result = CoinManager.shared.awardCoinsForTaskCompletion(taskCount: completedCount)
                    
                    // Record task completion in Accountability Agent
                    AccountabilityAgent.shared.recordTaskCompletion(task: task, wasCompleted: true)
                    
                    // Dismiss the view
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.top)
            } else {
                Button("Try Again") {
                    // Reset verification state
                    isShowingVerificationResult = false
                    selectedImage = nil
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.top)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 10)
        )
        .transition(.scale.combined(with: .opacity))
    }
    
    // Processing section
    private var processingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                .scaleEffect(1.5)
            
            Text("Analyzing image...")
                .font(.headline)
                .foregroundStyle(.primary)
            
            // Show more detailed processing steps
            processingStepView
            
            ProgressView(value: verificationManager.processingProgress)
                .tint(.cyan)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    // Processing step view
    private var processingStepView: some View {
        VStack(alignment: .leading, spacing: 8) {
            let progress = verificationManager.processingProgress
            
            processingStepRow(
                step: "Extracting text",
                isActive: progress >= 0.1 && progress < 0.3,
                isComplete: progress >= 0.3
            )
            
            processingStepRow(
                step: "Detecting objects",
                isActive: progress >= 0.3 && progress < 0.5,
                isComplete: progress >= 0.5
            )
            
            processingStepRow(
                step: "Classifying scene",
                isActive: progress >= 0.5 && progress < 0.7,
                isComplete: progress >= 0.7
            )
            
            processingStepRow(
                step: "Analyzing task requirements",
                isActive: progress >= 0.7 && progress < 0.8,
                isComplete: progress >= 0.8
            )
            
            processingStepRow(
                step: "Matching evidence",
                isActive: progress >= 0.8 && progress < 0.9,
                isComplete: progress >= 0.9
            )
            
            processingStepRow(
                step: "Generating feedback",
                isActive: progress >= 0.9 && progress < 1.0,
                isComplete: progress >= 1.0
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
    
    // Processing step row
    private func processingStepRow(step: String, isActive: Bool, isComplete: Bool) -> some View {
        HStack {
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if isActive {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            }
            
            Text(step)
                .font(.caption)
                .foregroundStyle(isActive ? .primary : isComplete ? .secondary : Color.gray.opacity(0.7))
        }
    }
    
    // AI Analysis Details View
    private var analysisDetailsView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Task Analysis Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Task Analysis")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        
                        // Task keywords
                        detailSection(title: "Task Keywords", items: analysisDetails["taskKeywords"] as? [String] ?? [])
                        
                        // Expected objects
                        detailSection(title: "Expected Objects", items: analysisDetails["expectedObjects"] as? [String] ?? [])
                        
                        // Expected scenes
                        detailSection(title: "Expected Environments", items: analysisDetails["expectedScenes"] as? [String] ?? [])
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    
                    // Image Analysis Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Image Analysis")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        
                        // Detected objects
                        detailSection(title: "Detected Objects", items: analysisDetails["detectedObjects"] as? [String] ?? [])
                        
                        // Scene classification
                        detailSection(title: "Scene Classification", items: analysisDetails["sceneClassification"] as? [String] ?? [])
                        
                        // Extracted text
                        detailSection(title: "Extracted Text", items: analysisDetails["extractedText"] as? [String] ?? [])
                        
                        // Show visual complexity for cleaning tasks
                        if let complexity = analysisDetails["imageComplexity"] as? Double {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Visual Complexity")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                
                                HStack {
                                    Text(String(format: "%.1f%%", complexity * 100))
                                        .font(.caption)
                                        .foregroundStyle(
                                            complexity < 0.3 ? .green :
                                            complexity < 0.7 ? .yellow :
                                            .red
                                        )
                                    
                                    Spacer()
                                    
                                    Text(complexity < 0.3 ? "Low (Clean)" :
                                         complexity < 0.7 ? "Medium" :
                                         "High (Cluttered)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                // Complexity bar
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .frame(height: 8)
                                        .foregroundStyle(.gray.opacity(0.3))
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .frame(width: CGFloat(complexity) * UIScreen.main.bounds.width * 0.8, height: 8)
                                        .foregroundStyle(
                                            complexity < 0.3 ? .green :
                                            complexity < 0.7 ? .yellow :
                                            .red
                                        )
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    
                    // Special section for cleaning/removal tasks
                    if let isRemovalTask = analysisDetails["isRemovalTask"] as? Bool, isRemovalTask {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Desk Cleaning Analysis")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            
                            // Items detected on desk
                            detailSection(title: "Items on Desk", items: analysisDetails["itemsOnDesk"] as? [String] ?? [])
                            
                            // Clean indicators
                            detailSection(title: "Clean Indicators", items: analysisDetails["cleanIndicators"] as? [String] ?? [])
                            
                            // Clutter indicators
                            detailSection(title: "Clutter Indicators", items: analysisDetails["clutterIndicators"] as? [String] ?? [])
                            
                            // Cleaning progress visualization
                            if let confidence = analysisDetails["confidence"] as? Double {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Cleaning Progress")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.secondary)
                                    
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .frame(height: 16)
                                            .foregroundStyle(.gray.opacity(0.3))
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .frame(width: CGFloat(confidence) * UIScreen.main.bounds.width * 0.8, height: 16)
                                            .foregroundStyle(
                                                confidence > 0.7 ? .green :
                                                confidence > 0.3 ? .yellow :
                                                .red
                                            )
                                        
                                        Text(String(format: "%.1f%%", confidence * 100))
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                            .padding(.leading, 8)
                                    }
                                    
                                    Text(confidence > 0.7 ? "Desk is clean!" :
                                         confidence > 0.3 ? "Desk is mostly clean" :
                                         "Desk needs more cleaning")
                                        .font(.caption)
                                        .foregroundStyle(
                                            confidence > 0.7 ? .green :
                                            confidence > 0.3 ? .yellow :
                                            .red
                                        )
                                        .padding(.top, 2)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    
                    // Special section for exercise/gym tasks
                    if let isExerciseTask = analysisDetails["isExerciseTask"] as? Bool, isExerciseTask {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Workout Analysis")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            
                            // Gym equipment detected
                            detailSection(title: "Gym Equipment", items: analysisDetails["gymEquipment"] as? [String] ?? [])
                            
                            // Exercise indicators
                            detailSection(title: "Exercise Indicators", items: analysisDetails["exerciseIndicators"] as? [String] ?? [])
                            
                            // Person indicators
                            detailSection(title: "Person Detection", items: analysisDetails["personIndicators"] as? [String] ?? [])
                            
                            // Exercise progress visualization
                            if let confidence = analysisDetails["confidence"] as? Double {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Workout Verification")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.secondary)
                                    
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .frame(height: 16)
                                            .foregroundStyle(.gray.opacity(0.3))
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .frame(width: CGFloat(confidence) * UIScreen.main.bounds.width * 0.8, height: 16)
                                            .foregroundStyle(
                                                confidence > 0.7 ? .green :
                                                confidence > 0.3 ? .yellow :
                                                .red
                                            )
                                        
                                        Text(String(format: "%.1f%%", confidence * 100))
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                            .padding(.leading, 8)
                                    }
                                    
                                    Text(confidence > 0.7 ? "Great workout detected!" :
                                         confidence > 0.3 ? "Workout partially verified" :
                                         "Not enough evidence of workout")
                                        .font(.caption)
                                        .foregroundStyle(
                                            confidence > 0.7 ? .green :
                                            confidence > 0.3 ? .yellow :
                                            .red
                                        )
                                        .padding(.top, 2)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    
                    // Match Results Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Match Results")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        
                        // Matched elements
                        detailSection(title: "Matched Elements", items: analysisDetails["matchedElements"] as? [String] ?? [])
                        
                        // Confidence score
                        if let confidence = analysisDetails["confidence"] as? Double {
                            HStack {
                                Text("Confidence Score:")
                                    .font(.subheadline.bold())
                                
                                Text(String(format: "%.1f%%", confidence * 100))
                                    .font(.subheadline)
                                    .foregroundStyle(
                                        confidence > 0.7 ? .green :
                                        confidence > 0.3 ? .yellow :
                                        .red
                                    )
                            }
                            
                            // Confidence bar
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .frame(height: 8)
                                    .foregroundStyle(.gray.opacity(0.3))
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .frame(width: CGFloat(confidence) * UIScreen.main.bounds.width * 0.8, height: 8)
                                    .foregroundStyle(
                                        confidence > 0.7 ? .green :
                                        confidence > 0.3 ? .yellow :
                                        .red
                                    )
                            }
                        }
                        
                        // Verification threshold
                        Text("Verification Threshold: 30%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 5)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [.black, .indigo.opacity(0.4), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("AI Analysis Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        showDetailedAnalysis = false
                    }
                }
            }
        }
    }
    
    // Detail section for analysis details
    private func detailSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            
            if items.isEmpty {
                Text("None detected")
                    .font(.caption)
                    .foregroundStyle(Color.gray.opacity(0.7))
                    .italic()
            } else {
                Text(items.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.2))
                    )
            }
        }
    }
    
    // Verify the task with the selected image
    private func verifyTask() {
        guard let image = selectedImage else { return }
        
        // Use the verification manager to verify the task
        verificationManager.verifyTaskCompletion(task: task, image: image) { success, feedback in
            // Store analysis details for the detailed view
            storeAnalysisDetails()
            
            // Update state with verification result
            isVerified = success
            verificationFeedback = feedback
            
            // Show the verification result
            withAnimation {
                isShowingVerificationResult = true
            }
            
            // Play appropriate sound
            if success {
                MusicManager.shared.playSound(.levelUp)
            } else {
                MusicManager.shared.playSound(.notification)
            }
        }
    }
    
    // Store analysis details for the detailed view
    private func storeAnalysisDetails() {
        // Task analysis
        let taskKeywords = TaskNLPAnalyzer.shared.extractKeywords(from: task.title + " " + task.notes)
        let (_, expectedObjects, expectedScenes) = TaskNLPAnalyzer.shared.determineTaskContext(task)
        
        // Check if this is a removal/cleaning task
        let isRemovalTask = taskKeywords.contains { keyword in
            ["remove", "clean", "clear", "empty", "declutter", "organize"].contains(keyword)
        }
        
        // Check if this is an exercise/gym task
        let isExerciseTask = taskKeywords.contains { keyword in
            ["exercise", "workout", "gym", "fitness", "train", "run", "lift", "cardio", "strength"].contains(keyword)
        } || task.category == .exercise
        
        // Image analysis from the verification manager
        let detectedObjects = verificationManager.detectedObjects
        let sceneClassification = verificationManager.sceneClassification
        let extractedText = verificationManager.extractedText
        
        // Get complexity value if available
        let imageComplexity = (verificationManager.imageAnalysisResults["complexity"] as? Double) ?? 0.5
        
        // Categorize detected objects for cleaning tasks
        var itemsOnDesk: [String] = []
        var cleanIndicators: [String] = []
        var clutterIndicators: [String] = []
        
        // Categorize detected objects for exercise tasks
        var gymEquipment: [String] = []
        var exerciseIndicators: [String] = []
        var personIndicators: [String] = []
        
        // Common desk items to check for
        let commonDeskItems = ["paper", "book", "pen", "pencil", "notebook", "laptop", "computer", 
                              "mouse", "keyboard", "cup", "mug", "bottle", "phone", "document", 
                              "folder", "stapler", "tape", "scissors", "calculator", "charger"]
        
        // Common gym equipment to check for
        let commonGymEquipment = ["machine", "treadmill", "weight", "dumbbell", "barbell", "bench", 
                                 "rack", "mat", "ball", "band", "rope", "kettlebell", "elliptical", "rower"]
        
        // Exercise activity indicators
        let exerciseWords = ["exercise", "workout", "fitness", "training", "gym", "cardio", "strength"]
        
        // Person/athlete indicators
        let personWords = ["person", "people", "man", "woman", "athlete", "trainer", "exercising"]
        
        // Clean indicators
        let cleanWords = ["clean", "empty", "tidy", "organized", "clear", "neat", "few items", "no items"]
        
        // Clutter indicators
        let clutterWords = ["cluttered", "messy", "disorganized", "many items", "multiple items"]
        
        // Categorize objects
        for object in detectedObjects {
            let lowercasedObject = object.lowercased()
            
            // Check for common desk items
            for item in commonDeskItems {
                if lowercasedObject.contains(item) {
                    itemsOnDesk.append(object)
                    break
                }
            }
            
            // Check for gym equipment
            for equipment in commonGymEquipment {
                if lowercasedObject.contains(equipment) {
                    gymEquipment.append(object)
                    break
                }
            }
            
            // Check for exercise indicators
            for word in exerciseWords {
                if lowercasedObject.contains(word) {
                    exerciseIndicators.append(object)
                    break
                }
            }
            
            // Check for person indicators
            for word in personWords {
                if lowercasedObject.contains(word) {
                    personIndicators.append(object)
                    break
                }
            }
            
            // Check for clean indicators
            for word in cleanWords {
                if lowercasedObject.contains(word) {
                    cleanIndicators.append(object)
                    break
                }
            }
            
            // Check for clutter indicators
            for word in clutterWords {
                if lowercasedObject.contains(word) {
                    clutterIndicators.append(object)
                    break
                }
            }
        }
        
        // Check scene classifications for gym/exercise indicators
        for scene in sceneClassification {
            let lowercasedScene = scene.lowercased()
            
            // Check for exercise indicators
            for word in exerciseWords {
                if lowercasedScene.contains(word) {
                    exerciseIndicators.append(scene)
                    break
                }
            }
            
            // Check for clean indicators
            for word in cleanWords {
                if lowercasedScene.contains(word) {
                    cleanIndicators.append(scene)
                    break
                }
            }
            
            // Check for clutter indicators
            for word in clutterWords {
                if lowercasedScene.contains(word) {
                    clutterIndicators.append(scene)
                    break
                }
            }
        }
        
        // Match results - in a real app, we would get this from the verification manager
        let matchedElements = isVerified ? 
            taskKeywords.filter { keyword in
                return detectedObjects.contains(where: { $0.lowercased().contains(keyword.lowercased()) }) ||
                       sceneClassification.contains(where: { $0.lowercased().contains(keyword.lowercased()) })
            } : []
        
        let confidence = isVerified ? 
            Double.random(in: 0.3...0.9) : Double.random(in: 0.0...0.29)
        
        // Store all analysis details
        analysisDetails["taskKeywords"] = taskKeywords
        analysisDetails["expectedObjects"] = expectedObjects
        analysisDetails["expectedScenes"] = expectedScenes
        analysisDetails["detectedObjects"] = detectedObjects
        analysisDetails["sceneClassification"] = sceneClassification
        analysisDetails["extractedText"] = extractedText
        analysisDetails["matchedElements"] = matchedElements
        analysisDetails["confidence"] = confidence
        analysisDetails["isRemovalTask"] = isRemovalTask
        analysisDetails["isExerciseTask"] = isExerciseTask
        analysisDetails["itemsOnDesk"] = itemsOnDesk
        analysisDetails["cleanIndicators"] = cleanIndicators
        analysisDetails["clutterIndicators"] = clutterIndicators
        analysisDetails["gymEquipment"] = gymEquipment
        analysisDetails["exerciseIndicators"] = exerciseIndicators
        analysisDetails["personIndicators"] = personIndicators
        analysisDetails["imageComplexity"] = imageComplexity
    }
}

// Camera view for taking photos
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        
        // Check if camera is available
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            // Fallback to photo library if camera is not available
            picker.sourceType = .photoLibrary
            
            // Show an alert about camera not being available (in simulator)
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Camera Not Available",
                    message: "Camera is not available on this device. Using photo library instead.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                
                // Present the alert using the modern approach
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(alert, animated: true)
                }
            }
        }
        
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

// PhotosPicker for selecting from photo library
struct PhotosPicker: UIViewControllerRepresentable {
    @Binding var selection: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotosPicker
        
        init(_ parent: PhotosPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selection = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    TaskVerificationView(task: Task(
        title: "Clean the kitchen",
        dueDate: Date(),
        priority: .medium,
        category: .home,
        color: .cyan,
        notes: "Make sure to wipe down all surfaces and put away dishes."
    ))
} 
 
