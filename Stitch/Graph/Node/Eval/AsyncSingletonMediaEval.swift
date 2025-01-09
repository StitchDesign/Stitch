//
//  AsyncSingletonMediaEval.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/5/23.
//

import Foundation
import StitchSchemaKit
import StitchEngine

typealias MediaManagerSingletonKeyPath = ReferenceWritableKeyPath<StitchDocumentViewModel, LoadingStatus<StitchSingletonMediaObject>?>
typealias SingletonMediaCreation = @Sendable (StitchDocumentViewModel, GraphDelegate, NodeId) async -> ()
typealias AsyncSingletonMediaEvalOp = (PortValues, StitchSingletonMediaObject, Int) -> PortValues

actor SingletonMediaNodeCoordinator: NodeEphemeralObservable {
    @MainActor
    func createSingletonMedia(graph: GraphDelegate,
                              nodeId: NodeId,
                              mediaCreation: @escaping SingletonMediaCreation) async {
        guard let document = graph.documentDelegate else { return }
        
        await mediaCreation(document, graph, nodeId)
        
        graph.calculate(nodeId)
    }
}

extension SingletonMediaNodeCoordinator {
    nonisolated func onPrototypeRestart() { }
}

/// Used for nodes like location and camera.
@MainActor
func asyncSingletonMediaEval(node: PatchNode,
                             graph: GraphDelegate,
                             mediaCreation: @escaping SingletonMediaCreation,
                             mediaManagerKeyPath: MediaManagerSingletonKeyPath,
                             mediaOp: @escaping AsyncSingletonMediaEvalOp) -> PortValuesList {
    
    guard let document = graph.documentDelegate,
            let singletonMediaNodeCoordinator = node.ephemeralObservers?.first as? SingletonMediaNodeCoordinator else {
        fatalErrorIfDebug()
        return []
    }

    return node.loopedEval { values, loopIndex in
        // Return synchronously if media object already exists
        if let singletonMedia = document[keyPath: mediaManagerKeyPath]?.loadedInstance {
            return mediaOp(values, singletonMedia, loopIndex)
        }
        
        // Skip if loading
        guard !(document[keyPath: mediaManagerKeyPath]?.isLoading ?? false) else {
            return node.defaultOutputs
        }

        let nodeId = node.id
        document[keyPath: mediaManagerKeyPath] = .loading

        Task(priority: .high) { [weak graph] in
            guard let graph = graph else {
                return
            }
            
            await singletonMediaNodeCoordinator
                .createSingletonMedia(graph: graph,
                                      nodeId: nodeId,
                                      mediaCreation: mediaCreation)
        }
        
        return node.defaultOutputs
    }
}
