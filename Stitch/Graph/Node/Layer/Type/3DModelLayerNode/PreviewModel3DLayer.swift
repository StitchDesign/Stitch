//
//  Preview3DModel.swift
//  Stitch
//
//  Created by Nicholas Arner on 8/3/22.
//

import SwiftUI
import SceneKit
import StitchSchemaKit

struct Preview3DModelLayer: View {
    // State for media needed if we need to async load an import
    @State private var mediaObject: StitchMediaObject?
    
    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel
    
    let interactiveLayer: InteractiveLayer
    let position: CGSize
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
    
    var layerNode: LayerNodeViewModel? {
        self.graph.getNodeViewModel(layerViewModel.id.layerNodeId.asNodeId)?
            .layerNode
    }

    var body: some View {
        Group {
            /*
             `Model3DView` is a UIViewRepresentable whose
             updateUIView method adjusts opacity and isAnimation.
             
             When `model3DFilePath` changes, it is `updateUIView`,
             rather than `makeUIView`,
             which is called again.
             
             In order to change out the actual model,
             we would have to recreate the entire scene in `updateUIView`;
             but we don't want to do that when e.g. just opacity has changed.
             
             So we use a SwiftUI identifier modifier to tie
             the UIViewRepresentable's identity to a given model,
             i.e. model3DFilePath.
             */
            if let entity = entity {
                Model3DView(sceneSize: size.asCGSize!,
                            model3DFilePath: entity.sourceURL,
                            modelOpacity: opacity,
                            isAnimating: entity.isAnimating)
                .id(entity.sourceURL)
                .onAppear {
                    // Mark as layer so we regenerate views when finished loading
                    // Fixes bug where newly created graphs don't show model
                    entity.isUsedInLayer = true
                }
            } else {
                Color.clear
            }
            
        }
        .modifier(MediaLayerViewModifier(mediaValue: mediaValue,
                                         mediaObject: $mediaObject,
                                         graph: graph,
                                         mediaRowObserver: layerNode?.model3DPort.rowObserver))
        .modifier(PreviewCommonModifier(
            graph: graph,
            layerViewModel: layerViewModel,
            interactiveLayer: interactiveLayer,
            position: position,
            rotationX: rotationX,
            rotationY: rotationY,
            rotationZ: rotationZ,
            //            size: size.asCGSize(parentSize),
            size: size,
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
    let sceneSize: CGSize
    let model3DFilePath: URL
    let modelOpacity: CGFloat
    let isAnimating: Bool

    func makeUIView(context: Context) -> SCNView {
        do {
            let newScene = try SCNScene.init(url: model3DFilePath)
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
    }

}
