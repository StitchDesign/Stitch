//
//  PreviewLayerView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/12/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct PreviewLayerView: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel
    let layer: Layer
    let isPinnedViewRendering: Bool
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    let parentIsScrollableGrid: Bool
    let realityContent: LayerRealityCameraContent?

    var id: PreviewCoordinate {
        self.layerViewModel.previewCoordinate
    }
    
    var body: some View {
        layer.layerGraphNode.content(document: document,
                                     graph: graph,
                                     viewModel: layerViewModel,
                                     parentSize: parentSize,
                                     layersInGroup: [],
                                     isPinnedViewRendering: isPinnedViewRendering,
                                     parentDisablesPosition: parentDisablesPosition,
                                     parentIsScrollableGrid: parentIsScrollableGrid,
                                     realityContent: realityContent)
        .eraseToAnyView()
    }
}
