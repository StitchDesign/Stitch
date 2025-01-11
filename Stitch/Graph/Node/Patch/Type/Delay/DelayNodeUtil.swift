//
//  GraphActions.swift
//  Stitch
//
//  Created by cjc on 12/21/20.
//

import CoreData
import Foundation
import StitchSchemaKit
import SwiftUI
import AVFoundation
import CoreMotion

/* ----------------------------------------------------------------
 Graph Actions
 ---------------------------------------------------------------- */


extension NodeTimerEphemeralObserver {
    /// Assigns the value to the output of a delay node after the delay timer has fired.
    @MainActor
    func assignDelayedValueAction(timerId: UUID,
                                  node: NodeDelegate,
                                  value: PortValue,
                                  loopIndex: Int,
                                  delayLength: Double,
                                  originalNodeType: UserVisibleType?) {
        guard let graph = node.graphDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        let nodeId = node.id
        self.runningTimers.removeValue(forKey: timerId)
        
        // Note: some nodes do not have node-types; in that case, current node type and original node type will always both be `nil`.
        guard node.userVisibleType == originalNodeType else {
            log("AssignDelayedValueAction: node types no longer match; current type is \(node.userVisibleType) but original type was \(originalNodeType)")
            return
        }
        
        var value = value
        
        // Change pulse time to now if type is pulse,
        // otherwise downstream nodes won't fire
        if originalNodeType == .pulse {
            value = .pulse(graph.graphStepState.graphTime)
        }
        
        // Normal outputs if no media
        guard let media = value.asyncMedia else {
            graph.recalculateGraph(outputValues: .init(from: [value]),
                                   nodeId: nodeId,
                                   loopIndex: loopIndex)
            return
        }
        
        // Create computed copy if there's media
        Task(priority: .userInitiated) { [weak node] in
            guard let mediaCopy = try await media.mediaObject.createComputedCopy() else {
                return
            }
            
            // Mic media needs delayed assigned accordingly
            if let mic = mediaCopy.mic {
                await MainActor.run { [weak mic] in
                    mic?.delegate.assignDelay(delayLength)
                }
            }
            
            let newGraphMedia = GraphMediaValue(id: media.id,
                                                dataType: .computed,
                                                mediaObject: mediaCopy)
            
            let newOutputs = [newGraphMedia.portValue]
            
            await MainActor.run { [weak node] in
                return node?.graphDelegate?.recalculateGraph(outputValues: .byIndex(newOutputs),
                                                             nodeId: nodeId,
                                                             loopIndex: loopIndex)
            }
        }
    }
}
