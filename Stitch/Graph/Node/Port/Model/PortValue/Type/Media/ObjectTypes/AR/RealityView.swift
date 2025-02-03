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

typealias LayerRealityCameraContent = StitchRealityContent

/// Views point to `StitchRealityContent` when child layers are nested inside of a Reality View.
/// A `StitchRealityContent` always exists even when its `StitchARView` may not be present due to race conditions assigning the AR view.
@Observable
final class StitchRealityContent {
    var arView: StitchARView?
}

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
    let realityContent: StitchRealityContent?
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
        
        // Update object with scene if this is a valid group reality view
        realityContent?.arView = arView
        
        return arView.arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        uiView.frame.size = size.asAlgebraicCGSize
        uiView.alpha = opacity
        uiView.transform = CGAffineTransform(scaleX: scale, y: scale)
        uiView.renderOptions = isShadowsEnabled ? [] : [.disableGroundingShadows]
    }
}
