//
//  StitchEntity.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/24/23.
//

import Combine
import Foundation
import StitchSchemaKit
import RealityKit

@Observable
final class StitchEntity: NSObject, Sendable {
    let id: MediaObjectId
    let sourceURL: URL
    var isUsedInLayer: Bool = false
    let nodeId: NodeId
    
    // Used just for anchors
    weak var anchor: AnchorEntity?
    
    var isAnimating: Bool {
        @MainActor didSet {
            if isAnimating {
                self.entityStatus.loadedInstance?.startAnimation()
            } else {
                self.entityStatus.loadedInstance?.stopAllAnimations()
            }
        }
    }
    
    var transform: matrix_float4x4?
    var entityStatus: LoadingStatus<Entity> = .loading
    
    private var cancellables = Set<AnyCancellable>()
    
    @MainActor
    init(id: MediaObjectId,
         nodeId: NodeId,
         sourceURL: URL,
         isAnimating: Bool,
         initialTransform: matrix_float4x4? = nil,
         anchor: AnchorEntity? = nil) {
        self.id = id
        self.nodeId = nodeId
        self.sourceURL = sourceURL
        self.isAnimating = isAnimating
        
        // For usage with anchor node
        self.transform = initialTransform
        self.anchor = anchor
        
        super.init()
        
        //This is what we want to apply the transform to
        //so that we don't have to keep track of the asset's root transform and a user transform separately
        //when we import a model, the units will often be in meters or centimeters
        //the engine (reality kit or scenekit) has logic that says "hey I don't deal with MM or CM, so I'm going to set the model's transform to be 0.01 so that the model matches my coordinate space"...so the engine will add a root transform to the model so that it can work with the engine's coordinate space
        //so, if we were to apply a transform on just Stitch Entity, we would be applying it to root transform of the model
        //however, if we put the entity that loads the model inside of a container entity, and apply our transform to THAT container entity, it preserves whatever root transform was applied by the modelling package or engine that created the 3D asset
        let containerEntity = Entity()
        
        
        // Loads entity asynchronously. Using the normal loading is NOT efficient
        // even when called on an async thread.
        Entity.loadAsync(contentsOf: sourceURL)
            .sink(receiveCompletion: { [weak self] completion in
                if case let .failure(error) = completion {
                    print("Unable to load a model due to error \(error)")
                    self?.entityStatus = .failed
                }
            }, receiveValue: { [weak self] entity in
                self?.entityStatus = .loaded(containerEntity)
                
                containerEntity.addChild(entity)
                

                // Start animations if enabled. Because async we need to set the property
                // to keep it in sync.
                self?.isAnimating = isAnimating
                if isAnimating {
                    self?.entityStatus.loadedInstance?.startAnimation()
                } else {
                    self?.entityStatus.loadedInstance?.stopAllAnimations()
                }
                
                if let stitchModelEntity = self {
                    if let anchor = self?.anchor {
                        // Set anchor transform
                        if let transform = self?.transform {
                            anchor.transform.matrix = transform
                        }
                        
                        // MARK: must run on main thread
                        // Adds entity to anchor
                        DispatchQueue.main.async { [weak entity, weak anchor] in
                            if let entity = entity {
                                //here we are adding the entity as a child of the anchor
                                //anchor.addChild.containerEntity
                                //any transform edits will be directed to the container
                                //the container will sit between the anchor and the model
                                anchor?.addChild(entity)
                            }
                        }
                    }
                    
                    // Can't recalculate from layer nodes
                    else if !stitchModelEntity.isUsedInLayer {
                        let nodeId = stitchModelEntity.nodeId
                        dispatch(RecalculateGraphFromNode(nodeId: nodeId))
                    }
                } else {
                    log("StitchEntity error: could not resolve all properties.")
                }
            })
            .store(in: &self.cancellables)
    }
    
    @MainActor func applyMatrix(newMatrix: matrix_float4x4) {
        // Update publisher, ensuring 3D model layer gets updated
        self.transform = newMatrix
        
        switch self.entityStatus {
        case .failed:
            return
        case .loading:
            self.transform = newMatrix
        case .loaded(let t):
            t.applyMatrix(newMatrix: newMatrix)
        }
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
