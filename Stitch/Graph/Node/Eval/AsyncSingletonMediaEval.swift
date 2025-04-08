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
typealias SingletonMediaCreation = @Sendable (StitchDocumentViewModel, GraphState, NodeId) async -> ()
typealias AsyncSingletonMediaEvalOp = (PortValues, StitchSingletonMediaObject, Int) -> MediaEvalOpResult

actor SingletonMediaNodeCoordinator: NodeEphemeralObservable, MediaEvalOpViewable {
    let mediaViewModel: MediaViewModel
    
    @MainActor
    func createSingletonMedia(graph: GraphState,
                              nodeId: NodeId,
                              mediaCreation: @escaping SingletonMediaCreation) async {
        guard let document = graph.documentDelegate else { return }
        
        await mediaCreation(document, graph, nodeId)
        
        graph.scheduleForNextGraphStep(nodeId)
    }
    
    @MainActor init() {
        self.mediaViewModel = .init()
    }
}

extension SingletonMediaNodeCoordinator {
    nonisolated func onPrototypeRestart() { }
}

/// Used for nodes like location and camera.
@MainActor
func asyncSingletonMediaEval(node: PatchNode,
                             graph: GraphState,
                             mediaCreation: @escaping SingletonMediaCreation,
                             mediaManagerKeyPath: MediaManagerSingletonKeyPath,
                             mediaOp: @escaping AsyncSingletonMediaEvalOp) -> [MediaEvalOpResult] {
    
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
            return MediaEvalOpResult(from: node.defaultOutputs)
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
        
        return MediaEvalOpResult(from: node.defaultOutputs)
    }
}
