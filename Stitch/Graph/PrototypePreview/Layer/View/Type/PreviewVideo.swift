//
//  PreviewVideo.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/21.
//

import AVKit
import StitchSchemaKit
import SwiftUI

struct PreviewVideoLayer: View {

    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    let videoPlayer: StitchVideoImportPlayer
    let position: CGPoint
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    let size: LayerSize
    let opacity: Double
    let videoFitStyle: VisualMediaFitStyle
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
    
    let shadowColor: Color
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: StitchPosition
    
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    let parentIsScrollableGrid: Bool
    
    let isClipped: Bool
    let volume: Double

    var body: some View {

        // TODO: handle video auto-sizing properly
        // let _size: CGSize = size.asAlgebraicCGSize

        VideoDisplayView(videoPlayer: videoPlayer,
                         document: document,
                         graph: graph,
                         layerViewModel: layerViewModel,
                         size: size, //_size,
                         opacity: opacity,
                         fitStyle: videoFitStyle,
                         isClipped: isClipped, 
                         isPinnedViewRendering: isPinnedViewRendering,
                         id: interactiveLayer.id,
                         position: position,
                         parentSize: parentSize,
                         volume: volume)
            
        // .frame is set VideoDisplayView
        .modifier(PreviewCommonModifierWithoutFrame(
            document: document,
            graph: graph,
            layerViewModel: layerViewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: interactiveLayer,
            position: position,
            rotationX: rotationX,
            rotationY: rotationY,
            rotationZ: rotationZ,
            // actual calculated size at which we're displaying the image
            size: size, 
            minimumDragDistance: DEFAULT_MINIMUM_DRAG_DISTANCE,
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
            shadowColor: shadowColor,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shadowOffset: shadowOffset,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            parentIsScrollableGrid: parentIsScrollableGrid))
    }
}
