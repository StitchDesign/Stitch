//
//  StitchEntity.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/24/23.
//

import Foundation
import StitchSchemaKit
import RealityKit
import SceneKit
import SwiftUI

enum StitchEntityType {
    case importedMedia(URL)
    case box
    case sphere
    case cylinder
    case cone
}

@Observable
final class StitchEntity: NSObject, Sendable {
    let id: UUID = .init()
    let type: StitchEntityType
    
    // This is what we want to apply the transform to
    // so that we don't have to keep track of the asset's root transform and a user transform separately
    // when we import a model, the units will often be in meters or centimeters
    // the engine (reality kit or scenekit) has logic that says "hey I don't deal with MM or CM, so I'm going to set the model's transform to be 0.01 so that the model matches my coordinate space"...so the engine will add a root transform to the model so that it can work with the engine's coordinate space
    // so, if we were to apply a transform on just Stitch Entity, we would be applying it to root transform of the model
    // however, if we put the entity that loads the model inside of a container entity, and apply our transform to THAT container entity, it preserves whatever root transform was applied by the modelling package or engine that created the 3D asset
    @MainActor let containerEntity: ModelEntity = .init()
    
    // Entity instance with import
    private let importEntity: Entity
    
    @MainActor
    var isAnimating: Bool = false {
        didSet {
            if isAnimating {
                self.importEntity.startAnimation()
            } else {
                self.importEntity.stopAllAnimations()
            }
        }
    }
    
    @MainActor var transform: matrix_float4x4?
    
    @MainActor init(type: StitchEntityType,
                    entity: Entity) {
        self.type = type
        self.importEntity = entity
        
        super.init()
        
        self.containerEntity.addChild(importEntity)
        
        // Gesture support
        self.containerEntity.generateCollisionShapes(recursive: true)
        
        // Add a collision component to the parentEntity with a rough shape and appropriate offset for the model that it contains
        let entityBounds = self.importEntity.visualBounds(relativeTo: self.containerEntity)
        self.containerEntity.collision = CollisionComponent(shapes: [ShapeResource.generateBox(size: entityBounds.extents).offsetBy(translation: entityBounds.center)])
    }
    
    @MainActor
    convenience init(sourceURL: URL,
                     isAnimating: Bool,
                     initialTransform: matrix_float4x4? = nil) async throws {
        let importEntity = try await Entity(contentsOf: sourceURL)
        
        self.init(type: .importedMedia(sourceURL),
                  entity: importEntity)
        
        self.isAnimating = isAnimating
        
        // For usage with anchor node
        self.transform = initialTransform
        
        if isAnimating {
            importEntity.startAnimation()
        } else {
            importEntity.stopAllAnimations()
        }
    }
}

extension StitchEntity {
    var sourceURL: URL? {
        switch self.type {
        case .importedMedia(let url):
            return url
        default:
            return nil
        }
    }
    
    var displayName: String {
        switch self.type {
        case .importedMedia(let url):
            return url.filename
        case .box:
            return "Box"
        case .sphere:
            return "Sphere"
        case .cone:
            return "Cone"
        case .cylinder:
            return "Cylinder"
        }
    }
    
    @MainActor
    func createCopy() async throws -> StitchEntity {
        let entity = self.sourceURL != nil
        ? try await StitchEntity(sourceURL: self.sourceURL!,
                                 isAnimating: self.isAnimating)
        : StitchEntity(type: self.type,
                       entity: self.importEntity)
        
        entity.importEntity.transform = self.importEntity.transform
        entity.containerEntity.transform = self.containerEntity.transform
        return entity
    }
    
    @MainActor func applyMatrix(newMatrix: matrix_float4x4) {
        // Update publisher, ensuring 3D model layer gets updated
        self.transform = newMatrix
        self.containerEntity._applyMatrix(newMatrix: newMatrix)
    }
    
    @MainActor func createSCNScene(layerViewModel: LayerViewModel) throws -> SCNScene {
        switch self.type {
        case .importedMedia(let url):
            return try SCNScene(url: url)
        default:
            let scene = SCNScene()
            self.buildSCNScene(from: scene,
                               layerViewModel: layerViewModel)
            return scene
        }
    }
    
    @MainActor private func buildSCNScene(from scene: SCNScene,
                                          layerViewModel: LayerViewModel) {
        switch self.type {
        case .importedMedia:
            // do nothing
            return
        case .box:
            let size3D = layerViewModel.size3D.getPoint3D ?? .zero
            let cornerRadius = layerViewModel.cornerRadius.getNumber ?? .zero
            let box = SCNBox(width: size3D.x,
                             height: size3D.y,
                             length: size3D.z,
                             chamferRadius: cornerRadius)
            let node = SCNNode(geometry: box)
            scene.rootNode.addChildNode(node)
        default:
            fatalError()
        }
    }
    
    @MainActor func updateSCNScene(uiView: SCNView,
                                   layerViewModel: LayerViewModel) {
        switch self.type {
        case .importedMedia:
            // do nothing
            return
        
        case .box:
            let boxNode = uiView.scene?.rootNode.childNodes.compactMap {
                $0.geometry as? SCNBox
            }.first
            guard let boxNode = boxNode else {
                fatalErrorIfDebug()
                return
            }
            
            let size3D = layerViewModel.size3D.getPoint3D ?? .zero
            let cornerRadius = layerViewModel.cornerRadius.getNumber ?? .zero
            
            boxNode.width = size3D.x
            boxNode.height = size3D.y
            boxNode.length = size3D.z
            boxNode.chamferRadius = cornerRadius
            
        default:
            fatalErrorIfDebug()
        }
    }
    
    @MainActor
    func createMeshResource(size3D: Point3D,
                            cornerRadius: Double) -> MeshResource? {
        switch self.type {
        case .importedMedia:
            // Do nothing
            return nil
            
        case .box:
            // Create a mesh resource.
            let boxMesh = MeshResource.generateBox(width: Float(size3D.x),
                                                   height: Float(size3D.y),
                                                   depth: Float(size3D.z),
                                                   cornerRadius: Float(cornerRadius))
            return boxMesh
            
        default:
            fatalErrorIfDebug()
            return nil
        }
    }
    
    @MainActor
    func update(size3D: Point3D,
                cornerRadius: Double,
                color: Color,
                isMetallic: Bool) {
        let material = SimpleMaterial(color: color.toUIColor,
                                      isMetallic: isMetallic)
        
        // Create a mesh resource.
        guard let mesh = self.createMeshResource(size3D: size3D,
                                                 cornerRadius: cornerRadius) else {
            return
        }
        
        // Add the mesh resource to a model component, and add it to the entity.
        self.importEntity.components.set(ModelComponent(mesh: mesh, materials: [material]))
    }
}

extension Entity {
    /// Supports animations definied from Reality Composer Pro.
    func startAnimation() {
        self.availableAnimations.forEach {
            self.playAnimation($0.repeat(duration: .infinity),
                               transitionDuration: 1.25,
                               startsPaused: false)
        }
    }
}
