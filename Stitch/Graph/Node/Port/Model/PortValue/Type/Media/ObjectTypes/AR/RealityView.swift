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

struct RealityView: UIViewRepresentable {
    // AR view must already be created in media manager
//    let arView: StitchARView
    let size: LayerSize
    let scale: Double
    let opacity: Double
    let isCameraEnabled: Bool
    let isShadowsEnabled: Bool
    let anchors: [GraphMediaValue]
    
    // Override camera setting on Mac
    var _isCameraEnabled: Bool {
#if targetEnvironment(macCatalyst)
        return false
#else
        return isCameraEnabled
#endif
    }
    
    func makeUIView(context: Context) -> StitchARView {
        let arView = StitchARView(cameraMode: .nonAR)
        arView.environment.background = _isCameraEnabled ? .cameraFeed() : .color(.blue)
        arView.cameraMode = _isCameraEnabled ? .ar : .nonAR
        arView.renderOptions = isShadowsEnabled ? [] : [.disableGroundingShadows]
        return arView
    }

    func updateUIView(_ uiView: StitchARView, context: Context) {
        let mediaList = anchors.map { $0.mediaObject }
        
        // Update entities in ar view
        uiView.updateAnchors(mediaList: mediaList)
        
        uiView.cameraMode = _isCameraEnabled ? .ar : .nonAR
        uiView.environment.background = _isCameraEnabled ? .cameraFeed() : .color(.blue)
        uiView.frame.size = size.asAlgebraicCGSize
        uiView.alpha = opacity
        uiView.transform = CGAffineTransform(scaleX: scale, y: scale)
        uiView.renderOptions = isShadowsEnabled ? [] : [.disableGroundingShadows]
    }
}
