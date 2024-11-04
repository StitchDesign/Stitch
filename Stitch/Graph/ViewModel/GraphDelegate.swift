//
//  GraphDelegate.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation
import StitchSchemaKit
import StitchEngine

typealias GraphDelegate = GraphState

extension GraphState {
    @MainActor
    func children(of parent: NodeId) -> NodeViewModels {
        self.layerNodes.values.filter { layerNode in
            layerNode.layerNode?.layerGroupId == parent
        }
    }
}

extension GraphDelegate {
    var projectId: UUID { self.id }
    
    var cameraFeedManager: LoadingStatus<StitchSingletonMediaObject>? {
        self.documentDelegate?.cameraFeedManager
    }
    
    var locationManager: LoadingStatus<StitchSingletonMediaObject>? {
        self.documentDelegate?.locationManager
    }
    
    @MainActor var keypressState: KeyPressState {
        self.documentDelegate?.keypressState ?? .init()
    }
    
    @MainActor var previewWindowSize: CGSize {
        self.documentDelegate?.previewWindowSize ?? .init()
    }
    
    @MainActor var graphMovement: GraphMovementObserver {
        self.documentDelegate?.graphMovement ?? .init()
    }
    
    @MainActor var isGeneratingProjectThumbnail:  Bool {
        self.documentDelegate?.isGeneratingProjectThumbnail ?? false
    }
    
    var cameraFeed: CameraFeedManager? {
        self.cameraFeedManager?.loadedInstance?.cameraFeedManager
    }
    
    @MainActor var cameraSettings: CameraSettings {
        self.documentDelegate?.cameraSettings ?? .init()
    }
}
