//
//  VideoLayerNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 6/17/21.
//

import AVFoundation
import Foundation
import SwiftUI
import StitchSchemaKit

let defaultMediaFitStyle = VisualMediaFitStyle.fill

struct VideoLayerNode: LayerNodeDefinition {
    static let layer = Layer.video
    
    static let inputDefinitions: LayerInputTypeSet = .init([
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
        .masks
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.aspectRatio)
        .union(.sizing).union(.pinning)
    
    static func content(graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, 
                        isGeneratedAtTopLevel: Bool,
                        parentDisablesPosition: Bool) -> some View {
        VisualMediaLayerView(graph: graph,
                             viewModel: viewModel,
                             isGeneratedAtTopLevel: isGeneratedAtTopLevel,
                             parentSize: parentSize,
                             parentDisablesPosition: parentDisablesPosition)
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
