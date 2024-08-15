//
//  VideoDisplayView.swift
//  prototype
//
//  Created by Christian J Clampitt on 6/16/21.
//

import AVKit
import StitchSchemaKit
import SwiftUI

// REMOVE WHEN GraphSchema is phased out
typealias ImportedURLs = [MediaKey]

struct VideoDisplayView: View {
    let videoPlayer: StitchVideoImportPlayer
    
    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel

    // come from videoLayer node,
    // metadata provides other data...
//    var size: CGSize = defaultImageSize.asAlgebraicCGSize
    let size: LayerSize
    let opacity: Double // = defaultOpacityNumber
    let fitStyle: VisualMediaFitStyle // = .fill
    let isClipped: Bool

    let isGeneratedAtTopLevel: Bool
    
    let id: PreviewCoordinate
    let position: StitchPosition
    let parentSize: CGSize

    var body: some View {
        if isClipped {
            scrubbedVideoView.clipped()
        } else {
            scrubbedVideoView
        }
    }

    private var scrubbedVideoView: some View {
        Group {
            if graph.isGeneratingProjectThumbnail,
               let image = videoPlayer.thumbnail {
                ImageDisplayView(
                    image: image,
                    imageLayerSize: size,
                    imageDisplaySize: ImageDisplaySize(
                        size,
                        parentSize: parentSize,
                        resourceSize: image.size),
                    opacity: opacity,
                    fitStyle: fitStyle,
                    isClipped: isClipped)
            } else {
                ScrubbedVideoView(videoPlayer: videoPlayer,
                                  fitStyle: fitStyle)
            }
        }
        .opacity(opacity)
        .modifier(PreviewCommonSizeModifier(
            viewModel: layerViewModel, 
            isGeneratedAtTopLevel: isGeneratedAtTopLevel,
            aspectRatio: layerViewModel.getAspectRatioData(),
            size: size,
            minWidth: layerViewModel.getMinWidth,
            maxWidth: layerViewModel.getMaxWidth,
            minHeight: layerViewModel.getMinHeight,
            maxHeight: layerViewModel.getMaxHeight,
            parentSize: parentSize,
            sizingScenario: layerViewModel.getSizingScenario,
            frameAlignment: .center))
    }
}
