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
    let arView: StitchARView
    let size: LayerSize
    let scale: Double
    let opacity: Double
    let isCameraEnabled: Bool
    let isShadowsEnabled: Bool

    func makeUIView(context: Context) -> StitchARView {
        let view = arView
        arView.environment.background = .cameraFeed()
        arView.cameraMode = isCameraEnabled ? .ar : .nonAR
        arView.renderOptions = isShadowsEnabled ? [] : [.disableGroundingShadows]
        return view
    }

    func updateUIView(_ uiView: StitchARView, context: Context) {
        uiView.cameraMode = isCameraEnabled ? .ar : .nonAR
        uiView.frame.size = size.asAlgebraicCGSize
        uiView.alpha = opacity
        uiView.transform = CGAffineTransform(scaleX: scale, y: scale)
        arView.renderOptions = isShadowsEnabled ? [] : [.disableGroundingShadows]
    }
}
