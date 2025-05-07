//
//  PortActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/30/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension NodeViewModel {
    @MainActor
    func getComputedMediaObjects() -> [StitchMediaObject] {
        self.ephemeralObservers?.compactMap {
            ($0 as? MediaEvalOpObservable)?.computedMedia?.mediaObject
        } ?? []
    }
}

extension InputNodeRowObserver {
    /// Removes edges to some observer and conducts the following steps;
    /// 1. Removes connection by deleting reference to upstream output observer.
    /// 2. Flattens values.
    @MainActor
    func removeUpstreamConnection(node: NodeViewModel) {
        
        guard let upstreamOutputObserver = self.upstreamOutputObserver else {
            log("InputNodeRowObserver: removeUpstreamConnection: could not find upstream output observer")
            return
        }
        
        // Here we care about nodes, not canvas items
        let downstreamStitches = upstreamOutputObserver.getDownstreamCanvasItemsIds()
            .map(\.nodeId)
            .toSet
        
        let willUpstreamBeDisconnected = downstreamStitches == Set([self.id.nodeId])

        // Videos and audios need to be cleared from a now-disconnected node
        // TODO: this logic only works if the destination node of a removed edge is a speaker/video, and not if an edge was disconnected upstream from those nodes.
        // TODO: used to use media observable

        // Remove videos for disconnected visual media layers.
        // Check if the input coordinate of the removed edge came from an image or video layer.
        if node.kind.isVisualMediaLayerNode,
           // Only look at this input if it is the media input
           self.id.isMediaSelectorLocation {
            if willUpstreamBeDisconnected,
               let _ = self.upstreamOutputObserver {
                node.getComputedMediaObjects().forEach {
                    if let video = $0.video {
                        video.muteSound()
                    }
                }
            }

            // Mutate video metadata to clear video state--this will update the view
            self.updateValuesInInput([.asyncMedia(nil)])
        }

        // Remove audio from disconnected speaker nodes.
        else if node.kind.isSpeakerNode,
                // Only look at this input if it is the media input
                self.id.isMediaSelectorLocation,
                let upstreamObserverNode = upstreamOutputObserver.nodeDelegate {
            upstreamObserverNode.getAllMediaObservers()?
                .map(\.computedMedia)
                .forEach { media in
                    // Run effect to mute sound player
                    media?.mediaObject.updateVolume(to: .zero)
                }
            self.updateValuesInInput([.asyncMedia(nil)])
        } else {
            // Flatten values by default
            let flattenedValues = self.allLoopedValues.flattenValues()
            self.updateValuesInInput(flattenedValues)
        }
        
        // Removes connection--important to do this after media handling above
        self.upstreamOutputCoordinate = nil
    }
}

extension GraphState {
    // Note: this removes ANY incoming edge to the `edge.to` input; whereas in some use-cases e.g. group node creation, we had expected only to remove the specific passed-in edge if it existed.
    // Hence the rename from `edgeRemoved` to `removesEdgeAt`
    @MainActor
    func removeEdgeAt(input: InputPortIdAddress) {
        guard let inputCoordinate = self.getInputCoordinate(from: input) else {
            log("GraphState: removeEdgeAt: could not find input \(input.portId), \(input.canvasId)")
            return
        }
        
        self.removeEdgeAt(input: inputCoordinate)
    }
    
    @MainActor
    func removeEdgeAt(input: InputCoordinate) {
        guard let downstreamNode = self.getNode(input.nodeId) else {
            return
        }

        // Removes edge and checks for media to remove
        downstreamNode.removeIncomingEdge(at: input,
                                          graph: self)
    }

    @MainActor
    func addEdgeWithoutGraphRecalc(from: OutputCoordinate,
                                   to: InputCoordinate) {
        self.addEdgeWithoutGraphRecalc(edge: .init(from: from, to: to))
    }
    
    /*
     1. Adds edge.from's upstream-output to edge.to's downstream-input
     2. Recalcs topologicalData
     3. "Selects" edge if edge is to a selected node
     4. Schedules the origin-node ("from" node) to be calculated ned
     */
    @MainActor
    func addEdgeWithoutGraphRecalc(edge: PortEdgeData) {
        guard let downstreamNode = self.getNode(edge.to.nodeId),
              let downstreamInputObserver = downstreamNode.getInputRowObserver(for: edge.to.portType) else {
            log("addEdgeWithoutGraphRecalc: could not find input \(edge.to)")
            return
        }

        guard let upstreamNode = self.getNode(edge.from.nodeId),
              let upstreamOutputObserver = upstreamNode.getOutputRowObserver(for: edge.from.portType) else {
            log("addEdgeWithoutGraphRecalc: could not find output \(edge.from)")
            return
        }

        // TODO: are we sure we want to do this?
        // Runs logic to disconnect existing media connected by edge
        if downstreamInputObserver.upstreamOutputCoordinate != nil,
           let downstreamInputObserverNode = self.getNode(downstreamInputObserver.id.nodeId) {
            downstreamInputObserver.removeUpstreamConnection(node: downstreamInputObserverNode)
        }
        
        // Sets edge
        downstreamInputObserver.upstreamOutputCoordinate = edge.from

        // If the downstream observer is a pulse-type, we must manually flow the values down when edge first created,
        // since pulse inputs are skipped whenever the upstream output's values "did not change"
        // (the skipping is how we avoid e.g. the down output on a Press node from constantly triggering a downstream pulse).
        if downstreamInputObserver.allLoopedValues.first?.getPulse.isDefined ?? false {
            assertInDebug(!upstreamOutputObserver.allLoopedValues.isEmpty)
            
            downstreamInputObserver.setValuesInInput(upstreamOutputObserver.allLoopedValues)
        }
        
        self.updateTopologicalData()
    }

    @MainActor
    func edgeAdded(edge: PortEdgeData) {

        // Add edge
        self.addEdgeWithoutGraphRecalc(edge: edge)
        
        // Then recalculate the graph again, with new edge,
        // starting at the 'from' node downward:
        self.scheduleForNextGraphStep(edge.from.nodeId)
    }
    
    @MainActor
    func edgeAdded(edge: PortEdgeUI) {
        guard let edgeData = PortEdgeData(viewData: edge, graph: self) else {
            return
        }
        self.edgeAdded(edge: edgeData)
    }
}

extension NodeViewModel {
    // Used when we edit an input,
    // or when we add a new edge to an input that already has an edge
    @MainActor
    func removeIncomingEdge(at coordinate: NodeIOCoordinate,
                            graph: GraphState) {
        guard let inputObserver = self.getInputRowObserver(for: coordinate.portType),
              let node = graph.getNode(coordinate.nodeId) else {
            log("NodeViewModel: removeIncomingEdge: could not find observer for input \(coordinate)")
            return
        }
        
        inputObserver.removeUpstreamConnection(node: node)
    }
}

extension PortEdgeData {
    @MainActor
    init?(viewData: PortEdgeUI, graph: GraphState) {
        guard let inputCoordinate = graph.getInputCoordinate(from: viewData.to),
              let outputCoordinate = graph.getOutputCoordinate(from: viewData.from) else {
            fatalErrorIfDebug()
            return nil
        }
        
        self = .init(from: outputCoordinate, to: inputCoordinate)
    }
}
