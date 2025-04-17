//
//  LayerNodeReader.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/17/25.
//

import Foundation

protocol LayerNodeReader {
    @MainActor func getLayerInputObserver(_ layerInput: LayerInputPort) -> LayerInputObserver
    @MainActor var layerGroupId: NodeId? { get }
}

extension LayerNodeViewModel: LayerNodeReader { }
