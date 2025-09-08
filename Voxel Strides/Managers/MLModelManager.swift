//
//  MLModelManager.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/17/25.
//

import Foundation
import Vision
import CoreML
import UIKit

class MLModelManager {
    static let shared = MLModelManager()
    
    // For caching model results
    private var cachedSceneClassificationResults: [String: [VNClassificationObservation]] = [:]
    private var cachedObjectDetectionResults: [String: [VNRectangleObservation]] = [:]
    
    private init() {}
    
    // MARK: - Object Detection
    
    func detectObjects(in image: UIImage, completion: @escaping ([String], [VNRectangleObservation]?, Double) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([], nil, 0.5)
            return
        }
        
        // Calculate image complexity for clutter detection
        let imageComplexity = calculateImageComplexity(of: image)
        
        // Generate a cache key based on the image data
        let cacheKey = generateCacheKey(for: image)
        
        // Check if we have cached results
        if let cachedResults = cachedObjectDetectionResults[cacheKey] {
            // Since we're using VNRectangleObservation which doesn't have labels,
            // we need to simulate object detection based on the cached rectangles
            let objectLabels = simulateObjectDetection(from: cachedResults, in: image)
            completion(objectLabels, cachedResults, imageComplexity)
            return
        }
        
        // In a real app, we would use a trained object detection model
        // For now, we'll use a combination of Vision's built-in detection capabilities
        
        // Create a request handler
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let group = DispatchGroup()
        
        var detectedObjects = [String]()
        
        // 1. Detect rectangles (as a proxy for objects)
        group.enter()
        let rectangleRequest = VNDetectRectanglesRequest { [weak self] request, error in
            guard let self = self, error == nil else {
                group.leave()
                return
            }
            
            if let results = request.results as? [VNRectangleObservation], !results.isEmpty {
                // Cache the results
                self.cachedObjectDetectionResults[cacheKey] = results
                
                // Add rectangle-based objects
                let rectangleObjects = self.simulateObjectDetection(from: results, in: image)
                detectedObjects.append(contentsOf: rectangleObjects)
            }
            
            group.leave()
        }
        
        // Configure rectangle detection
        rectangleRequest.minimumAspectRatio = 0.2
        rectangleRequest.maximumAspectRatio = 5.0
        rectangleRequest.minimumSize = 0.05
        rectangleRequest.maximumObservations = 15
        
        // 2. Detect human bodies (for exercise detection)
        group.enter()
        let humanRequest = VNDetectHumanBodyPoseRequest { request, error in
            defer { group.leave() }
            
            guard error == nil, 
                  let observations = request.results as? [VNHumanBodyPoseObservation], 
                  !observations.isEmpty else {
                return
            }
            
            // Add human detection
            detectedObjects.append("person")
            
            // Check if the pose might be exercise-related
            for observation in observations {
                if let (poseType, confidence) = self.analyzePose(observation: observation) {
                    detectedObjects.append(poseType)
                    if confidence > 0.7 {
                        detectedObjects.append("active person")
                    }
                }
            }
        }
        
        // 3. Detect horizontal and vertical lines (for equipment)
        group.enter()
        let rectangleDetector = CIDetector(ofType: CIDetectorTypeRectangle, 
                                          context: nil, 
                                          options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        
        DispatchQueue.global(qos: .userInitiated).async {
            defer { group.leave() }
            
            let ciImage = CIImage(cgImage: cgImage)
            let features = rectangleDetector?.features(in: ciImage) ?? []
            
            if features.count > 3 {
                detectedObjects.append("equipment with frame")
                
                if features.count > 6 {
                    detectedObjects.append("complex equipment")
                    detectedObjects.append("weight machine")
                }
            }
        }
        
        // Perform the requests
        do {
            try handler.perform([rectangleRequest, humanRequest])
        } catch {
            print("Error performing Vision requests: \(error)")
        }
        
        // When all detections are complete
        group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
            guard let self = self else { return }
            
            // If we didn't detect much, try the image property analysis
            if detectedObjects.count < 3 {
                let propertyObjects = self.simulateObjectDetectionFromProperties(of: image)
                detectedObjects.append(contentsOf: propertyObjects)
            }
            
            // Add specific gym equipment detection
            let gymEquipment = self.detectSpecificGymEquipment(in: image)
            detectedObjects.append(contentsOf: gymEquipment)
            
            // Remove duplicates
            let uniqueObjects = Array(Set(detectedObjects))
            
            DispatchQueue.main.async {
                completion(uniqueObjects, nil, imageComplexity)
            }
        }
    }
    
    // Simulate object detection based on rectangle properties
    private func simulateObjectDetection(from rectangles: [VNRectangleObservation], in image: UIImage) -> [String] {
        var detectedObjects = [String]()
        
        // Count rectangles to determine clutter level
        let rectangleCount = rectangles.count
        
        // Analyze rectangle properties to infer objects
        for rectangle in rectangles {
            let width = rectangle.boundingBox.width
            let height = rectangle.boundingBox.height
            let aspectRatio = width / height
            let area = width * height
            
            // Infer object type based on properties
            if aspectRatio > 2.0 {
                detectedObjects.append("shelf")
            } else if aspectRatio < 0.5 {
                detectedObjects.append("bottle")
            } else if area > 0.4 {
                detectedObjects.append("table")
            } else if area > 0.3 && aspectRatio > 0.8 && aspectRatio < 1.2 {
                detectedObjects.append("exercise machine")
            } else if area > 0.2 && aspectRatio > 1.5 {
                detectedObjects.append("bench")
            } else if area < 0.1 && aspectRatio > 0.8 && aspectRatio < 1.2 {
                detectedObjects.append("weight")
            } else if area < 0.1 {
                detectedObjects.append("small object")
            } else {
                detectedObjects.append("item")
            }
        }
        
        // Add general objects based on rectangle count
        if rectangleCount > 8 {
            detectedObjects.append("cluttered space")
            detectedObjects.append("multiple items")
        } else if rectangleCount > 5 {
            detectedObjects.append("several items")
        } else if rectangleCount > 2 {
            detectedObjects.append("few items")
        } else if rectangleCount <= 1 {
            detectedObjects.append("clean space")
            detectedObjects.append("empty surface")
        }
        
        // Calculate density of rectangles
        let totalArea = rectangles.reduce(0.0) { $0 + ($1.boundingBox.width * $1.boundingBox.height) }
        
        if totalArea > 0.4 {
            detectedObjects.append("cluttered surface")
        } else if totalArea < 0.1 {
            detectedObjects.append("mostly empty surface")
        }
        
        // Add common objects based on task context
        let commonObjects = ["desk", "table", "chair", "floor", "wall", "book", "computer", "phone", "paper"]
        detectedObjects.append(contentsOf: commonObjects.shuffled().prefix(2))
        
        return detectedObjects
    }
    
    // Simulate object detection from image properties
    private func simulateObjectDetectionFromProperties(of image: UIImage) -> [String] {
        var detectedObjects = [String]()
        
        // Calculate brightness and colorfulness
        let brightness = calculateAverageBrightness(of: image)
        let colorfulness = calculateColorfulness(of: image)
        let complexity = calculateImageComplexity(of: image)
        
        // Detect if this might be a gym environment based on image properties
        let isLikelyGym = detectGymEnvironment(in: image)
        
        // Infer objects based on image properties
        if brightness > 0.7 {
            detectedObjects.append("clean surface")
            detectedObjects.append("empty space")
            detectedObjects.append("organized space")
        } else if brightness > 0.5 {
            detectedObjects.append("mostly clean surface")
        } else if brightness < 0.3 {
            detectedObjects.append("dark environment")
            detectedObjects.append("cluttered space")
        }
        
        if colorfulness > 0.6 {
            detectedObjects.append("colorful items")
            detectedObjects.append("decorative objects")
        } else if colorfulness < 0.2 {
            detectedObjects.append("monochrome objects")
            detectedObjects.append("minimalist space")
        }
        
        // Analyze image complexity to detect clutter
        if complexity > 0.7 {
            detectedObjects.append("cluttered space")
            detectedObjects.append("many items")
        } else if complexity < 0.3 {
            detectedObjects.append("clean space")
            detectedObjects.append("few items")
            detectedObjects.append("empty surface")
        }
        
        // Add gym-related objects if environment looks like a gym
        if isLikelyGym {
            let gymObjects = ["exercise machine", "gym equipment", "weights", "fitness equipment", 
                             "workout machine", "bench", "treadmill", "exercise bike", "dumbbells", 
                             "weight rack", "fitness area", "training equipment"]
            
            // Add several gym objects
            detectedObjects.append(contentsOf: gymObjects.shuffled().prefix(4))
        }
        
        // Add common objects
        let commonObjects = ["desk", "table", "chair", "floor", "wall", "items", "objects", "furniture"]
        detectedObjects.append(contentsOf: commonObjects.shuffled().prefix(3))
        
        return detectedObjects
    }
    
    // Analyze human body pose to determine exercise type
    private func analyzePose(observation: VNHumanBodyPoseObservation) -> (poseType: String, confidence: Float)? {
        // Get recognized points
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else {
            return nil
        }
        
        // Check if we have enough key points
        guard let rightShoulder = recognizedPoints[.rightShoulder]?.location,
              let leftShoulder = recognizedPoints[.leftShoulder]?.location,
              let rightHip = recognizedPoints[.rightHip]?.location,
              let leftHip = recognizedPoints[.leftHip]?.location,
              let rightKnee = recognizedPoints[.rightKnee]?.location,
              let leftKnee = recognizedPoints[.leftKnee]?.location else {
            return ("person standing", 0.5)
        }
        
        // Calculate angles between body parts
        let shoulderAngle = abs(rightShoulder.y - leftShoulder.y)
        let hipAngle = abs(rightHip.y - leftHip.y)
        let kneeAngle = abs(rightKnee.y - leftKnee.y)
        
        // Check for bent position (like squatting)
        if let rightAnkle = recognizedPoints[.rightAnkle]?.location,
           let leftAnkle = recognizedPoints[.leftAnkle]?.location {
            
            let kneeToAnkleDistance = abs(rightKnee.y - rightAnkle.y)
            
            if kneeToAnkleDistance < 0.1 {
                return ("person squatting", 0.8)
            }
        }
        
        // Check for lying down position (like bench press)
        if shoulderAngle < 0.1 && hipAngle < 0.1 && 
           rightShoulder.y < 0.4 && leftShoulder.y < 0.4 {
            return ("person lying down", 0.8)
        }
        
        // Check for seated position (like on a machine)
        if rightKnee.y - rightHip.y < 0.15 && leftKnee.y - leftHip.y < 0.15 {
            return ("person seated", 0.7)
        }
        
        return ("person exercising", 0.6)
    }
    
    // Detect specific gym equipment based on image features
    private func detectSpecificGymEquipment(in image: UIImage) -> [String] {
        var detectedEquipment = [String]()
        
        // Resize image for faster processing
        let size = CGSize(width: 224, height: 224)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext(),
              let cgImage = resizedImage.cgImage else {
            UIGraphicsEndImageContext()
            return []
        }
        UIGraphicsEndImageContext()
        
        // Extract image features
        let brightness = calculateAverageBrightness(of: resizedImage)
        let colorfulness = calculateColorfulness(of: resizedImage)
        let complexity = calculateImageComplexity(of: resizedImage)
        let edgeDensity = calculateEdgeDensity(of: cgImage)
        let hasGymColors = detectGymColors(in: resizedImage)
        let hasEquipmentPatterns = detectEquipmentPatterns(in: resizedImage)
        
        // Check for horizontal and vertical lines
        let (horizontalLineCount, verticalLineCount) = countLinesInImage(cgImage)
        
        // Detect specific equipment based on visual features
        
        // Weight machines typically have metal frames and multiple lines
        if hasGymColors && horizontalLineCount > 4 && verticalLineCount > 4 && complexity > 0.5 {
            detectedEquipment.append("weight machine")
            
            // Further classify the type of weight machine
            if horizontalLineCount > Int(Double(verticalLineCount) * 1.5) {
                detectedEquipment.append("leg press machine")
            } else if verticalLineCount > Int(Double(horizontalLineCount) * 1.5) {
                detectedEquipment.append("cable machine")
            } else {
                detectedEquipment.append("multi-gym equipment")
            }
        }
        
        // Treadmills have a distinctive shape and typically have a console
        if hasGymColors && horizontalLineCount > 2 && horizontalLineCount < 6 && 
           verticalLineCount > 1 && verticalLineCount < 4 && complexity < 0.6 {
            detectedEquipment.append("treadmill")
        }
        
        // Benches are typically horizontal with supporting legs
        if hasGymColors && horizontalLineCount > 1 && horizontalLineCount < 4 && 
           verticalLineCount > 0 && verticalLineCount < 3 && complexity < 0.4 {
            detectedEquipment.append("bench")
            
            if horizontalLineCount == 1 && verticalLineCount >= 2 {
                detectedEquipment.append("flat bench")
            } else {
                detectedEquipment.append("adjustable bench")
            }
        }
        
        // Dumbbells and weights are typically dark with high contrast
        if hasGymColors && complexity < 0.4 && edgeDensity < 0.3 && brightness < 0.4 {
            detectedEquipment.append("weights")
            
            if horizontalLineCount < 2 && verticalLineCount < 2 {
                detectedEquipment.append("dumbbells")
            } else {
                detectedEquipment.append("weight plates")
            }
        }
        
        // Cardio machines like bikes and ellipticals
        if hasGymColors && horizontalLineCount > 2 && verticalLineCount > 2 && 
           complexity > 0.4 && complexity < 0.7 {
            detectedEquipment.append("cardio equipment")
            
            if horizontalLineCount > verticalLineCount {
                detectedEquipment.append("exercise bike")
            } else {
                detectedEquipment.append("elliptical machine")
            }
        }
        
        // If we detect gym colors but can't identify specific equipment
        if hasGymColors && detectedEquipment.isEmpty {
            detectedEquipment.append("gym equipment")
        }
        
        // If we detect equipment patterns but can't identify specific equipment
        if hasEquipmentPatterns && detectedEquipment.isEmpty {
            detectedEquipment.append("fitness equipment")
        }
        
        return detectedEquipment
    }
    
    // Count horizontal and vertical lines in an image
    private func countLinesInImage(_ cgImage: CGImage) -> (horizontal: Int, vertical: Int) {
        let width = cgImage.width
        let height = cgImage.height
        
        // Create a bitmap context to sample pixels
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(data: nil,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: bytesPerRow,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: bitmapInfo) else { 
            return (0, 0) 
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else { return (0, 0) }
        
        // Count horizontal and vertical lines
        var horizontalLineCount = 0
        var verticalLineCount = 0
        
        // Check for horizontal lines
        for y in stride(from: 10, to: height-10, by: 10) {
            var lineDetected = false
            var lineLength = 0
            
            for x in 1..<width {
                let currentIndex = (y * bytesPerRow) + (x * bytesPerPixel)
                let prevIndex = (y * bytesPerRow) + ((x-1) * bytesPerPixel)
                let pixelPointer = pixelData.bindMemory(to: UInt8.self, capacity: height * bytesPerRow)
                
                // Check if current pixel is similar to previous
                let isSimilar = abs(Int(pixelPointer[currentIndex]) - Int(pixelPointer[prevIndex])) < 20 &&
                               abs(Int(pixelPointer[currentIndex+1]) - Int(pixelPointer[prevIndex+1])) < 20 &&
                               abs(Int(pixelPointer[currentIndex+2]) - Int(pixelPointer[prevIndex+2])) < 20
                
                if isSimilar {
                    lineLength += 1
                    let thirdOfWidth = Int(width) / 3
                    if lineLength > thirdOfWidth {
                        lineDetected = true
                    }
                } else {
                    lineLength = 0
                }
            }
            
            if lineDetected {
                horizontalLineCount += 1
            }
        }
        
        // Check for vertical lines
        for x in stride(from: 10, to: width-10, by: 10) {
            var lineDetected = false
            var lineLength = 0
            
            for y in 1..<height {
                let currentIndex = (y * bytesPerRow) + (x * bytesPerPixel)
                let prevIndex = ((y-1) * bytesPerRow) + (x * bytesPerPixel)
                let pixelPointer = pixelData.bindMemory(to: UInt8.self, capacity: height * bytesPerRow)
                
                // Check if current pixel is similar to previous
                let isSimilar = abs(Int(pixelPointer[currentIndex]) - Int(pixelPointer[prevIndex])) < 20 &&
                               abs(Int(pixelPointer[currentIndex+1]) - Int(pixelPointer[prevIndex+1])) < 20 &&
                               abs(Int(pixelPointer[currentIndex+2]) - Int(pixelPointer[prevIndex+2])) < 20
                
                if isSimilar {
                    lineLength += 1
                    let thirdOfHeight = Int(height) / 3
                    if lineLength > thirdOfHeight {
                        lineDetected = true
                    }
                } else {
                    lineLength = 0
                }
            }
            
            if lineDetected {
                verticalLineCount += 1
            }
        }
        
        return (horizontalLineCount, verticalLineCount)
    }
    
    // MARK: - Scene Classification
    
    func classifyScene(in image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }
        
        // Generate a cache key based on the image data
        let cacheKey = generateCacheKey(for: image)
        
        // Check if we have cached results
        if let cachedResults = cachedSceneClassificationResults[cacheKey] {
            let sceneLabels = cachedResults.map { $0.identifier }
            completion(sceneLabels)
            return
        }
        
        // In a real app, you would use a scene classification model
        // Since we don't have an actual model file, we'll use a more sophisticated approach
        
        // Calculate image properties
        let brightness = calculateAverageBrightness(of: image)
        let colorfulness = calculateColorfulness(of: image)
        let complexity = calculateImageComplexity(of: image)
        let aspectRatio = image.size.width / image.size.height
        
        // Check if this might be a gym environment
        let isLikelyGym = detectGymEnvironment(in: image)
        
        // Detect dominant colors
        let dominantColors = detectDominantColors(in: image)
        
        var scenes = [String]()
        
        // Classify scene based on properties and dominant colors
        
        // Check for gym environment first
        if isLikelyGym {
            scenes.append("gym")
            
            // Further classify the type of gym area
            if brightness > 0.6 {
                scenes.append("modern fitness center")
            } else {
                scenes.append("traditional gym")
            }
            
            if complexity > 0.7 {
                scenes.append("equipment area")
            } else if complexity < 0.4 {
                scenes.append("open workout space")
            }
            
            // Add more specific gym classifications
            scenes.append("fitness facility")
            scenes.append("workout area")
        } else {
            // Non-gym environment classification
            if brightness > 0.7 {
                if complexity < 0.3 {
                    scenes.append("clean bright space")
                    scenes.append("empty surface")
                } else if colorfulness > 0.5 {
                    scenes.append("bright colorful room")
                } else {
                    scenes.append("bright space")
                }
            } else if brightness < 0.3 {
                scenes.append("dark room")
            } else {
                scenes.append("indoor space")
            }
            
            // Add scene type based on aspect ratio
            if aspectRatio > 1.5 {
                scenes.append("wide room")
            } else if aspectRatio < 0.7 {
                scenes.append("tall space")
            } else {
                scenes.append("standard room")
            }
            
            // Add scene type based on complexity
            if complexity > 0.7 {
                scenes.append("cluttered environment")
            } else if complexity < 0.3 {
                scenes.append("minimalist environment")
                scenes.append("clean space")
            }
            
            // Classify based on dominant colors
            if dominantColors.contains(where: { $0.name == "wood" || $0.name == "brown" }) {
                scenes.append("home environment")
            }
            
            if dominantColors.contains(where: { $0.name == "white" || $0.name == "gray" }) {
                scenes.append("office space")
            }
            
            if dominantColors.contains(where: { $0.name == "green" }) {
                scenes.append("nature-influenced space")
            }
        }
        
        completion(scenes)
    }
    
    // Detect dominant colors in an image
    private func detectDominantColors(in image: UIImage) -> [(name: String, value: UIColor)] {
        guard let cgImage = image.cgImage else { return [] }
        
        // Resize image for faster processing
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext(),
              let resizedCGImage = resizedImage.cgImage else {
            UIGraphicsEndImageContext()
            return []
        }
        UIGraphicsEndImageContext()
        
        let width = resizedCGImage.width
        let height = resizedCGImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(data: nil,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: bytesPerRow,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: bitmapInfo) else { return [] }
        
        context.draw(resizedCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else { return [] }
        
        // Sample pixels and count color occurrences
        var colorCounts: [String: (count: Int, color: UIColor)] = [:]
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * bytesPerRow) + (x * bytesPerPixel)
                let pixelPointer = pixelData.bindMemory(to: UInt8.self, capacity: height * bytesPerRow)
                
                let r = CGFloat(pixelPointer[pixelIndex]) / 255.0
                let g = CGFloat(pixelPointer[pixelIndex + 1]) / 255.0
                let b = CGFloat(pixelPointer[pixelIndex + 2]) / 255.0
                
                // Classify the color
                let colorName = classifyColor(r: r, g: g, b: b)
                let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                
                if let existing = colorCounts[colorName] {
                    colorCounts[colorName] = (existing.count + 1, existing.color)
                } else {
                    colorCounts[colorName] = (1, color)
                }
            }
        }
        
        // Sort colors by occurrence count
        let sortedColors = colorCounts.sorted { $0.value.count > $1.value.count }
        
        // Return top colors with names
        return sortedColors.prefix(3).map { (name: $0.key, value: $0.value.color) }
    }
    
    // Classify a color based on RGB values
    private func classifyColor(r: CGFloat, g: CGFloat, b: CGFloat) -> String {
        // Check for grayscale colors first
        if abs(r - g) < 0.1 && abs(g - b) < 0.1 {
            if r < 0.2 { return "black" }
            if r < 0.5 { return "gray" }
            if r > 0.8 { return "white" }
            return "gray"
        }
        
        // Check for primary and secondary colors
        if r > 0.6 && g < 0.4 && b < 0.4 { return "red" }
        if r < 0.4 && g > 0.6 && b < 0.4 { return "green" }
        if r < 0.4 && g < 0.4 && b > 0.6 { return "blue" }
        
        if r > 0.6 && g > 0.6 && b < 0.4 { return "yellow" }
        if r < 0.4 && g > 0.6 && b > 0.6 { return "cyan" }
        if r > 0.6 && g < 0.4 && b > 0.6 { return "magenta" }
        
        // Check for browns and oranges
        if r > 0.5 && g > 0.3 && g < 0.6 && b < 0.4 { 
            return r > 0.7 ? "orange" : "brown"
        }
        
        // Wood tones
        if r > 0.4 && r < 0.7 && g > 0.2 && g < 0.5 && b < 0.3 {
            return "wood"
        }
        
        return "other"
    }
    
    // MARK: - Specialized Environment Detection
    
    // Detect if an image likely contains a gym environment
    private func detectGymEnvironment(in image: UIImage) -> Bool {
        // In a real app, this would use a trained model
        // For now, we'll use some heuristics based on image properties
        
        // Calculate color histogram to look for common gym colors
        let hasGymColors = detectGymColors(in: image)
        
        // Calculate edge density to detect equipment
        let edgeDensity = calculateEdgeDensity(of: image.cgImage!)
        
        // Check for patterns that might indicate gym equipment
        let hasEquipmentPatterns = detectEquipmentPatterns(in: image)
        
        // Combine factors for gym detection
        let gymLikelihood = (hasGymColors ? 0.4 : 0) + 
                            (edgeDensity > 0.4 ? 0.3 : 0) + 
                            (hasEquipmentPatterns ? 0.3 : 0)
        
        return gymLikelihood > 0.5
    }
    
    // Detect colors commonly found in gyms
    private func detectGymColors(in image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Create a bitmap context to sample pixels
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(data: nil,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: bytesPerRow,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: bitmapInfo) else { return false }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else { return false }
        
        // Sample pixels to detect gym-typical colors
        var blackCount = 0
        var metalGrayCount = 0
        var brightRedCount = 0
        var brightBlueCount = 0
        
        let pixelCount = width * height
        let samplingFactor = max(1, pixelCount / 2000) // Sample at most 2000 pixels
        let totalSamples = (width / samplingFactor) * (height / samplingFactor)
        
        for y in stride(from: 0, to: height, by: samplingFactor) {
            for x in stride(from: 0, to: width, by: samplingFactor) {
                let pixelIndex = (y * bytesPerRow) + (x * bytesPerPixel)
                let pixelPointer = pixelData.bindMemory(to: UInt8.self, capacity: pixelCount * bytesPerPixel)
                
                let r = Double(pixelPointer[pixelIndex]) / 255.0
                let g = Double(pixelPointer[pixelIndex + 1]) / 255.0
                let b = Double(pixelPointer[pixelIndex + 2]) / 255.0
                
                // Check for black (gym equipment)
                if r < 0.15 && g < 0.15 && b < 0.15 {
                    blackCount += 1
                }
                
                // Check for metal gray (weights, machines)
                if abs(r - g) < 0.1 && abs(g - b) < 0.1 && r > 0.4 && r < 0.7 {
                    metalGrayCount += 1
                }
                
                // Check for bright red (often used in gym equipment)
                if r > 0.7 && g < 0.3 && b < 0.3 {
                    brightRedCount += 1
                }
                
                // Check for bright blue (often used in gym equipment)
                if r < 0.3 && g < 0.5 && b > 0.7 {
                    brightBlueCount += 1
                }
            }
        }
        
        // Calculate percentages
        let blackPercent = Double(blackCount) / Double(totalSamples)
        let metalGrayPercent = Double(metalGrayCount) / Double(totalSamples)
        let brightColorPercent = Double(brightRedCount + brightBlueCount) / Double(totalSamples)
        
        // Determine if colors match gym environment
        return (blackPercent > 0.15 && metalGrayPercent > 0.1) || 
               (metalGrayPercent > 0.2) || 
               (brightColorPercent > 0.05 && metalGrayPercent > 0.1)
    }
    
    // Detect patterns that might indicate gym equipment
    private func detectEquipmentPatterns(in image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        
        // Resize image for faster processing
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext(),
              let resizedCGImage = resizedImage.cgImage else {
            UIGraphicsEndImageContext()
            return false
        }
        UIGraphicsEndImageContext()
        
        // Create a bitmap context to sample pixels
        let width = resizedCGImage.width
        let height = resizedCGImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(data: nil,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: bytesPerRow,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: bitmapInfo) else { return false }
        
        context.draw(resizedCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else { return false }
        
        // Count horizontal and vertical lines (common in gym equipment)
        var horizontalLineCount = 0
        var verticalLineCount = 0
        
        // Check for horizontal lines
        for y in 5..<(height-5) {
            var lineDetected = false
            var lineLength = 0
            
            for x in 1..<width {
                let currentIndex = (y * bytesPerRow) + (x * bytesPerPixel)
                let prevIndex = (y * bytesPerRow) + ((x-1) * bytesPerPixel)
                let pixelPointer = pixelData.bindMemory(to: UInt8.self, capacity: height * bytesPerRow)
                
                // Check if current pixel is similar to previous
                let isSimilar = abs(Int(pixelPointer[currentIndex]) - Int(pixelPointer[prevIndex])) < 20 &&
                               abs(Int(pixelPointer[currentIndex+1]) - Int(pixelPointer[prevIndex+1])) < 20 &&
                               abs(Int(pixelPointer[currentIndex+2]) - Int(pixelPointer[prevIndex+2])) < 20
                
                if isSimilar {
                    lineLength += 1
                    if lineLength > width / 3 {
                        lineDetected = true
                    }
                } else {
                    lineLength = 0
                }
            }
            
            if lineDetected {
                horizontalLineCount += 1
            }
        }
        
        // Check for vertical lines
        for x in 5..<(width-5) {
            var lineDetected = false
            var lineLength = 0
            
            for y in 1..<height {
                let currentIndex = (y * bytesPerRow) + (x * bytesPerPixel)
                let prevIndex = ((y-1) * bytesPerRow) + (x * bytesPerPixel)
                let pixelPointer = pixelData.bindMemory(to: UInt8.self, capacity: height * bytesPerRow)
                
                // Check if current pixel is similar to previous
                let isSimilar = abs(Int(pixelPointer[currentIndex]) - Int(pixelPointer[prevIndex])) < 20 &&
                               abs(Int(pixelPointer[currentIndex+1]) - Int(pixelPointer[prevIndex+1])) < 20 &&
                               abs(Int(pixelPointer[currentIndex+2]) - Int(pixelPointer[prevIndex+2])) < 20
                
                if isSimilar {
                    lineLength += 1
                    let thirdOfHeight = Int(height) / 3
                    if lineLength > thirdOfHeight {
                        lineDetected = true
                    }
                } else {
                    lineLength = 0
                }
            }
            
            if lineDetected {
                verticalLineCount += 1
            }
        }
        
        // Gym equipment often has a grid-like structure
        return horizontalLineCount >= 3 && verticalLineCount >= 3
    }
    
    // MARK: - Helper Methods
    
    // Calculate image complexity (to detect clutter)
    private func calculateImageComplexity(of image: UIImage) -> Double {
        // Resize image for faster processing
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext(),
              let cgImage = resizedImage.cgImage else {
            UIGraphicsEndImageContext()
            return 0.5 // Default medium complexity
        }
        UIGraphicsEndImageContext()
        
        // Calculate edge density using a simple edge detection
        let edgeDensity = calculateEdgeDensity(of: cgImage)
        
        // Calculate color variance
        let colorfulness = calculateColorfulness(of: resizedImage)
        
        // Combine metrics for overall complexity
        return (edgeDensity * 0.7 + colorfulness * 0.3)
    }
    
    // Calculate edge density (more edges = more objects = more clutter)
    private func calculateEdgeDensity(of cgImage: CGImage) -> Double {
        let width = cgImage.width
        let height = cgImage.height
        
        // Create a bitmap context to sample pixels
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(data: nil,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: bytesPerRow,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: bitmapInfo) else { return 0.5 }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else { return 0.5 }
        
        // Simple edge detection by checking differences between adjacent pixels
        var edgeCount = 0
        let threshold = 30 // Threshold for edge detection
        
        for y in 1..<height {
            for x in 1..<width {
                let currentPixelIndex = (y * bytesPerRow) + (x * bytesPerPixel)
                let leftPixelIndex = (y * bytesPerRow) + ((x-1) * bytesPerPixel)
                let topPixelIndex = ((y-1) * bytesPerRow) + (x * bytesPerPixel)
                
                let pixelPointer = pixelData.bindMemory(to: UInt8.self, capacity: height * bytesPerRow)
                
                // Calculate difference with left pixel
                let rDiffLeft = abs(Int(pixelPointer[currentPixelIndex]) - Int(pixelPointer[leftPixelIndex]))
                let gDiffLeft = abs(Int(pixelPointer[currentPixelIndex+1]) - Int(pixelPointer[leftPixelIndex+1]))
                let bDiffLeft = abs(Int(pixelPointer[currentPixelIndex+2]) - Int(pixelPointer[leftPixelIndex+2]))
                
                // Calculate difference with top pixel
                let rDiffTop = abs(Int(pixelPointer[currentPixelIndex]) - Int(pixelPointer[topPixelIndex]))
                let gDiffTop = abs(Int(pixelPointer[currentPixelIndex+1]) - Int(pixelPointer[topPixelIndex+1]))
                let bDiffTop = abs(Int(pixelPointer[currentPixelIndex+2]) - Int(pixelPointer[topPixelIndex+2]))
                
                // If difference exceeds threshold, count as edge
                if (rDiffLeft + gDiffLeft + bDiffLeft > threshold) || (rDiffTop + gDiffTop + bDiffTop > threshold) {
                    edgeCount += 1
                }
            }
        }
        
        // Normalize edge count to 0-1 range
        let maxPossibleEdges = (width - 1) * (height - 1) * 2
        return Double(edgeCount) / Double(maxPossibleEdges)
    }
    
    // Generate a cache key for an image
    private func generateCacheKey(for image: UIImage) -> String {
        // In a real app, you would use a hash of the image data
        // For this demo, we'll use image dimensions and a simple hash
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        let simpleHash = (width * height) % 10000
        return "\(width)x\(height)_\(simpleHash)"
    }
    
    // Calculate average brightness of an image
    private func calculateAverageBrightness(of image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0 }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Create a bitmap context to sample pixels
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(data: nil,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: bytesPerRow,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: bitmapInfo) else { return 0 }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else { return 0 }
        
        // Sample pixels to calculate brightness
        var totalBrightness: Double = 0
        let pixelCount = width * height
        let samplingFactor = max(1, pixelCount / 1000) // Sample at most 1000 pixels
        
        for y in stride(from: 0, to: height, by: samplingFactor) {
            for x in stride(from: 0, to: width, by: samplingFactor) {
                let pixelIndex = (y * bytesPerRow) + (x * bytesPerPixel)
                let pixelPointer = pixelData.bindMemory(to: UInt8.self, capacity: pixelCount * bytesPerPixel)
                
                let r = Double(pixelPointer[pixelIndex]) / 255.0
                let g = Double(pixelPointer[pixelIndex + 1]) / 255.0
                let b = Double(pixelPointer[pixelIndex + 2]) / 255.0
                
                // Calculate perceived brightness
                let brightness = (0.299 * r + 0.587 * g + 0.114 * b)
                totalBrightness += brightness
            }
        }
        
        let sampleCount = (width / samplingFactor) * (height / samplingFactor)
        return totalBrightness / Double(sampleCount)
    }
    
    // Calculate colorfulness of an image
    private func calculateColorfulness(of image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0 }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Create a bitmap context to sample pixels
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(data: nil,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: bytesPerRow,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: bitmapInfo) else { return 0 }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else { return 0 }
        
        // Sample pixels to calculate standard deviation of colors
        var rValues = [Double]()
        var gValues = [Double]()
        var bValues = [Double]()
        
        let pixelCount = width * height
        let samplingFactor = max(1, pixelCount / 1000) // Sample at most 1000 pixels
        
        for y in stride(from: 0, to: height, by: samplingFactor) {
            for x in stride(from: 0, to: width, by: samplingFactor) {
                let pixelIndex = (y * bytesPerRow) + (x * bytesPerPixel)
                let pixelPointer = pixelData.bindMemory(to: UInt8.self, capacity: pixelCount * bytesPerPixel)
                
                rValues.append(Double(pixelPointer[pixelIndex]) / 255.0)
                gValues.append(Double(pixelPointer[pixelIndex + 1]) / 255.0)
                bValues.append(Double(pixelPointer[pixelIndex + 2]) / 255.0)
            }
        }
        
        // Calculate standard deviation of each color channel
        let rStdDev = calculateStandardDeviation(rValues)
        let gStdDev = calculateStandardDeviation(gValues)
        let bStdDev = calculateStandardDeviation(bValues)
        
        // Average of standard deviations as a measure of colorfulness
        return (rStdDev + gStdDev + bStdDev) / 3.0
    }
    
    // Calculate standard deviation of an array of values
    private func calculateStandardDeviation(_ values: [Double]) -> Double {
        let count = Double(values.count)
        guard count > 0 else { return 0 }
        
        let mean = values.reduce(0, +) / count
        let sumOfSquaredDifferences = values.reduce(0) { $0 + pow($1 - mean, 2) }
        return sqrt(sumOfSquaredDifferences / count)
    }
} 