//
//  TaskVerificationManager.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/17/25.
//

import Foundation
import SwiftUI
import Vision
import NaturalLanguage
import CoreML

class TaskVerificationManager: ObservableObject {
    static let shared = TaskVerificationManager()
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0
    
    // Results from various analyses
    private(set) var detectedObjects = [String]()
    private(set) var sceneClassification = [String]()
    private(set) var extractedText = [String]()
    private(set) var imageAnalysisResults = [String: Any]()
    
    private init() {}
    
    // Main function to verify a task with an image
    func verifyTaskCompletion(task: Task, image: UIImage, completion: @escaping (Bool, String) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(false, "Failed to process image")
            return
        }
        
        // Save the verification image to the task
        task.verificationImageData = imageData
        
        // Reset analysis results
        detectedObjects = []
        sceneClassification = []
        extractedText = []
        imageAnalysisResults = [:]
        
        // Set status to processing
        isProcessing = true
        processingProgress = 0.1
        
        // Create a dispatch group to track all analysis tasks
        let analysisGroup = DispatchGroup()
        
        // 1. Perform text recognition
        analysisGroup.enter()
        recognizeText(in: image) { [weak self] text in
            self?.extractedText = text
            self?.processingProgress = 0.3
            analysisGroup.leave()
        }
        
        // 2. Perform object detection using MLModelManager
        analysisGroup.enter()
        MLModelManager.shared.detectObjects(in: image) { [weak self] objects, _, complexity in
            self?.detectedObjects = objects
            self?.imageAnalysisResults["complexity"] = complexity
            self?.processingProgress = 0.5
            analysisGroup.leave()
        }
        
        // 3. Perform scene classification using MLModelManager
        analysisGroup.enter()
        MLModelManager.shared.classifyScene(in: image) { [weak self] scenes in
            self?.sceneClassification = scenes
            self?.processingProgress = 0.7
            analysisGroup.leave()
        }
        
        // When all analyses are complete
        analysisGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Compile all analysis results
            self.imageAnalysisResults["objects"] = self.detectedObjects
            self.imageAnalysisResults["scenes"] = self.sceneClassification
            self.imageAnalysisResults["text"] = self.extractedText
            
            // Analyze the task using NLP
            let taskAnalysis = TaskNLPAnalyzer.shared.analyzeTask(task)
            
            // Match task requirements with image analysis
            self.processingProgress = 0.8
            let matchResult = TaskNLPAnalyzer.shared.matchTaskWithImageAnalysis(
                taskAnalysis: taskAnalysis,
                imageAnalysis: self.imageAnalysisResults
            )
            
            // Generate feedback based on match result
            let feedback = TaskNLPAnalyzer.shared.generateFeedback(task: task, matchResult: matchResult)
            self.processingProgress = 0.9
            
            // Update task verification status
            DispatchQueue.main.async {
                task.verification = matchResult.isCompleted ? .verified : .rejected
                task.verificationFeedback = feedback
                task.isCompleted = matchResult.isCompleted
                
                self.isProcessing = false
                self.processingProgress = 1.0
                
                // Call completion handler
                completion(matchResult.isCompleted, feedback)
            }
        }
    }
    
    // Recognize text in an image using Vision
    private func recognizeText(in image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }
        
        var recognizedText = [String]()
        
        let textRecognitionRequest = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let results = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }
            
            for observation in results {
                if let topCandidate = observation.topCandidates(1).first {
                    recognizedText.append(topCandidate.string)
                }
            }
            
            completion(recognizedText)
        }
        
        // Configure the text recognition request
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = true
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? requestHandler.perform([textRecognitionRequest])
    }
    
    // Calculate average brightness of an image (used for basic image analysis)
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
    
    // Calculate colorfulness of an image (used for basic image analysis)
    private func calculateColorfulness(of image: UIImage) -> Double {
        // Simplified implementation - in a real app, you'd use a more sophisticated algorithm
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