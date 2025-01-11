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
    let arView: StitchARView
    let size: LayerSize
    let scale: Double
    let opacity: Double
    let isShadowsEnabled: Bool
    
    func makeUIView(context: Context) -> StitchARView {
        arView.environment.background = .cameraFeed()
        arView.cameraMode = .ar
        arView.renderOptions = isShadowsEnabled ? [] : [.disableGroundingShadows]
        
        return arView
    }
    
    func updateUIView(_ uiView: StitchARView, context: Context) {
        uiView.frame.size = size.asAlgebraicCGSize
        uiView.alpha = opacity
        uiView.transform = CGAffineTransform(scaleX: scale, y: scale)
        uiView.renderOptions = isShadowsEnabled ? [] : [.disableGroundingShadows]
    }
}

struct NonCameraRealityView: UIViewRepresentable {
    @Bindable var previewLayer: LayerViewModel
    let size: LayerSize
    let scale: Double
    let opacity: Double
    let isShadowsEnabled: Bool
    
    func makeUIView(context: Context) -> StitchARView {
        let arView = StitchARView(cameraMode: .nonAR)
        arView.environment.background = .color(.clear)
        arView.cameraMode = .nonAR
        arView.renderOptions = isShadowsEnabled ? [] : [.disableGroundingShadows]
        
        // Update object with scene
        previewLayer.realityContent = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: StitchARView, context: Context) {        
        uiView.frame.size = size.asAlgebraicCGSize
        uiView.alpha = opacity
        uiView.transform = CGAffineTransform(scaleX: scale, y: scale)
        uiView.renderOptions = isShadowsEnabled ? [] : [.disableGroundingShadows]
    }
}
