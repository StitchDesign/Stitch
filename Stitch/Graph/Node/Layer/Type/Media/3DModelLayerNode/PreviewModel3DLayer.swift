//
//  Preview3DModel.swift
//  Stitch
//
//  Created by Nicholas Arner on 8/3/22.
//

import SwiftUI
import SceneKit
import StitchSchemaKit
import RealityKit

// https://stackoverflow.com/questions/63515452/how-do-i-determine-the-maximum-allowed-size-of-an-mtltexturedescriptor

let max1DTextureWidth: CGFloat = {
    var maxLength = 8192;

    // It's recommended to use your shared device
    let device = MTLCreateSystemDefaultDevice()!

    if device.supportsFamily(.apple1) || device.supportsFamily(.apple2) {
        maxLength = 8192 // A7 and A8 chips
    } else {
        maxLength = 16384 // A9 and later chips
    }
    let k = CGFloat(maxLength)
    // log("max1DTextureWidth: k: \(k)")
    return k
}()

struct Preview3DModelLayer: View {    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel
    
    let realityContent: LayerRealityCameraContent?
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    let entity: StitchEntity?
    let anchorEntityId: UUID?
    let translation3DEnabled: Bool
    let rotation3DEnabled: Bool
    let scale3DEnabled: Bool
    let position: CGPoint
    let rotationX: Double
    let rotationY: Double
    let rotationZ: Double
    let size: LayerSize
    let opacity: Double
    let scale: Double
    let anchoring: Anchoring
    let blurRadius: CGFloat
    let blendMode: StitchBlendMode
    let brightness: Double
    let colorInvert: Bool
    let contrast: Double
    let hueRotation: Double
    let saturation: Double
    let pivot: Anchoring
    
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    let parentIsScrollableGrid: Bool

    @MainActor
    var layerNode: LayerNodeViewModel? {
        self.graph.getNode(layerViewModel.previewCoordinate.layerNodeId.asNodeId)?
            .layerNode
    }

    var sceneSize: CGSize {
        let _sceneSize = size.asSceneSize(parentSize: parentSize)
        // log("sceneSize: \(_sceneSize)")
        return _sceneSize
    }
    
    @ViewBuilder
    func entityView(realityContent: StitchRealityContent) -> some View {
        if let realityContent = realityContent.arView {
            Color.clear
                .modifier(ModelEntityLayerViewModifier(previewLayer: layerViewModel,
                                                       entity: self.entity,
                                                       realityContent: realityContent,
                                                       graph: graph,
                                                       anchorEntityId: anchorEntityId,
                                                       translationEnabled: translation3DEnabled,
                                                       rotationEnabled: rotation3DEnabled,
                                                       scaleEnabled: scale3DEnabled,
                                                       isRendering: isPinnedViewRendering))
        } else {
            // Loading nothing if ARView isn't set yet
            EmptyView()
        }
    }
    
    var body: some View {
        Group {
            if document.isGeneratingProjectThumbnail || !isPinnedViewRendering {
                Color.clear
            }
            
            else if let realityContent = self.realityContent {
                entityView(realityContent: realityContent)
            }
            
            else if let entity = entity {
                Model3DView(layerViewModel: layerViewModel,
                            graph: graph,
                            entity: entity,
                            size: self.size,
                            sceneSize: self.sceneSize,
                            scale: self.scale,
                            opacity: self.opacity,
                            isRendering: self.isPinnedViewRendering)
                .onAppear {
                    entity.isAnimating = self.layerViewModel.isEntityAnimating.getBool ?? false
                }
            }
            
            else {
                Color.clear
            }
        }
        .onChange(of: self.layerViewModel.isEntityAnimating, initial: true) { _, isAnimating in
            entity?.isAnimating = isAnimating.getBool ?? false
        }
        .modifier(PreviewCommonModifier(
            document: document,
            graph: graph,
            layerViewModel: layerViewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: interactiveLayer,
            position: position,
            rotationX: rotationX,
            rotationY: rotationY,
            rotationZ: rotationZ,
            size: sceneSize.toLayerSize,
            scale: scale,
            anchoring: anchoring,
            blurRadius: blurRadius,
            blendMode: blendMode,
            brightness: brightness,
            colorInvert: colorInvert,
            contrast: contrast,
            hueRotation: hueRotation,
            saturation: saturation,
            pivot: pivot,
            shadowColor: .defaultShadowColor,
            shadowOpacity: .defaultShadowOpacity,
            shadowRadius: .defaultShadowRadius,
            shadowOffset: .defaultShadowOffset,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            parentIsScrollableGrid: parentIsScrollableGrid))
    }
}

struct ModelEntityLayerViewModifier: ViewModifier {
    @State private var anchorEntity: AnchorEntity = .init()
    @Bindable var previewLayer: LayerViewModel
    
    let entity: StitchEntity?
    let realityContent: StitchARView
    let graph: GraphState
    let anchorEntityId: UUID?
    let translationEnabled: Bool
    let rotationEnabled: Bool
    let scaleEnabled: Bool
    let isRendering: Bool
    
    var gestures: ARView.EntityGestures {
        var enabledGestures = ARView.EntityGestures()
        
        if translationEnabled {
            enabledGestures.insert(.translation)
        }
        if rotationEnabled {
            enabledGestures.insert(.rotation)
        }
        if scaleEnabled {
            enabledGestures.insert(.scale)
        }
        
        return enabledGestures
    }
    
    func asssignNewAnchor(_ newAnchor: AnchorEntity,
                          entity: StitchEntity?,
                          to realityContent: StitchARView) {
        self.anchorEntity = newAnchor
        
        if let entity = entity {
            newAnchor.addChild(entity.containerEntity)
        }
        
        realityContent.arView.scene.addAnchor(newAnchor)
    }
    
    func getAnchor(for nodeId: UUID) -> AnchorEntity? {
        // TODO: support looping in reality view
        guard let observer = self.graph.getNode(nodeId)?.ephemeralObservers?.first as? ARAnchorObserver else {
            return nil
        }
        
        return observer.arAnchor
    }
    
    func assignGestures(entity: StitchEntity) {
        realityContent.arView.installGestures(gestures,
                                       for: entity.containerEntity as Entity & HasCollision)
    }
    
    func body(content: Content) -> some View {
        guard isRendering else {
            return content
                .eraseToAnyView()
        }
        
        return content
            .onDisappear {
                if let entity = self.entity?.containerEntity {
                    self.anchorEntity.removeChild(entity)
                }
            }
            .onChange(of: realityContent.id, initial: true) {
                if let anchorId = self.anchorEntityId,
                   let assignedAnchor = self.getAnchor(for: anchorId) {
                    self.anchorEntity = assignedAnchor
                }
                
                realityContent.arView.scene.addAnchor(self.anchorEntity)
            }
            .onChange(of: self.anchorEntityId) { _, newAnchorEntityId in
                // Remove old anchor from reality
                let oldAnchor = self.anchorEntity
                realityContent.arView.scene.removeAnchor(oldAnchor)
                
                guard let newAnchorEntityId = newAnchorEntityId else {
                    self.asssignNewAnchor(AnchorEntity(),
                                          entity: self.entity,
                                          to: realityContent)
                    return
                }
                
                guard let anchor = self.getAnchor(for: newAnchorEntityId) else {
                    self.asssignNewAnchor(AnchorEntity(),
                                          entity: self.entity,
                                          to: realityContent)
                    fatalErrorIfDebug()
                    return
                }
                
                self.asssignNewAnchor(anchor,
                                      entity: self.entity,
                                      to: realityContent)
            }
            .onChange(of: self.entity, initial: true) { oldEntity, newEntity in
                // Remove old entity
                if let oldEntity = oldEntity {
                    self.anchorEntity.removeChild(oldEntity.containerEntity)
                }
                
                if let newEntity = newEntity {
                    newEntity.isAnimating = previewLayer.isEntityAnimating.getBool ?? false
                    
                    self.anchorEntity.addChild(newEntity.containerEntity)
                    
                    // assign gestures
                    self.assignGestures(entity: newEntity)
                }
            }
            .onChange(of: self.gestures) {
                if let entity = self.entity {
                    
                    // MARK: if gestures change, the only way to remove a previously-assigned gesture is to remove the entity entirely, recreate it, and then re-assign gestures
                    Task(priority: .high) { [weak entity] in
                        guard let entity = entity,
                              let entityCopy = try? await entity.createCopy() else {
                            return
                        }
                     
                        await MainActor.run { [weak entityCopy] in
                            guard let entityCopy = entityCopy else { return }
                            previewLayer.mediaViewModel.inputMedia = .init(computedMedia: .model3D(entityCopy),
                                                                           id: .init())
                            self.anchorEntity.addChild(entityCopy.containerEntity)
                            
                            self.assignGestures(entity: entityCopy)
                        }
                    }
                }
            }
            .eraseToAnyView()
    }
}
