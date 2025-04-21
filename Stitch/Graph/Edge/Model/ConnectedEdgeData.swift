//
//  ConnectedEdgeData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 3/11/25.
//

import SwiftUI
import StitchSchemaKit

struct ConnectedEdgeData: Equatable, Identifiable {
    static func == (lhs: ConnectedEdgeData, rhs: ConnectedEdgeData) -> Bool {
        lhs.upstreamOutput.id == rhs.upstreamOutput.id &&
        lhs.downstreamInput.id == rhs.downstreamInput.id &&
        lhs.zIndex == rhs.zIndex
    }
    
    // TODO: use a better type for identifier? Should only need `InputCoordinate` ?
    let id: NodeRowViewModelId
    
    let upstreamOutput: OutputPortUIViewModel
    let downstreamInput: InputPortUIViewModel
    let inputData: EdgeAnchorDownstreamData
    let outputData: EdgeAnchorUpstreamData
    let zIndex: Double

    // To create a "connected edge", we MUST have both an upstream canvas item and a downstream canvas item
    // TODO: can these initializer *really* fail? It must be called with at least one upstream row view model and one downstream row view model
//    @MainActor
//    init?(upstreamCanvasItem: CanvasItemViewModel,
//          upstreamOutputPortUIViewModel: OutputPortUIViewModel,
//          downstreamInput: InputNodeRowViewModel) {
//        
//        guard let downstreamNode = downstreamInput.nodeDelegate,
//              let inputData = EdgeAnchorDownstreamData(from: downstreamInput,
//                                                       upstreamNodeId: upstreamCanvasItem.id),
//              let outputData = EdgeAnchorUpstreamData(from: upstreamCanvasItem.outputPortUIViewModels,
//                                                      upstreamNodeId: upstreamCanvasItem.id.nodeId,
//                                                      inputRowViewModelsOnDownstreamNode: downstreamNode.allInputViewModels) else {
//            return nil
//        }
//        
//        self.id = downstreamInput.id
//        self.upstreamOutput = upstreamOutputPortUIViewModel
//        self.downstreamInput = downstreamInput.portUIViewModel
//        self.inputData = inputData
//        self.outputData = outputData
//        self.zIndex = max(upstreamCanvasItem.zIndex, upstreamCanvasItem.zIndex)
//    }
    
    @MainActor
    static func create(upstreamCanvasItem: CanvasItemViewModel,
                       upstreamOutputPortUIViewModel: OutputPortUIViewModel,
                       downstreamInput: InputNodeRowViewModel) -> Self? {
        
//        guard let downstreamNode = downstreamInput.nodeDelegate,
//              let inputData = EdgeAnchorDownstreamData(from: downstreamInput,
//                                                       upstreamNodeId: upstreamCanvasItem.id),
//              let outputData = EdgeAnchorUpstreamData(from: upstreamCanvasItem.outputPortUIViewModels,
//                                                      upstreamNodeId: upstreamCanvasItem.id.nodeId,
//                                                      inputRowViewModelsOnDownstreamNode: downstreamNode.allInputViewModels) else {
//            fatalErrorIfDebug()
//            return nil
//        }
        
        let downstreamNode = downstreamInput.nodeDelegate!
        
        let inputData = EdgeAnchorDownstreamData(from: downstreamInput,
                                                 upstreamNodeId: upstreamCanvasItem.id)!
        
        let outputData = EdgeAnchorUpstreamData(from: upstreamCanvasItem.outputPortUIViewModels,
                                                upstreamNodeId: upstreamCanvasItem.id.nodeId,
                                                inputRowViewModelsOnDownstreamNode: downstreamNode.allInputViewModels)!
        
        
        
        return .init(id: downstreamInput.id,
                     upstreamOutput: upstreamOutputPortUIViewModel,
                     downstreamInput: downstreamInput.portUIViewModel,
                     inputData: inputData,
                     outputData: outputData,
                     zIndex: max(upstreamCanvasItem.zIndex, upstreamCanvasItem.zIndex))
    }
}
