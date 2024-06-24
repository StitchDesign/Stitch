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
    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel
    let layer: Layer
    let parentSize: CGSize
    let parentDisablesPosition: Bool

    var id: PreviewCoordinate {
        self.layerViewModel.id
    }
    
    var body: some View {
        layer.layerGraphNode.content(graph: graph,
                                     viewModel: layerViewModel,
                                     parentSize: parentSize,
                                     layersInGroup: [],
                                     parentDisablesPosition: parentDisablesPosition)
        .eraseToAnyView()
    }
}
