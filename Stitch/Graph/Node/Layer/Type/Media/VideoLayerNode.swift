//
//  VideoLayerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/21.
//

import AVFoundation
import Foundation
import SwiftUI
import StitchSchemaKit

extension VisualMediaFitStyle {
    static let defaultMediaFitStyle = VisualMediaFitStyle.fill
    static let defaultMediaFitStylePortValue = PortValue.fitStyle(VisualMediaFitStyle.fill)
}

struct VideoLayerNode: LayerNodeDefinition {
    static let layer = Layer.video
    
    static let inputDefinitions: LayerInputPortSet = .init([
        .video,
        .position,
        .rotationX,
        .rotationY,
        .rotationZ,
        .size,
        .opacity,
        .fitStyle,
        .scale,
        .anchoring,
        .zIndex,
        .clipped,
        .masks,
        .volume,
        .size
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.pinning)
        .union(.layerPaddingAndMargin)
        .union(.offsetInGroup)
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, 
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: LayerRealityCameraContent?) -> some View {
        VisualMediaLayerView(document: document,
                             graph: graph,
                             viewModel: viewModel,
                             isPinnedViewRendering: isPinnedViewRendering,
                             parentSize: parentSize,
                             parentDisablesPosition: parentDisablesPosition,
                             parentIsScrollableGrid: parentIsScrollableGrid)
    }
    
        static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}


extension VisualMediaFitStyle: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.fitStyle
    }

    var display: String {
        switch self {
        case .fit:
            return "Fit"
        case .fill:
            return "Fill"
        case .stretch:
            return "Stretch"
        }
    }

    // .aspectRatio's ContentMode
    var asContentMode: ContentMode {
        switch self {
        case .fit:
            return .fit
        case .fill:
            return .fill
        // TODO: Actually, when fitStyle = .stretch and all dimensions are non-auto, we don't apply contentMode at all.
        case .stretch:
            return .fit
        }
    }
}
