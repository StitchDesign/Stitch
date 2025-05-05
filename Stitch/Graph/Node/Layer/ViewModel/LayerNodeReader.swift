//
//  LayerNodeReader.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/17/25.
//

import Foundation

protocol LayerNodeReader {
    @MainActor func getLayerInputObserver(_ layerInput: LayerInputPort) -> LayerInputObserver
    @MainActor func layerGroupId(_ layersSidebarViewModel: LayersSidebarViewModel) -> NodeId?
    @MainActor var allLayerInputObservers: [LayerInputObserver] { get }
}

extension LayerNodeViewModel: LayerNodeReader {
    @MainActor var allLayerInputObservers: [LayerInputObserver] {
        self.layer.layerGraphNode.inputDefinitions.reduce(into: .init()) { partialResult, port in
            partialResult.append(self[keyPath: port.layerNodeKeyPath])
        }
    }
}
