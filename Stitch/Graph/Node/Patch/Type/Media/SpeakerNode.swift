//
//  SpeakerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/25/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import AudioKit

@MainActor
func speakerNode(id: NodeId,
                 audio: AsyncMediaValue? = nil,
                 position: CGSize = .zero,
                 zIndex: Double = 0) -> PatchNode {
    let inputs = toInputs(
        id: id,
        values:
            ("Sound", [.asyncMedia(audio)]),
        ("Volume", [.number(1)])
    )

    // no outputs actually?
    let outputs = fakeOutputs(id: id, offset: inputs.count)

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .speaker,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func speakerEval(node: PatchNode) -> EvalResult {
    let _ = loopedEval(node: node) { values, loopIndex in
        // MARK: media object is obtained by looking at upstream connected node's saved media objects. This system isn't perfect as not all nodes which can hold media use the MediaEvalOpObserver.
        guard let volume = values[safe: 1]?.getNumber,
              let mediaObject = node.getInputMedia(portIndex: 0,
                                                   loopIndex: loopIndex),
              let speakerMedia = mediaObject.soundFilePlayer else {
            log("speakerEval error: no engine or soundinput found.")
            return
        }
        
        // TODO: player volume should be displayed from this speaker node
        speakerMedia.updateVolume(volume)
    }
    
    return EvalResult(outputsValues: [])
}

// TODO: Move
extension NodeViewModel {
    @MainActor
    /// Gets the media object for some connected input.
    func getInputMedia(coordinate: NodeIOCoordinate,
                       loopIndex: Int) -> StitchMediaObject? {
        switch coordinate.portType {
        case .portIndex(let portIndex):
            return self.getInputMedia(portIndex: portIndex,
                                      loopIndex: loopIndex)
            
        case .keyPath(let keyPath):
            guard let layerNode = self.layerNode else {
                fatalErrorIfDebug()
                return nil
            }
            
            // MARK: helpers here will not retrieve local imported layer view model, thorough testing needed if scope increases
            return layerNode.getConnectedInputMedia(keyPath: keyPath,
                                                    loopIndex: loopIndex)
        }
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getInputMedia(portIndex: Int,
                       loopIndex: Int) -> StitchMediaObject? {
        // Do nothing if no upstream connection for media
        guard let connectedUpstreamObserver = self.inputsObservers[safe: portIndex]?.upstreamOutputObserver,
                let connectedUpstreamNode = connectedUpstreamObserver.nodeDelegate else {
            // Check if media eval op exists here if no connection
            return self.getComputedMedia(loopIndex: loopIndex)
        }
        
        // MARK: media object is obtained by looking at upstream connected node's saved media objects. This system isn't perfect as not all nodes which can hold media use the MediaEvalOpObservable.
        return connectedUpstreamNode.getComputedMedia(loopIndex: loopIndex)
    }
    
    @MainActor
    /// Gets the media object for some connected input.
    func getComputedMedia(loopIndex: Int) -> StitchMediaObject? {
        // Check if media eval op exists here if no connection
        let mediaObserver = self.ephemeralObservers?[safe: loopIndex] as? MediaEvalOpObservable
        return mediaObserver?.currentMedia?.mediaObject
    }
}

extension LayerNodeViewModel {
    @MainActor
    /// Gets the media object for some connected input.
    func getConnectedInputMedia(keyPath: LayerInputType,
                                loopIndex: Int) -> StitchMediaObject? {
        let port = self[keyPath: keyPath.layerNodeKeyPath]
        
        if let upstreamObserver = port.rowObserver.upstreamOutputObserver,
           let upstreamNode = upstreamObserver.nodeDelegate {
            return upstreamNode.getComputedMedia(loopIndex: loopIndex)
        }
        
//        // No upstream connection, find media at layer view model
//        guard let layerViewModel = self.previewLayerViewModels[safe: loopIndex] else {
//            return nil
//        }
//        
//        return layerViewModel.mediaObject
        
        return nil
    }
}
