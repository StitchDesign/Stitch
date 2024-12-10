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
    // State for media needed if we need to async load an import
    @State private var mediaObject: StitchMediaObject?
    
    // Keeps track of anchor object, if used
    @State private var anchorEntity: AnchorEntity?
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel
    @Binding var realityContent: LayerRealityCameraContent?
    
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    let position3D: Point3D
    let scale3D: Point3D
    let rotation3D: Point3D
    let anchorEntityId: UUID?
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
    
    var mediaValue: AsyncMediaValue? {
        self.layerViewModel.model3D._asyncMedia
    }
    
    var entity: StitchEntity? {
        mediaObject?.model3DEntity
    }
    
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
    
    var transform: simd_float4x4 {
        .init(position: position3D,
              scale: scale3D,
              rotation: rotation3D)
    }
    
    var body: some View {
        Group {
            if let realityContent = self.realityContent,
               let entity = self.entity {
                Color.clear
                    .onChange(of: self.entity, initial: true) {
                        entity.applyMatrix(newMatrix: transform)
                        realityContent.add(entity.containerEntity)
                    }
                    .onChange(of: self.transform) { _, newTransform in
                        entity.applyMatrix(newMatrix: newTransform)
                    }
                    .onChange(of: self.anchorEntityId, initial: true) { _, newAnchorEntityId in
                        // Remove old anchor from reality, if exists
                        if let oldAnchor = self.anchorEntity {
                            realityContent.remove(oldAnchor)
                            
                            // add back entity to scene (which would have gotten removed by above
                            realityContent.add(entity.containerEntity)
                        }

                        guard let newAnchorEntityId = newAnchorEntityId else {
                            self.anchorEntity = nil
                            return
                        }
                        
                        // TODO: support looping in reality view
                        guard let anchorObserver = self.graph.getNodeViewModel(newAnchorEntityId)?.ephemeralObservers?.first as? ARAnchorObserver else {
                            self.anchorEntity = nil
                            fatalErrorIfDebug()
                            return
                        }
                        
                        guard let anchor = anchorObserver.arAnchor else { return }
                        self.anchorEntity = anchor
                        
                        // add entity to anchor
                        anchor.addChild(entity.containerEntity)
                        
                        // add anchor to reality
                        realityContent.add(anchor)
                    }
                    .onDisappear {
                        realityContent.remove(entity.containerEntity)
                    }
            } else {
                if document.isGeneratingProjectThumbnail {
                    Color.clear
                } else if let entity = entity {
                    Model3DView(entity: entity,
                                sceneSize: sceneSize,
                                modelOpacity: opacity)
                    .onAppear {
                        // Mark as layer so we regenerate views when finished loading
                        // Fixes bug where newly created graphs don't show model
                        entity.isUsedInLayer = true
                    }
                } else {
                    Color.clear
                }
            }
        }
        .modifier(MediaLayerViewModifier(mediaValue: mediaValue,
                                         mediaObject: $mediaObject,
                                         document: document,
                                         mediaRowObserver: layerNode?.model3DPort.rowObserver,
                                         isRendering: isPinnedViewRendering))
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
            parentDisablesPosition: parentDisablesPosition))
    }
}

// SwiftUI View that contains a wrapper around the ViewController responsibile for displaying a 3D model
struct Model3DView: UIViewRepresentable {
    @Bindable var entity: StitchEntity
    let sceneSize: CGSize
    let modelOpacity: CGFloat
    
    var model3DFilePath: URL {
        entity.sourceURL
    }

    var isAnimating: Bool {
        entity.isAnimating
    }
    
    func makeUIView(context: Context) -> SCNView {
        do {
            let newScene = try SCNScene(url: model3DFilePath)
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
        guard let modelNode = uiView.scene?.rootNode.childNodes.first else {
            dispatch(ReceivedStitchFileError(error: .failedToCreate3DScene))
            return
        }

        uiView.frame.size = CGSize(width: sceneSize.width, height: sceneSize.height)
        modelNode.opacity = modelOpacity
        modelNode.isPaused = !isAnimating
        
        if let transform = entity.transform {
            modelNode.simdTransform = transform
        }
    }
}
