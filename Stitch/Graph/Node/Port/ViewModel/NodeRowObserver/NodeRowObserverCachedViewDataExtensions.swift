//
//  NodeRowObserverCachedViewDataExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/24.
//

import Foundation
import StitchSchemaKit

// MARK: derived/cached data: PortViewData, ActiveValue, PortColor

extension NodeRowObserver {
   /// Caches perf-costly operations for tracking various data used for view.
   @MainActor
   func updatePortViewData() {
       self.portViewType = self.getPortViewType()
   }
   
   @MainActor
   func updateConnectedNodes() {
       self.connectedNodes = self.getConnectedNodes()
       
       // Update port color data
       self.updatePortColor()
   }
   
   @MainActor
   var inputPortViewData: InputPortViewData? {
       self.portViewType?.input
   }
   
   @MainActor
   var outputPortViewData: OutputPortViewData? {
       self.portViewType?.output
   }
   
   /// Gets node ID for currently visible node. Covers edge cause where group nodes use splitter nodes,
   /// which save a differnt node ID.
   @MainActor
   var visibleNodeId: NodeId? {
       guard self.nodeDelegate?.isVisibleInFrame ?? false else {
           return nil
       }
       
       // We use the group node ID only if it isn't in focus
       if self.nodeDelegate?.splitterType == .input &&
           self.nodeDelegate?.graphDelegate?.groupNodeFocused != self.nodeDelegate?.parentGroupNodeId {
           return self.nodeDelegate?.parentGroupNodeId
       }
       
       return self.id.nodeId
   }
       
   // MARK: This has expensive perf (esp `getGroupSplitters`) so it's been relegated to only be called on visible nodes sync.
   @MainActor
   private func getPortViewType() -> PortViewType? {
       guard let nodeId = self.nodeDelegate?.id else {
           return nil
       }

       // Row observers use splitters inside groups
       let isGroup = self.nodeKind == .patch(.splitter) &&
       // Splitter is visible if it's parent group ID is focused in graph
       self.nodeDelegate?.parentGroupNodeId != self.nodeDelegate?.graphDelegate?.groupNodeFocused
       
       guard !isGroup else {
           let splitterType: SplitterType = self.nodeIOType == .input ? .input : .output
           
           // Groups can't use ID's directly since these are splitter IDs
           guard let groupNodeId = self.nodeDelegate?.parentGroupNodeId,
                 let groupSplitters = self.nodeDelegate?.graphDelegate?
                     .getSplitterRowObservers(for: groupNodeId, type: splitterType),
                 let groupPortId = groupSplitters
               .firstIndex(where: { $0.id == self.id }) else {
//                fatalErrorIfDebug()
               return nil
           }
           
           return .init(nodeIO: self.nodeIOType,
                        portId: groupPortId,
                        nodeId: groupNodeId)
       }
       
       // Check for layers and patches
       switch self.id.portType {
       case .keyPath(let layerInputType):
           assertInDebug(self.nodeIOType == .input)
           
           guard let layer = self.nodeKind.getLayer,
                 let index = layer.layerGraphNode.inputDefinitions.firstIndex(of: layerInputType) else {
               fatalErrorIfDebug()
               return nil
           }
           
           return .init(nodeIO: self.nodeIOType,
                        portId: index,
                        nodeId: nodeId)
           
       case .portIndex(let portId):
           return .init(nodeIO: self.nodeIOType,
                        portId: portId,
                        nodeId: nodeId)
       }
   }
   
   /// Nodes connected via edge.
   @MainActor
   private func getConnectedNodes() -> NodeIdSet {
       guard let nodeId = self.nodeDelegate?.id else {
           fatalErrorIfDebug()
           return .init()
       }
       
       // Include self
       var nodes = Set([nodeId])
       
       // Must get port UI data. Helpers below will get group or splitter data depending on focused group.
       switch self.portViewType {
       case .none:
           return .init()
       case .input:
           guard let connectedUpstreamNode = self.getConnectedUpstreamNode() else {
               return nodes
           }
           
           nodes.insert(connectedUpstreamNode)
           return nodes
           
       case .output:
           return nodes.union(getConnectedDownstreamNodes())
       }
   }
   
   var hasEdge: Bool {
       self.upstreamOutputCoordinate.isDefined ||
           self.containsDownstreamConnection
   }
   
   @MainActor
   func updatePortColor() {
       guard let graph = self.nodeDelegate?.graphDelegate,
             let portViewType = self.portViewType else {
           // log("updatePortColor: did not have graph delegate and/or portViewType; will default to noEdge")
           self.setPortColorIfChanged(.noEdge)
           return
       }
       
       switch portViewType {
       case .output:
           updateOutputColor(output: self, graphState: graph)
       case .input:
           updateInputColor(input: self, graphState: graph)
       }
   }

   // TODO: return nil if outputs were empty (e.g. prototype has just been restarted) ?
   static func getActiveValue(allLoopedValues: PortValues,
                              activeIndex: ActiveIndex) -> PortValue {
       let adjustedIndex = activeIndex.adjustedIndex(allLoopedValues.count)
       guard let value = allLoopedValues[safe: adjustedIndex] else {
           // Outputs may be instantiated as empty
           //            fatalError()
           log("getActiveValue: could not retrieve index \(adjustedIndex) in \(allLoopedValues)")
           // See https://github.com/vpl-codesign/stitch/issues/5960
           return PortValue.none
       }

       return value
   }

   func getActiveValue(activeIndex: ActiveIndex) -> PortValue {
       Self.getActiveValue(allLoopedValues: self.allLoopedValues,
                           activeIndex: activeIndex)
   }

   // Tracked by subscriber to know when a new view model should be created
   private func getNodeRowType(activeIndex: ActiveIndex) -> NodeRowType {
       let activeValue = self.getActiveValue(activeIndex: activeIndex)
       return activeValue.getNodeRowType(nodeIO: self.nodeIOType)
   }
}

