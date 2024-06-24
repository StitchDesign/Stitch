//
//  AsyncSingletonMediaEval.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/5/23.
//

import Foundation
import StitchSchemaKit
import StitchEngine

typealias MediaManagerSingletonKeyPath = ReferenceWritableKeyPath<GraphDelegate, LoadingStatus<StitchSingletonMediaObject>?>
typealias SingletonMediaCreation = @Sendable (GraphDelegate, NodeId) async -> StitchSingletonMediaObject
typealias AsyncSingletonMediaEvalOp = (PortValues, StitchSingletonMediaObject, Int) -> PortValues

actor SingletonMediaNodeCoordinator: NodeEphemeralObservable {
    func createSingletonMedia(graph: GraphDelegate,
                              nodeId: NodeId,
                              mediaManagerKeyPath: MediaManagerSingletonKeyPath,
                              mediaCreation: @escaping SingletonMediaCreation) async {
        let media = await mediaCreation(graph, nodeId)
        
        await MainActor.run { [weak graph] in
            graph?[keyPath: mediaManagerKeyPath] = .loaded(media)
            graph?.calculate(nodeId)
        }
    }
}

/// Used for nodes like location and camera.
@MainActor
func asyncSingletonMediaEval(node: PatchNode,
                             graph: GraphDelegate,
                             mediaCreation: @escaping SingletonMediaCreation,
                             mediaManagerKeyPath: MediaManagerSingletonKeyPath,
                             mediaOp: @escaping AsyncSingletonMediaEvalOp) -> PortValuesList {
    
    guard let singletonMediaNodeCoordinator = node.ephemeralObservers?.first as? SingletonMediaNodeCoordinator else {
        fatalErrorIfDebug()
        return []
    }
    

    return node.loopedEval { values, loopIndex in
        // Return synchronously if media object already exists
        if let singletonMedia = graph[keyPath: mediaManagerKeyPath]?.loadedInstance {
            return mediaOp(values, singletonMedia, loopIndex)
        }
        
        // Skip if loading
        guard !(graph[keyPath: mediaManagerKeyPath]?.isLoading ?? false) else {
            return node.defaultOutputs
        }

        let nodeId = node.id
        graph[keyPath: mediaManagerKeyPath] = .loading

        Task(priority: .high) { [weak graph] in
            guard let graph = graph else {
                return
            }
            
            await singletonMediaNodeCoordinator
                .createSingletonMedia(graph: graph,
                                      nodeId: nodeId,
                                      mediaManagerKeyPath: mediaManagerKeyPath,
                                      mediaCreation: mediaCreation)
        }
        
        return node.defaultOutputs
    }
}
