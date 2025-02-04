//
//  Model3DView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/17/25.
//

import SwiftUI
import RealityKit
import SceneKit
import StitchSchemaKit

struct Model3DView: View {
    @State private var arView: ARView?
    @State private var anchorEntity: AnchorEntity = .init()
    
    let layerViewModel: LayerViewModel
    let graph: GraphState
    let entity: StitchEntity
    let size: LayerSize
    let sceneSize: CGSize
    let scale: Double
    let opacity: Double
    let isRendering: Bool

    var body: some View {
        switch entity.type {
        case .importedMedia(let url):
            // imported 3D models need scene to set model always in view
            Model3DImportView(entity: entity,
                              layerViewModel: layerViewModel,
                              sourceURL: url,
                              sceneSize: sceneSize,
                              modelOpacity: opacity)
        
        default:
            // geometry case
            Model3DGeometryView(layerViewModel: layerViewModel,
                                graph: graph,
                                entity: entity,
                                size: size,
                                scale: scale,
                                opacity: opacity,
                                isRendering: isRendering)
        }
    }
}

struct Model3DGeometryView: View {
    // Make localized reality content for a non-reality 3D object
    @State private var realityContent = StitchRealityContent()
    @State private var anchorEntity: AnchorEntity = .init()
    
    let layerViewModel: LayerViewModel
    let graph: GraphState
    let entity: StitchEntity
    let size: LayerSize
    let scale: Double
    let opacity: Double
    let isRendering: Bool
    
    var body: some View {
        ZStack {
            NonCameraRealityView(layerViewModel: layerViewModel,
                                 realityContent: realityContent,
                                 size: size,
                                 scale: scale,
                                 opacity: opacity,
                                 isShadowsEnabled: false)
            
            if let arView = realityContent.arView {
                Color.clear
                    .modifier(ModelEntityLayerViewModifier(previewLayer: layerViewModel,
                                                           entity: entity,
                                                           realityContent: arView,
                                                           graph: graph,
                                                           anchorEntityId: nil,
                                                           translationEnabled: false,
                                                           rotationEnabled: false,
                                                           scaleEnabled: false,
                                                           isRendering: isRendering))
            }
        }
    }
}

// SwiftUI View that contains a wrapper around the ViewController responsibile for displaying a 3D model
struct Model3DImportView: UIViewRepresentable {
    @Bindable var entity: StitchEntity
    @Bindable var layerViewModel: LayerViewModel
    let sourceURL: URL
    let sceneSize: CGSize
    let modelOpacity: CGFloat
    
    var isAnimating: Bool {
        entity.isAnimating
    }
    
    func makeUIView(context: Context) -> SCNView {
        do {
            let newScene = try SCNScene(url: sourceURL)
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
