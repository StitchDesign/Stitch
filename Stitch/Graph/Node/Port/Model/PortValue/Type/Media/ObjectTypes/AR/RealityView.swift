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
//    let anchors: [GraphMediaValue]
    
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

struct NonCameraRealityViewWrapper: View {
    let arView = StitchARView(cameraMode: .nonAR)
    let size: LayerSize
    let scale: Double
    let opacity: Double
    let isShadowsEnabled: Bool
    let anchors: [GraphMediaValue]
 
    var body: some View {
        NonCameraRealityView(arView: arView,
                             size: size,
                             scale: scale,
                             opacity: opacity,
                             isShadowsEnabled: isShadowsEnabled)
        .onChange(of: anchors, initial: true) {
            let mediaList = anchors.map { $0.mediaObject }
            
            // Update entities in ar view
            arView.updateAnchors(mediaList: mediaList)
        }
    }
}

struct NonCameraRealityView: UIViewRepresentable {
    let arView: StitchARView
    let size: LayerSize
    let scale: Double
    let opacity: Double
    let isShadowsEnabled: Bool
    
    func makeUIView(context: Context) -> StitchARView {
//        let arView = StitchARView(cameraMode: .nonAR)
        arView.environment.background = .color(.purple)
        arView.cameraMode = .nonAR
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
