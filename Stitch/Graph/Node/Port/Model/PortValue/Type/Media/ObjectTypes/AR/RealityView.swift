//
//  RealityView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/29/22.
//

import ARKit
import RealityKit
import SwiftUI
import StitchSchemaKit

struct CameraRealityView: UIViewRepresentable {
    // AR view must already be created in media manager
    let arView: ARView
    let size: LayerSize
    let scale: Double
    let opacity: Double
    let isShadowsEnabled: Bool
    
    func makeUIView(context: Context) -> ARView {
        arView.environment.background = .cameraFeed()
        arView.cameraMode = .ar
        arView.renderOptions = isShadowsEnabled ? [] : [.disableGroundingShadows]
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        uiView.frame.size = size.asAlgebraicCGSize
        uiView.alpha = opacity
        uiView.transform = CGAffineTransform(scaleX: scale, y: scale)
        uiView.renderOptions = isShadowsEnabled ? [] : [.disableGroundingShadows]
    }
}

struct NonCameraRealityView: UIViewRepresentable {
    @Bindable var layerViewModel: LayerViewModel
    let size: LayerSize
    let scale: Double
    let opacity: Double
    let isShadowsEnabled: Bool
    
    func makeUIView(context: Context) -> ARView {
        let arView = StitchARView(cameraMode: .nonAR)
        arView.arView.environment.background = .color(.clear)
        arView.arView.cameraMode = .nonAR
        arView.arView.renderOptions = isShadowsEnabled ? [] : [.disableGroundingShadows]
        
        // MARK: useful for debugging gestures
//        arView.debugOptions = .showPhysics
        
        // Update object with scene
        layerViewModel.realityContent = arView
        
        return arView.arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        uiView.frame.size = size.asAlgebraicCGSize
        uiView.alpha = opacity
        uiView.transform = CGAffineTransform(scaleX: scale, y: scale)
        uiView.renderOptions = isShadowsEnabled ? [] : [.disableGroundingShadows]
    }
}
