//
//  StitchEntity.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/24/23.
//

import Foundation
import StitchSchemaKit
import RealityKit

@Observable
final class StitchEntity: NSObject, Sendable {
    let id: MediaObjectId
    let sourceURL: URL
    let nodeId: NodeId
    
    // This is what we want to apply the transform to
    // so that we don't have to keep track of the asset's root transform and a user transform separately
    // when we import a model, the units will often be in meters or centimeters
    // the engine (reality kit or scenekit) has logic that says "hey I don't deal with MM or CM, so I'm going to set the model's transform to be 0.01 so that the model matches my coordinate space"...so the engine will add a root transform to the model so that it can work with the engine's coordinate space
    // so, if we were to apply a transform on just Stitch Entity, we would be applying it to root transform of the model
    // however, if we put the entity that loads the model inside of a container entity, and apply our transform to THAT container entity, it preserves whatever root transform was applied by the modelling package or engine that created the 3D asset
    let containerEntity: Entity
    
    // Entity instance with import
    private let importEntity: Entity
    
    @MainActor
    var isAnimating: Bool {
        didSet {
            if isAnimating {
                self.importEntity.startAnimation()
            } else {
                self.importEntity.stopAllAnimations()
            }
        }
    }
    
    @MainActor var transform: matrix_float4x4?
    
    @MainActor
    init(id: MediaObjectId,
         nodeId: NodeId,
         sourceURL: URL,
         isAnimating: Bool,
         initialTransform: matrix_float4x4? = nil) async throws {
        self.id = id
        self.nodeId = nodeId
        self.sourceURL = sourceURL
        self.isAnimating = isAnimating
        self.containerEntity = Entity()
        
        // For usage with anchor node
        self.transform = initialTransform
        
        let importEntity = try await Entity(contentsOf: sourceURL)
        self.containerEntity.addChild(importEntity)
        
        if isAnimating {
            importEntity.startAnimation()
        } else {
            importEntity.stopAllAnimations()
        }
        
        self.importEntity = importEntity
        super.init()
    }
    
    @MainActor func applyMatrix(newMatrix: matrix_float4x4) {
        // Update publisher, ensuring 3D model layer gets updated
        self.transform = newMatrix
        self.containerEntity._applyMatrix(newMatrix: newMatrix)
    }
}

extension Entity {
    func startAnimation() {
        self.availableAnimations.forEach {
            self.playAnimation($0.repeat(duration: .infinity),
                               transitionDuration: 1.25,
                               startsPaused: false)
        }
    }
}
