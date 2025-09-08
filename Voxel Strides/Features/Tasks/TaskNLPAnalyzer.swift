//
//  TaskNLPAnalyzer.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/17/25.
//

import Foundation
import NaturalLanguage
import CoreML

class TaskNLPAnalyzer {
    static let shared = TaskNLPAnalyzer()
    
    // Cache for task analyses to avoid redundant processing
    private var taskAnalysisCache: [String: [String: Any]] = [:]
    
    private init() {}
    
    // MARK: - Task Analysis
    
    // Analyze task to extract key information
    func analyzeTask(_ task: Task) -> [String: Any] {
        // Check cache first
        let cacheKey = task.id.uuidString
        if let cachedAnalysis = taskAnalysisCache[cacheKey] {
            return cachedAnalysis
        }
        
        var analysis = [String: Any]()
        
        // Extract keywords from title and notes
        let titleKeywords = extractKeywords(from: task.title)
        let notesKeywords = extractKeywords(from: task.notes)
        let allKeywords = Array(Set(titleKeywords + notesKeywords)) // Remove duplicates
        
        analysis["titleKeywords"] = titleKeywords
        analysis["notesKeywords"] = notesKeywords
        analysis["allKeywords"] = allKeywords
        
        // Determine if this is a removal/cleaning task
        let isRemovalTask = titleKeywords.contains { keyword in
            ["remove", "clean", "clear", "empty", "declutter", "organize"].contains(keyword)
        }
        
        analysis["isRemovalTask"] = isRemovalTask
        
        // Determine if this is an exercise/gym task
        let isExerciseTask = titleKeywords.contains { keyword in
            ["exercise", "workout", "gym", "fitness", "train", "run", "lift", "cardio", "strength"].contains(keyword)
        } || task.category == .exercise
        
        analysis["isExerciseTask"] = isExerciseTask
        
        // Determine task type and expected objects/scenes
        let (taskType, expectedObjects, expectedScenes) = determineTaskContext(task)
        
        analysis["taskType"] = taskType
        analysis["expectedObjects"] = expectedObjects
        analysis["expectedScenes"] = expectedScenes
        
        // For removal tasks, also track what should be removed
        if isRemovalTask {
            var itemsToRemove = [String]()
            
            // Look for items mentioned after "remove", "clean", etc.
            if task.title.lowercased().contains("remove") {
                let components = task.title.lowercased().components(separatedBy: "remove")
                if components.count > 1 {
                    let afterRemove = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let potentialItems = extractKeywords(from: afterRemove)
                    itemsToRemove.append(contentsOf: potentialItems)
                }
            }
            
            // If no specific items found, use general clutter words
            if itemsToRemove.isEmpty {
                itemsToRemove = ["items", "clutter", "stuff", "objects", "things"]
            }
            
            analysis["itemsToRemove"] = itemsToRemove
        }
        
        // For exercise tasks, track exercise type and equipment
        if isExerciseTask {
            var exerciseTypes = [String]()
            var exerciseEquipment = [String]()
            
            // Common exercise types
            let exerciseTypeKeywords = ["cardio", "strength", "weight", "run", "jog", "walk", "lift", "train", 
                                       "yoga", "pilates", "stretch", "hiit", "circuit", "aerobic", "anaerobic"]
            
            // Common exercise equipment
            let equipmentKeywords = ["treadmill", "bike", "machine", "weight", "dumbbell", "barbell", "bench", 
                                    "rack", "mat", "ball", "band", "rope", "kettlebell", "elliptical", "rower"]
            
            // Check for exercise types in task text
            for keyword in allKeywords {
                if exerciseTypeKeywords.contains(where: { keyword.contains($0) }) {
                    exerciseTypes.append(keyword)
                }
                
                if equipmentKeywords.contains(where: { keyword.contains($0) }) {
                    exerciseEquipment.append(keyword)
                }
            }
            
            // If no specific exercise types found, use general exercise words
            if exerciseTypes.isEmpty {
                exerciseTypes = ["workout", "exercise", "fitness"]
            }
            
            analysis["exerciseTypes"] = exerciseTypes
            analysis["exerciseEquipment"] = exerciseEquipment
        }
        
        // Extract entities (names, locations, etc.)
        let entities = extractEntities(from: task.title + " " + task.notes)
        analysis["entities"] = entities
        
        // Determine key action verbs
        let actionVerbs = extractActionVerbs(from: task.title + " " + task.notes)
        analysis["actionVerbs"] = actionVerbs
        
        // Determine task difficulty
        let difficulty = estimateTaskDifficulty(task)
        analysis["difficulty"] = difficulty
        
        // Cache the analysis
        taskAnalysisCache[cacheKey] = analysis
        
        return analysis
    }
    
    // MARK: - Keyword Extraction
    
    // Extract keywords from text using NL tagger
    func extractKeywords(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text
        
        var keywords = [String]()
        
        // Get all nouns, verbs, and adjectives
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            if let tag = tag, (tag == .noun || tag == .verb || tag == .adjective) {
                let word = String(text[tokenRange]).lowercased()
                if word.count > 2 && !self.isStopWord(word) {
                    keywords.append(word)
                }
            }
            return true
        }
        
        return keywords
    }
    
    // Extract named entities from text
    func extractEntities(from text: String) -> [String: [String]] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var entities: [String: [String]] = [
            "persons": [],
            "locations": [],
            "organizations": [],
            "other": []
        ]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            if let tag = tag {
                let entity = String(text[tokenRange])
                
                switch tag {
                case .personalName:
                    entities["persons"]?.append(entity)
                case .placeName:
                    entities["locations"]?.append(entity)
                case .organizationName:
                    entities["organizations"]?.append(entity)
                default:
                    if tag != .otherWord && !self.isStopWord(entity.lowercased()) {
                        entities["other"]?.append(entity)
                    }
                }
            }
            return true
        }
        
        return entities
    }
    
    // Extract action verbs from text
    func extractActionVerbs(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var actionVerbs = [String]()
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            if let tag = tag, tag == .verb {
                let verb = String(text[tokenRange]).lowercased()
                if verb.count > 2 && !self.isStopWord(verb) {
                    actionVerbs.append(verb)
                }
            }
            return true
        }
        
        return actionVerbs
    }
    
    // MARK: - Task Context Analysis
    
    // Determine task context based on category and keywords
    func determineTaskContext(_ task: Task) -> (type: String, expectedObjects: [String], expectedScenes: [String]) {
        var taskType = "general"
        var expectedObjects = [String]()
        var expectedScenes = [String]()
        
        // Base context on task category
        switch task.category {
        case .home:
            taskType = "cleaning"
            expectedObjects = ["clean", "tidy", "organized", "surface", "floor", "table", "desk", "vacuum", "mop", "broom", "cloth"]
            expectedScenes = ["clean space", "organized room", "tidy environment", "home"]
            
        case .exercise:
            taskType = "exercise"
            expectedObjects = ["exercise machine", "gym equipment", "weights", "fitness equipment", "workout machine", 
                              "bench", "treadmill", "exercise bike", "dumbbells", "weight rack", "fitness area", 
                              "training equipment", "shoes", "gym", "fitness", "weights", "mat", "sports", "running", "workout"]
            expectedScenes = ["gym", "fitness center", "workout area", "exercise room", "training facility", 
                             "outdoor space", "exercise area", "park", "fitness center"]
            
        case .work:
            taskType = "work"
            expectedObjects = ["computer", "desk", "papers", "workspace", "office", "laptop", "monitor", "keyboard", "documents"]
            expectedScenes = ["office", "workspace", "desk", "home office", "meeting room"]
            
        case .study:
            taskType = "study"
            expectedObjects = ["books", "notes", "computer", "desk", "study materials", "textbook", "notebook", "pen", "highlighter"]
            expectedScenes = ["study area", "desk", "library", "classroom", "quiet space"]
            
        case .health:
            taskType = "health"
            expectedObjects = ["food", "kitchen", "cooking", "meal", "dish", "plate", "utensils", "ingredients", "pan", "pot", "medicine", "health items", "medical equipment", "pills", "vitamins", "medical supplies"]
            expectedScenes = ["kitchen", "dining area", "cooking space", "countertop", "medical facility", "home", "pharmacy", "hospital", "clinic"]
            
        case .shopping:
            taskType = "shopping"
            expectedObjects = ["products", "items", "groceries", "shopping bags", "cart", "store", "goods", "purchases"]
            expectedScenes = ["store", "shopping area", "retail space", "market", "mall"]
            
        case .travel:
            taskType = "travel"
            expectedObjects = ["luggage", "tickets", "passport", "travel items", "maps", "transportation"]
            expectedScenes = ["airport", "station", "hotel", "outdoor", "travel destination"]
            
        default:
            expectedObjects = ["item", "object", "space", "area", "room"]
            expectedScenes = ["indoor", "outdoor", "space", "area"]
        }
        
        // Refine expected objects based on task title keywords
        let titleKeywords = extractKeywords(from: task.title)
        
        // Add specific objects based on keywords
        for keyword in titleKeywords {
            // Add related objects based on common keywords
            if keyword.contains("desk") || keyword.contains("table") {
                expectedObjects.append(contentsOf: ["desk", "table", "chair", "surface", "workspace"])
                expectedScenes.append(contentsOf: ["office", "workspace", "study area"])
            }
            
            if keyword.contains("clean") || keyword.contains("tidy") || keyword.contains("organize") {
                expectedObjects.append(contentsOf: ["clean surface", "organized items", "tidy space"])
                expectedScenes.append(contentsOf: ["clean room", "organized space", "tidy area"])
            }
            
            if keyword.contains("cook") || keyword.contains("bake") || keyword.contains("food") {
                expectedObjects.append(contentsOf: ["food", "kitchen items", "cooking utensils", "ingredients", "meal"])
                expectedScenes.append(contentsOf: ["kitchen", "dining area", "cooking space"])
            }
            
            if keyword.contains("exercise") || keyword.contains("workout") || keyword.contains("gym") || 
               keyword.contains("fitness") || keyword.contains("train") {
                expectedObjects.append(contentsOf: ["exercise machine", "gym equipment", "weights", "fitness equipment", 
                                                  "workout machine", "bench", "treadmill", "exercise bike", "dumbbells", 
                                                  "weight rack", "fitness area", "training equipment"])
                expectedScenes.append(contentsOf: ["gym", "fitness center", "workout area", "exercise room", 
                                                 "training facility", "outdoor space", "exercise area"])
            }
            
            if keyword.contains("run") || keyword.contains("jog") || keyword.contains("walk") {
                expectedObjects.append(contentsOf: ["running shoes", "track", "treadmill", "path", "road"])
                expectedScenes.append(contentsOf: ["outdoor", "park", "gym", "track", "road"])
            }
            
            if keyword.contains("weight") || keyword.contains("lift") || keyword.contains("strength") {
                expectedObjects.append(contentsOf: ["weights", "dumbbells", "barbell", "weight machine", "bench", "rack"])
                expectedScenes.append(contentsOf: ["gym", "weight room", "fitness center"])
            }
        }
        
        // Remove duplicates
        expectedObjects = Array(Set(expectedObjects))
        expectedScenes = Array(Set(expectedScenes))
        
        return (taskType, expectedObjects, expectedScenes)
    }
    
    // Estimate task difficulty based on various factors
    func estimateTaskDifficulty(_ task: Task) -> String {
        // Start with a base difficulty based on priority
        var difficultyScore = 0
        
        switch task.priority {
        case .high:
            difficultyScore += 3
        case .medium:
            difficultyScore += 2
        case .low:
            difficultyScore += 1
        }
        
        // Add points based on task category
        switch task.category {
        case .work, .study:
            difficultyScore += 2
        case .exercise, .health:
            difficultyScore += 1
        default:
            break
        }
        
        // Add points for longer titles (might indicate complexity)
        let titleWords = task.title.split(separator: " ").count
        if titleWords > 5 {
            difficultyScore += 1
        }
        
        // Add points for notes (might indicate additional requirements)
        if !task.notes.isEmpty {
            difficultyScore += 1
        }
        
        // Determine difficulty level
        if difficultyScore >= 6 {
            return "hard"
        } else if difficultyScore >= 3 {
            return "medium"
        } else {
            return "easy"
        }
    }
    
    // MARK: - Matching Logic
    
    // Match task requirements with image analysis
    func matchTaskWithImageAnalysis(taskAnalysis: [String: Any], imageAnalysis: [String: Any]) -> (isCompleted: Bool, confidence: Double, matchedElements: [String]) {
        // Extract keywords from task and image analyses
        let taskKeywords = taskAnalysis["allKeywords"] as? [String] ?? []
        let expectedObjects = taskAnalysis["expectedObjects"] as? [String] ?? []
        let expectedScenes = taskAnalysis["expectedScenes"] as? [String] ?? []
        let isRemovalTask = taskAnalysis["isRemovalTask"] as? Bool ?? false
        let isExerciseTask = taskAnalysis["isExerciseTask"] as? Bool ?? false
        let itemsToRemove = taskAnalysis["itemsToRemove"] as? [String] ?? []
        let exerciseTypes = taskAnalysis["exerciseTypes"] as? [String] ?? []
        let exerciseEquipment = taskAnalysis["exerciseEquipment"] as? [String] ?? []
        
        let imageObjects = imageAnalysis["objects"] as? [String] ?? []
        let imageScenes = imageAnalysis["scenes"] as? [String] ?? []
        let imageText = imageAnalysis["text"] as? [String] ?? []
        
        // Combine all image elements for matching
        let allImageElements = imageObjects + imageScenes + imageText
        
        // Track matched elements
        var matchedElements = [String]()
        var totalMatches = 0.0
        var possibleMatches = Double(taskKeywords.count + expectedObjects.count + expectedScenes.count)
        
        // Ensure we have at least some possible matches
        possibleMatches = max(possibleMatches, 1)
        
        if isRemovalTask {
            // For removal tasks, we need to check if items that should be removed are NOT present
            
            // Check if the scene is described as "clean", "empty", "organized", etc.
            let cleanSceneIndicators = ["clean", "empty", "tidy", "organized", "clear", "neat"]
            let hasCleanScene = imageScenes.contains { scene in
                cleanSceneIndicators.contains { scene.lowercased().contains($0) }
            }
            
            // Check for clutter indicators
            let clutterIndicators = ["cluttered", "messy", "disorganized", "many items"]
            let hasClutter = allImageElements.contains { element in
                clutterIndicators.contains { element.lowercased().contains($0) }
            }
            
            if hasCleanScene {
                totalMatches += 2.0 // Give higher weight to clean scene detection
                matchedElements.append("clean environment")
            }
            
            if hasClutter {
                totalMatches -= 2.0 // Penalize clutter detection
                matchedElements.append("cluttered environment")
            }
            
            // Check if there are few or no items detected
            let fewItemsIndicators = ["few items", "no items", "empty", "clean space", "clean surface"]
            let hasFewItems = imageObjects.contains { object in
                fewItemsIndicators.contains { object.lowercased().contains($0) }
            }
            
            if hasFewItems {
                totalMatches += 2.0
                matchedElements.append("few or no items")
            }
            
            // Check for specific items that should be removed
            var specificItemsFound = [String]()
            var specificItemsRemoved = [String]()
            
            // Common desk items to check for
            let commonDeskItems = ["paper", "book", "pen", "pencil", "notebook", "laptop", "computer", 
                                  "mouse", "keyboard", "cup", "mug", "bottle", "phone", "document", 
                                  "folder", "stapler", "tape", "scissors", "calculator", "charger"]
            
            // Check for common desk items in the image
            for item in commonDeskItems {
                let itemFound = allImageElements.contains { element in
                    element.lowercased().contains(item.lowercased())
                }
                
                if itemFound {
                    specificItemsFound.append(item)
                } else {
                    specificItemsRemoved.append(item)
                }
            }
            
            // Check if the specific items to remove are NOT found
            var itemsFound = 0
            for item in itemsToRemove {
                let itemFound = allImageElements.contains { element in
                    element.lowercased().contains(item.lowercased())
                }
                
                if !itemFound {
                    // Item not found is good for removal tasks
                    totalMatches += 0.5
                    matchedElements.append("\(item) removed")
                } else {
                    itemsFound += 1
                    specificItemsFound.append(item)
                }
            }
            
            // If most items to remove are not found, that's a good sign
            if itemsFound <= itemsToRemove.count / 3 {
                totalMatches += 1.0
                matchedElements.append("most items removed")
            }
            
            // Check for "desk" or "surface" being detected (the clean area)
            let surfaceDetected = imageObjects.contains { object in
                ["desk", "table", "surface", "countertop", "workspace"].contains { object.lowercased().contains($0) }
            }
            
            if surfaceDetected {
                totalMatches += 1.0
                matchedElements.append("surface visible")
            }
            
            // Check for image complexity (lower is better for clean desk)
            if let complexity = imageAnalysis["complexity"] as? Double {
                if complexity < 0.3 {
                    totalMatches += 1.5
                    matchedElements.append("low visual complexity")
                } else if complexity > 0.7 {
                    totalMatches -= 1.0
                    matchedElements.append("high visual complexity")
                }
            }
            
            // Add information about specific items found/removed for better feedback
            if !specificItemsFound.isEmpty {
                matchedElements.append("items still present: \(specificItemsFound.prefix(3).joined(separator: ", "))")
            }
            
            if !specificItemsRemoved.isEmpty {
                matchedElements.append("items not detected: \(specificItemsRemoved.prefix(3).joined(separator: ", "))")
            }
            
        } else if isExerciseTask {
            // For exercise tasks, we need to check for gym environment and equipment
            
            // Check if the scene is described as a gym or fitness area
            let gymSceneIndicators = ["gym", "fitness", "workout", "exercise", "training"]
            let hasGymScene = imageScenes.contains { scene in
                gymSceneIndicators.contains { scene.lowercased().contains($0) }
            }
            
            if hasGymScene {
                totalMatches += 2.0 // Give higher weight to gym scene detection
                matchedElements.append("gym environment")
            }
            
            // Check for exercise equipment
            let equipmentIndicators = ["machine", "treadmill", "weight", "bench", "equipment", "bike", "dumbbell", "barbell"]
            var detectedEquipment = [String]()
            
            for indicator in equipmentIndicators {
                let found = allImageElements.contains { element in
                    element.lowercased().contains(indicator)
                }
                
                if found {
                    detectedEquipment.append(indicator)
                }
            }
            
            // Add matches for detected equipment
            for equipment in detectedEquipment {
                totalMatches += 0.5
                matchedElements.append("\(equipment) detected")
            }
            
            // Check for specific exercise types mentioned in the task
            for exerciseType in exerciseTypes {
                let found = allImageElements.contains { element in
                    element.lowercased().contains(exerciseType.lowercased())
                }
                
                if found {
                    totalMatches += 1.0
                    matchedElements.append("\(exerciseType) activity")
                }
            }
            
            // Check for specific equipment mentioned in the task
            for equipment in exerciseEquipment {
                let found = allImageElements.contains { element in
                    element.lowercased().contains(equipment.lowercased())
                }
                
                if found {
                    totalMatches += 1.0
                    matchedElements.append("\(equipment) present")
                }
            }
            
            // Check for person in exercise position
            let hasPersonExercising = imageObjects.contains { object in
                ["person", "people", "man", "woman", "athlete", "trainer"].contains { object.lowercased().contains($0) }
            }
            
            if hasPersonExercising {
                totalMatches += 1.0
                matchedElements.append("person exercising")
            }
            
        } else {
            // Standard matching for non-specialized tasks
            
            // Match task keywords with image elements
            for keyword in taskKeywords {
                if allImageElements.contains(where: { self.wordsMatch($0, keyword) }) {
                    totalMatches += 1.0
                    matchedElements.append(keyword)
                }
            }
            
            // Match expected objects
            for object in expectedObjects {
                if imageObjects.contains(where: { self.wordsMatch($0, object) }) {
                    totalMatches += 0.5 // Lower weight for generic expected objects
                    matchedElements.append(object)
                }
            }
            
            // Match expected scenes
            for scene in expectedScenes {
                if imageScenes.contains(where: { self.wordsMatch($0, scene) }) {
                    totalMatches += 0.5 // Lower weight for generic expected scenes
                    matchedElements.append(scene)
                }
            }
        }
        
        // Calculate confidence score
        let confidence = min(1.0, totalMatches / possibleMatches)
        
        // Determine if task is completed based on confidence threshold
        let isCompleted = confidence > 0.3 // Threshold for considering task completed
        
        return (isCompleted, confidence, matchedElements)
    }
    
    // Check if two words match (including partial matches)
    private func wordsMatch(_ word1: String, _ word2: String) -> Bool {
        let w1 = word1.lowercased()
        let w2 = word2.lowercased()
        
        return w1.contains(w2) || w2.contains(w1) || 
               levenshteinDistance(w1, w2) <= min(2, min(w1.count, w2.count) / 3)
    }
    
    // Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        
        var dist = [[Int]]()
        for i in 0...a.count {
            dist.append([Int](repeating: 0, count: b.count + 1))
            dist[i][0] = i
        }
        
        for j in 0...b.count {
            dist[0][j] = j
        }
        
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    dist[i][j] = dist[i-1][j-1]
                } else {
                    dist[i][j] = min(
                        dist[i-1][j] + 1,      // deletion
                        dist[i][j-1] + 1,      // insertion
                        dist[i-1][j-1] + 1     // substitution
                    )
                }
            }
        }
        
        return dist[a.count][b.count]
    }
    
    // Check if a word is a common stop word
    private func isStopWord(_ word: String) -> Bool {
        let stopWords = ["the", "and", "a", "an", "in", "on", "at", "to", "for", "with", "by", "about", 
                        "like", "through", "over", "before", "between", "after", "from", "up", "down", 
                        "out", "off", "again", "further", "then", "once", "here", "there", "when", 
                        "where", "why", "how", "all", "any", "both", "each", "few", "more", "most", 
                        "other", "some", "such", "no", "nor", "not", "only", "own", "same", "so", 
                        "than", "too", "very", "can", "will", "just", "should", "now", "also", "get", 
                        "got", "make", "made", "put", "set", "this", "that", "these", "those", "was", 
                        "were", "has", "have", "had", "been", "being", "do", "does", "did", "done", 
                        "doing", "go", "goes", "going", "went", "gone"]
        
        return stopWords.contains(word.lowercased())
    }
    
    // Generate feedback based on match result
    func generateFeedback(task: Task, matchResult: (isCompleted: Bool, confidence: Double, matchedElements: [String])) -> String {
        let isCompleted = matchResult.isCompleted
        let confidence = matchResult.confidence
        let matchedElements = matchResult.matchedElements
        
        // Check if this is a removal task
        let isRemovalTask = task.title.lowercased().contains { char in
            ["remove", "clean", "clear", "empty", "declutter", "organize"].contains(String(char))
        }
        
        // Check if this is an exercise task
        let isExerciseTask = task.title.lowercased().contains { char in
            ["exercise", "workout", "gym", "fitness", "train", "run", "lift", "cardio", "strength"].contains(String(char))
        } || task.category == .exercise
        
        if isRemovalTask {
            // Extract specific items information from matched elements
            let itemsStillPresent = matchedElements.first(where: { $0.starts(with: "items still present:") })?.replacingOccurrences(of: "items still present: ", with: "") ?? ""
            
            if isCompleted {
                if confidence > 0.8 {
                    return "Excellent job! The desk is completely clear. I can see that you've successfully removed all items from the desk."
                } else if confidence > 0.6 {
                    return "Great job! The desk looks clean with most items removed. I can see \(matchedElements.prefix(2).joined(separator: ", "))."
                } else {
                    return "Task appears to be mostly completed. The desk looks relatively clear, though there might still be a few small items."
                }
            } else {
                if confidence > 0.4 {
                    return "I can see some progress, but the desk isn't completely clear yet. " + 
                           (itemsStillPresent.isEmpty ? "There are still some items that need to be removed." : 
                                                      "I can still see \(itemsStillPresent) that need to be removed.")
                } else if confidence > 0.2 {
                    return "You've made a start, but there are still quite a few items on the desk. " + 
                           (itemsStillPresent.isEmpty ? "" : "Items like \(itemsStillPresent) are still visible.")
                } else {
                    return "The desk still appears to have many items on it. Please remove more items and take another photo when the desk is clearer."
                }
            }
        } else if isExerciseTask {
            // Feedback for exercise tasks
            if isCompleted {
                if confidence > 0.8 {
                    return "Great workout! I can see you're at the gym with \(matchedElements.prefix(2).joined(separator: ", ")). Keep up the good work!"
                } else if confidence > 0.6 {
                    return "Good job with your exercise routine! I can see \(matchedElements.prefix(2).joined(separator: ", "))."
                } else {
                    return "It looks like you're exercising, though the image doesn't show all the details of your workout."
                }
            } else {
                if confidence > 0.2 {
                    return "I can see some signs of exercise activity with \(matchedElements.joined(separator: ", ")), but not enough to verify your complete workout."
                } else {
                    return "I don't see clear evidence of a workout in this image. Please take a photo that shows you exercising or at the gym."
                }
            }
        } else {
            // Standard feedback for non-specialized tasks
            if isCompleted {
                if confidence > 0.7 {
                    return "Great job! The image clearly shows that you've completed the task '\(task.title)'. I can see \(matchedElements.prefix(3).joined(separator: ", "))."
                } else {
                    return "Task appears to be completed. I can see evidence of \(matchedElements.joined(separator: ", ")) in the image."
                }
            } else {
                if confidence > 0 {
                    return "I can see some progress on your task, but it doesn't appear to be fully completed. I found \(matchedElements.joined(separator: ", ")) but more evidence is needed."
                } else {
                    return "I don't see evidence that the task '\(task.title)' has been completed. Please provide a clearer image of your completed task."
                }
            }
        }
    }
} 