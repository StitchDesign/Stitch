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
    @Binding var realityContent: LayerRealityCameraContent?
    
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
        self.graph.getNodeViewModel(layerViewModel.id.layerNodeId.asNodeId)?
            .layerNode
    }

    var sceneSize: CGSize {
        let _sceneSize = size.asSceneSize(parentSize: parentSize)
        // log("sceneSize: \(_sceneSize)")
        return _sceneSize
    }
    
    var body: some View {
        Group {
            if let realityContent = self.realityContent {
                Color.clear
                    .modifier(ModelEntityLayerViewModifier(previewLayer: layerViewModel,
                                                           entity: self.entity,
                                                           realityContent: realityContent,
                                                           graph: graph,
                                                           anchorEntityId: anchorEntityId,
                                                           translationEnabled: translation3DEnabled,
                                                           rotationEnabled: rotation3DEnabled,
                                                           scaleEnabled: scale3DEnabled))
                
            } else {
                if document.isGeneratingProjectThumbnail {
                    Color.clear
                } else if let entity = entity {
                    Model3DView(entity: entity,
                                layerViewModel: self.layerViewModel,
                                sceneSize: sceneSize,
                                modelOpacity: opacity)
                    .onAppear {
                        entity.isAnimating = self.layerViewModel.isEntityAnimating.getBool ?? false
                    }
                } else {
                    Color.clear
                }
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
    let realityContent: LayerRealityCameraContent
    let graph: GraphState
    let anchorEntityId: UUID?
    let translationEnabled: Bool
    let rotationEnabled: Bool
    let scaleEnabled: Bool
    
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
                          to realityContent: LayerRealityCameraContent) {
        self.anchorEntity = newAnchor
        
        if let entity = entity {
            newAnchor.addChild(entity.containerEntity)
        }
        
        realityContent.scene.addAnchor(newAnchor)
    }
    
    func getAnchor(for nodeId: UUID) -> AnchorEntity? {
        // TODO: support looping in reality view
        guard let observer = self.graph.getNodeViewModel(nodeId)?.ephemeralObservers?.first as? ARAnchorObserver else {
            return nil
        }
        
        return observer.arAnchor
    }
    
    func assignGestures(entity: StitchEntity) {
        realityContent.installGestures(gestures,
                                       for: entity.containerEntity as Entity & HasCollision)
    }
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if let anchorId = self.anchorEntityId,
                   let assignedAnchor = self.getAnchor(for: anchorId) {
                    self.anchorEntity = assignedAnchor
                }
                
                realityContent.scene.addAnchor(self.anchorEntity)
            }
            .onChange(of: self.anchorEntityId) { _, newAnchorEntityId in
                // Remove old anchor from reality
                let oldAnchor = self.anchorEntity
                realityContent.scene.removeAnchor(oldAnchor)
                
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
                    Task { [weak entity] in
                        guard let entity = entity,
                              let entityCopy = try? await entity.createCopy() else {
                            return
                        }
                     
                        await MainActor.run { [weak entityCopy] in
                            guard let entityCopy = entityCopy else { return }
                            previewLayer.mediaObject = .model3D(entityCopy)
                            self.anchorEntity.addChild(entityCopy.containerEntity)
                            
                            self.assignGestures(entity: entityCopy)
                        }
                    }
                }
            }
            .onDisappear {
                realityContent.scene.removeAnchor(self.anchorEntity)
            }
    }
}

// SwiftUI View that contains a wrapper around the ViewController responsibile for displaying a 3D model
struct Model3DView: UIViewRepresentable {
    @Bindable var entity: StitchEntity
    @Bindable var layerViewModel: LayerViewModel
    let sceneSize: CGSize
    let modelOpacity: CGFloat
    
    var isAnimating: Bool {
        entity.isAnimating
    }
    
    func makeUIView(context: Context) -> SCNView {
        do {
            let newScene = try entity.createSCNScene(layerViewModel: layerViewModel)
            let sceneView = SCNView()
            sceneView.scene = newScene
            sceneView.frame.size = CGSize(width: sceneSize.width, height: sceneSize.height)

            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            sceneView.scene?.rootNode.addChildNode(cameraNode)
            cameraNode.position = SCNVector3(x: 0, y: 0, z: 35)
            sceneView.scene?.rootNode.simdWorldPosition = SIMD3<Float>(0, 0, 0)

            let lightNode = SCNNode()
            lightNode.light = SCNLight()
            lightNode.light?.type = .ambient
            lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
            lightNode.name = "LIGHT"
            sceneView.scene?.rootNode.addChildNode(lightNode)

            let modelNode = newScene.rootNode.childNodes.first
            modelNode?.isPaused = !isAnimating

            sceneView.backgroundColor = .clear
            return sceneView
        } catch {
            dispatch(ReceivedStitchFileError(error: .failedToCreate3DScene))
            // return an empty scene view
            let sceneView = SCNView()
            return sceneView
        }
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let scene = uiView.scene,
              let modelNode = uiView.scene?.rootNode.childNodes.first else {
            dispatch(ReceivedStitchFileError(error: .failedToCreate3DScene))
            return
        }
        
        entity.updateSCNScene(from: scene,
                              layerViewModel: layerViewModel)

        uiView.frame.size = CGSize(width: sceneSize.width, height: sceneSize.height)
        modelNode.opacity = modelOpacity
        modelNode.isPaused = !isAnimating
        
        if let transform = entity.transform {
            modelNode.simdTransform = transform
        }
    }
}
