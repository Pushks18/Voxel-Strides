//
//  CompanionUtility.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import Foundation
import RealityKit
import ARKit

class CompanionUtility {
    
    static func createPlaceholderCompanion() -> ModelEntity {
        // Create a parent entity as a ModelEntity
        let companionEntity = ModelEntity()
        
        // Create a colorful body - larger sphere with gradient effect
        let bodyMaterial = SimpleMaterial(
            color: .cyan,
            roughness: 0.1,
            isMetallic: true
        )
        let bodyMesh = MeshResource.generateSphere(radius: 0.15)
        let body = ModelEntity(mesh: bodyMesh, materials: [bodyMaterial])
        
        // Create head - smaller sphere with different material
        let headMaterial = SimpleMaterial(
            color: .purple,
            roughness: 0.2,
            isMetallic: true
        )
        let headMesh = MeshResource.generateSphere(radius: 0.1)
        let head = ModelEntity(mesh: headMesh, materials: [headMaterial])
        head.position = [0, 0.2, 0]
        
        // Create eyes - two small dark spheres with shine
        let eyeMaterial = SimpleMaterial(
            color: .black,
            roughness: 0.0,
            isMetallic: false
        )
        let eyeMesh = MeshResource.generateSphere(radius: 0.02)
        
        let leftEye = ModelEntity(mesh: eyeMesh, materials: [eyeMaterial])
        leftEye.position = [0.05, 0.22, 0.08]
        
        let rightEye = ModelEntity(mesh: eyeMesh, materials: [eyeMaterial])
        rightEye.position = [-0.05, 0.22, 0.08]
        
        // Add eye shine for more life-like appearance
        let shineSize: Float = 0.008
        let shineMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let shineMesh = MeshResource.generateSphere(radius: shineSize)
        
        let leftShine = ModelEntity(mesh: shineMesh, materials: [shineMaterial])
        leftShine.position = [0.05, 0.23, 0.095]
        
        let rightShine = ModelEntity(mesh: shineMesh, materials: [shineMaterial])
        rightShine.position = [-0.05, 0.23, 0.095]
        
        // Create a smiling mouth - curved box
        let mouthMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let mouthMesh = MeshResource.generateBox(size: [0.08, 0.015, 0.01])
        let mouth = ModelEntity(mesh: mouthMesh, materials: [mouthMaterial])
        mouth.position = [0, 0.15, 0.09]
        
        // Add arms for more character
        let armMaterial = SimpleMaterial(color: .cyan, roughness: 0.3, isMetallic: true)
        let armMesh = MeshResource.generateBox(size: [0.03, 0.12, 0.03])
        
        let leftArm = ModelEntity(mesh: armMesh, materials: [armMaterial])
        leftArm.position = [0.15, 0.05, 0]
        leftArm.orientation = simd_quatf(angle: Float(-0.3), axis: [0, 0, 1])
        leftArm.name = "leftArm" // Add name for reference
        
        let rightArm = ModelEntity(mesh: armMesh, materials: [armMaterial])
        rightArm.position = [-0.15, 0.05, 0]
        rightArm.orientation = simd_quatf(angle: Float(0.3), axis: [0, 0, 1])
        rightArm.name = "rightArm" // Add name for reference
        
        // Add all parts to the companion
        companionEntity.addChild(body)
        companionEntity.addChild(head)
        companionEntity.addChild(leftEye)
        companionEntity.addChild(rightEye)
        companionEntity.addChild(leftShine)
        companionEntity.addChild(rightShine)
        companionEntity.addChild(mouth)
        companionEntity.addChild(leftArm)
        companionEntity.addChild(rightArm)
        
        // Add a light to make the companion more visible
        let light = PointLight()
        light.light.color = .white
        light.light.intensity = 1000000
        light.position = [0, 0.3, 0.5]
        companionEntity.addChild(light)
        
        // Position the companion to be easily visible
        companionEntity.position = [0, 0.3, -0.5]
        
        // Add collision component for gesture handling
        companionEntity.collision = CollisionComponent(shapes: [.generateBox(size: [0.3, 0.4, 0.3])])
        
        return companionEntity
    }
} 