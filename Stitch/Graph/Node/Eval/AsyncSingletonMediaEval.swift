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
typealias SingletonMediaCreation = @Sendable (StitchDocumentViewModel, NodeId) async -> StitchSingletonMediaObject
typealias AsyncSingletonMediaEvalOp = (PortValues, StitchSingletonMediaObject, Int) -> PortValues

actor SingletonMediaNodeCoordinator: NodeEphemeralObservable {
    func createSingletonMedia(document: StitchDocumentViewModel,
                              nodeId: NodeId,
                              mediaManagerKeyPath: MediaManagerSingletonKeyPath,
                              mediaCreation: @escaping SingletonMediaCreation) async {
        let media = await mediaCreation(document, nodeId)
        
        await MainActor.run { [weak document] in
            document?[keyPath: mediaManagerKeyPath] = .loaded(media)
            document?.calculate(nodeId)
        }
    }
}

/// Used for nodes like location and camera.
@MainActor
func asyncSingletonMediaEval(node: PatchNode,
                             document: StitchDocumentViewModel,
                             mediaCreation: @escaping SingletonMediaCreation,
                             mediaManagerKeyPath: MediaManagerSingletonKeyPath,
                             mediaOp: @escaping AsyncSingletonMediaEvalOp) -> PortValuesList {
    
    guard let singletonMediaNodeCoordinator = node.ephemeralObservers?.first as? SingletonMediaNodeCoordinator else {
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

        Task(priority: .high) { [weak document] in
            guard let document = document else {
                return
            }
            
            await singletonMediaNodeCoordinator
                .createSingletonMedia(document: document,
                                      nodeId: nodeId,
                                      mediaManagerKeyPath: mediaManagerKeyPath,
                                      mediaCreation: mediaCreation)
        }
        
        return node.defaultOutputs
    }
}
