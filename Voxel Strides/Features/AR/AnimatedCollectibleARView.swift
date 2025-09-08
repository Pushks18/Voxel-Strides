//
//  AnimatedCollectibleARView.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import SwiftUI
import SceneKit

// Make sure the struct is public
public struct AnimatedCollectibleARView: UIViewRepresentable {
    // Make the initializer public
    public var modelFileName: String
    
    // Public initializer
    public init(modelFileName: String) {
        self.modelFileName = modelFileName
    }
    
    public func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView(frame: .zero)
        sceneView.backgroundColor = .clear
        sceneView.autoenablesDefaultLighting = true
        sceneView.allowsCameraControl = true
        
        // Load model
        loadModel(in: sceneView)
        
        return sceneView
    }
    
    public func updateUIView(_ uiView: SCNView, context: Context) {
        // Nothing to update
    }
    
    // Separate method to load the model
    private func loadModel(in sceneView: SCNView) {
        // Create a scene
        let scene = SCNScene()
        
        // Try to load the model
        var modelNode: SCNNode?
        
        // First try loading from the Collectibles directory
        if let modelURL = Bundle.main.url(forResource: modelFileName, withExtension: "usdz", subdirectory: "Collectibles") {
            print("Found model in Collectibles directory: \(modelURL)")
            modelNode = loadModelFromURL(modelURL)
        }
        
        // If not found, try the main bundle
        if modelNode == nil, let modelURL = Bundle.main.url(forResource: modelFileName, withExtension: "usdz") {
            print("Found model in main bundle: \(modelURL)")
            modelNode = loadModelFromURL(modelURL)
        }
        
        // If still not found, create a fallback sphere
        if modelNode == nil {
            print("Model not found, creating fallback sphere")
            modelNode = createFallbackSphere()
        }
        
        // Add the model to the scene
        if let modelNode = modelNode {
            // Position the model
            modelNode.position = SCNVector3(0, 0, -0.5)
            
            // Add rotation animation
            let rotationAction = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 5.0)
            let repeatAction = SCNAction.repeatForever(rotationAction)
            modelNode.runAction(repeatAction)
            
            // Add to scene
            scene.rootNode.addChildNode(modelNode)
        }
        
        // Add ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 100
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // Add directional light
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 800
        let directionalNode = SCNNode()
        directionalNode.light = directionalLight
        directionalNode.position = SCNVector3(1, 1, 1)
        scene.rootNode.addChildNode(directionalNode)
        
        // Set the scene
        sceneView.scene = scene
    }
    
    // Helper method to load model from URL
    private func loadModelFromURL(_ url: URL) -> SCNNode? {
        do {
            // Create a scene from the URL
            let scene = try SCNScene(url: url, options: [.checkConsistency: true])
            
            // Get the root node
            let rootNode = SCNNode()
            
            // Add all child nodes from the loaded scene
            for child in scene.rootNode.childNodes {
                rootNode.addChildNode(child)
            }
            
            return rootNode
        } catch {
            print("Failed to load model: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Create a fallback sphere
    private func createFallbackSphere() -> SCNNode {
        // Choose color based on model name
        let color: UIColor
        if modelFileName.contains("crystal") {
            color = .cyan
        } else if modelFileName.contains("sword") || modelFileName.contains("axe") {
            color = .red
        } else if modelFileName.contains("staff") {
            color = .orange
        } else if modelFileName.contains("compass") {
            color = .yellow
        } else {
            color = .purple
        }
        
        // Create a sphere geometry
        let sphere = SCNSphere(radius: 0.1)
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.specular.contents = UIColor.white
        material.shininess = 0.8
        sphere.materials = [material]
        
        // Create a node with the sphere geometry
        let node = SCNNode(geometry: sphere)
        return node
    }
} 