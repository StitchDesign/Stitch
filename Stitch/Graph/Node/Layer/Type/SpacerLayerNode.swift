//
//  SpacerLayerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/17/25.
//

import Foundation
import SwiftUI
import StitchSchemaKit


struct SpacerLayerNode: LayerNodeDefinition {
    static let layer: Layer = .spacer
    
    static let inputDefinitions: LayerInputPortSet = .init([
        .enabled,
        .zIndex
    ])
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList,
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: LayerRealityCameraContent?) -> some View {
        
        PreviewSpacerLayer(
            document: document,
            graph: graph,
            layerViewModel: viewModel,
            interactiveLayer: viewModel.interactiveLayer,
            enabled: viewModel.enabled.getBool ?? true,
            parentSize: parentSize)
    }
}

struct PreviewSpacerLayer: View {
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel
    let interactiveLayer: InteractiveLayer
    let enabled: Bool
    let parentSize: CGSize
        
    var body: some View {
        if !enabled {
            EmptyView()
        } else {
            Spacer()
                .modifier(PreviewWindowElementSwiftUIGestures(
                    document: document,
                    graph: graph,
                    interactiveLayer: interactiveLayer,
                    pos: layerViewModel.readMidPosition,
                    size: layerViewModel.readSize.toLayerSize,
                    parentSize: parentSize,
                    minimumDragDistance: DEFAULT_MINIMUM_DRAG_DISTANCE))
        }
    }
}
