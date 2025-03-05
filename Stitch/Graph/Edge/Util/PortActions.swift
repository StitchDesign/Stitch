//
//  PortActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/30/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension InputNodeRowObserver {
    /// Removes edges to some observer and conducts the following steps;
    /// 1. Removes connection by deleting reference to upstream output observer.
    /// 2. Flattens values.
    /// 3. Returns side effects for media which needs to be cleared.
    @MainActor
    func removeUpstreamConnection(activeIndex: ActiveIndex? = nil,
                                  isVisible: Bool? = nil) {
        let downstreamStitches = self.upstreamOutputObserver?.getConnectedDownstreamNodes()
            .map { $0.nodeDelegate?.id }
            .toSet
        let willUpstreamBeDisconnected = downstreamStitches == Set([self.id.nodeId])

        // Videos and audios need to be cleared from a now-disconnected node
        // TODO: this logic only works if the destination node of a removed edge is a speaker/video, and not if an edge was disconnected upstream from those nodes.
        // TODO: used to use media observable

        // Remove videos for disconnected visual media layers.
        // Check if the input coordinate of the removed edge came from an image or video layer.
        if self.nodeKind.isVisualMediaLayerNode,
           // Only look at this input if it is the media input
           self.id.isMediaSelectorLocation {
            if willUpstreamBeDisconnected,
               let upstreamOutputObserver = self.upstreamOutputObserver {
                upstreamOutputObserver.getComputedMediaObjects().forEach {
                    if let video = $0.video {
                        video.muteSound()
                    }
                }
            }

            // Mutate video metadata to clear video state--this will update the view
            self.updateValues([.asyncMedia(nil)])
        }

        // Remove audio from disconnected speaker nodes.
        else if self.nodeKind.isSpeakerNode,
                // Only look at this input if it is the media input
                self.id.isMediaSelectorLocation,
                let node = self.upstreamOutputObserver?.nodeDelegate {
            node.getMediaObservers()?
                .map(\.computedMedia)
                .forEach { media in
                    // Run effect to mute sound player
                    media?.mediaObject.updateVolume(to: .zero)
                }
            self.updateValues([.asyncMedia(nil)])
        } else {
            // Flatten values by default
            let flattenedValues = self.allLoopedValues.flattenValues()
            self.updateValues(flattenedValues)
        }
        
        // Removes connection--important to do this after media handling above
        self.upstreamOutputCoordinate = nil
    }
}

extension GraphState {
    // Note: this removes ANY incoming edge to the `edge.to` input; whereas in some use-cases e.g. group node creation, we had expected only to remove the specific passed-in edge if it existed.
    // Hence the rename from `edgeRemoved` to `removesEdgeAt`
    @MainActor
    func removeEdgeAt(input: InputPortViewData,
                      activeIndex: ActiveIndex) {
        if let inputCoordinate = self.getInputCoordinate(from: input) {
            self.removeEdgeAt(input: inputCoordinate,
                              activeIndex: activeIndex)
        }
    }
    
    @MainActor
    func removeEdgeAt(input: InputCoordinate,
                      activeIndex: ActiveIndex) {
        guard let downstreamNode = self.getNodeViewModel(input.nodeId) else {
            return
        }

        // Removes edge and checks for media to remove
        downstreamNode.removeIncomingEdge(at: input,
                                          activeIndex: activeIndex,
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
     */
    @MainActor
    func addEdgeWithoutGraphRecalc(edge: PortEdgeData) {

        guard let downstreamNode = self.getNodeViewModel(edge.to.nodeId),
              let downstreamInputObserver = downstreamNode.getInputRowObserver(for: edge.to.portType) else {
            log("addEdgeWithoutGraphRecalc: could not find input \(edge.to)")
            return
        }

        guard self.getNodeViewModel(edge.from.nodeId).isDefined else {
            log("addEdgeWithoutGraphRecalc: could not find output \(edge.from)")
            return
        }

        // Runs logic to disconnect existing media conntected by edge
        if downstreamInputObserver.upstreamOutputCoordinate != nil {
            downstreamInputObserver.removeUpstreamConnection()
        }
        
        // Sets edge
        downstreamInputObserver.upstreamOutputCoordinate = edge.from

        self.updateTopologicalData()
    }

    // `addEdgeWithoutGraphRecalc` + graph recalc
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
                            activeIndex: ActiveIndex,
                            graph: GraphState) {
        self.getInputRowObserver(for: coordinate.portType)?
            .removeUpstreamConnection(activeIndex: activeIndex,
                                      isVisible: self.isVisibleInFrame(graph.visibleCanvasIds, graph.selectedSidebarLayers))
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
