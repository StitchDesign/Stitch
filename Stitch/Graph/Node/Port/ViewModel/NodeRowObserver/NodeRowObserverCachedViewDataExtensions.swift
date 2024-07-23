//
//  NodeRowObserverCachedViewDataExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/24.
//

import Foundation
import StitchSchemaKit

// MARK: derived/cached data: PortViewData, ActiveValue, PortColor

extension NodeRowViewModel {
    /// Gets node ID for currently visible node. Covers edge cause where group nodes use splitter nodes,
    /// which save a differnt node ID.
    @MainActor
    var visibleNodeIds: Set<CanvasItemId> {
        guard let nodeDelegate = self.nodeDelegate else {
            return []
        }
        
        let canvasItems = nodeDelegate.getAllCanvasObservers()
        
        return canvasItems.compactMap { canvasItem in
            guard canvasItem.isVisibleInFrame else {
                return nil
            }
            
            // We use the group node ID only if it isn't in focus
            if nodeDelegate.splitterType == .input &&
                 nodeDelegate.graphDelegate?.groupNodeFocused != canvasItem.parentGroupNodeId,
               let parentNodeId = canvasItem.parentGroupNodeId,
               let parentNode = self.graphDelegate?.getNodeViewModel(parentNodeId),
               let parentCanvasItem = parentNode.patchCanvasItem {
                return parentCanvasItem.id
            }
            
            return canvasItem.id
        }
        .toSet
    }

//   /// Caches perf-costly operations for tracking various data used for view.
//   @MainActor
//   func updatePortViewData() {
//       self.portViewType = self.getPortViewType()
//   }
   
   @MainActor
   func updateConnectedCanvasItems() {
       self.connectedCanvasItems = self.getConnectedCanvasItems()
       
       // Update port color data
       self.updatePortColor()
   }

//   @MainActor
//   var inputPortViewData: InputPortViewData? {
//       self.portViewType?.input
//   }
//   
//   @MainActor
//   var outputPortViewData: OutputPortViewData? {
//       self.portViewType?.output
//   }
       
//   // MARK: This has expensive perf (esp `getGroupSplitters`) so it's been relegated to only be called on visible nodes sync.
//   @MainActor
//   private func getPortViewType() -> PortViewType? {
//       guard let nodeId = self.nodeDelegate?.id else {
//           return nil
//       }
//
//       // Row observers use splitters inside groups
//       let isGroup = self.nodeKind == .patch(.splitter) &&
//       // Splitter is visible if it's parent group ID is focused in graph
//       self.nodeDelegate?.parentGroupNodeId != self.nodeDelegate?.graphDelegate?.groupNodeFocused
//       
//       guard !isGroup else {
//           let splitterType: SplitterType = self.nodeIOType == .input ? .input : .output
//           
//           // Groups can't use ID's directly since these are splitter IDs
//           guard let groupNodeId = self.nodeDelegate?.parentGroupNodeId,
//                 let groupSplitters = self.nodeDelegate?.graphDelegate?
//                     .getSplitterRowObservers(for: groupNodeId, type: splitterType),
//                 let groupPortId = groupSplitters
//               .firstIndex(where: { $0.id == self.id }) else {
////                fatalErrorIfDebug()
//               return nil
//           }
//           
//           return .init(nodeIO: self.nodeIOType,
//                        portId: groupPortId,
//                        nodeId: groupNodeId)
//       }
//       
//       // Check for layers and patches
//       switch self.id.portType {
//       case .keyPath(let layerInputType):
//           assertInDebug(self.nodeIOType == .input)
//           
//           guard let layer = self.nodeKind.getLayer,
//                 let index = layer.layerGraphNode.inputDefinitions.firstIndex(of: layerInputType) else {
//               fatalErrorIfDebug()
//               return nil
//           }
//           
//           return .init(nodeIO: self.nodeIOType,
//                        portId: index,
//                        nodeId: nodeId)
//           
//       case .portIndex(let portId):
//           return .init(nodeIO: self.nodeIOType,
//                        portId: portId,
//                        nodeId: nodeId)
//       }
//   }
   
   /// Nodes connected via edge.
   @MainActor
   private func getConnectedCanvasItems() -> Set<CanvasItemId> {
       guard let canvasIds = self.rowDelegate?.nodeDelegate?
        .getAllCanvasObservers()
        .map({ canvasItem in
            canvasItem.id
        }).toSet else {
           // Valid nil case for insert node menu
           return .init()
       }
       
       // Must get port UI data. Helpers below will get group or splitter data depending on focused group
       let connectedCanvasIds = self.findConnectedCanvasItems()
       return canvasIds.union(connectedCanvasIds)
   }
   
//   @MainActor
//   func updatePortColor() {
//       guard let graph = self.rowDelegate?.nodeDelegate?.graphDelegate,
//             let portViewType = self.portViewType else {
//           // log("updatePortColor: did not have graph delegate and/or portViewType; will default to noEdge")
//           self.setPortColorIfChanged(.noEdge)
//           return
//       }
//       
//       switch portViewType {
//       case .output:
//           updateOutputColor(output: self, graphState: graph)
//       case .input:
//           updateInputColor(input: self, graphState: graph)
//       }
//   }
    
//   // Tracked by subscriber to know when a new view model should be created
//   private func getNodeRowType(activeIndex: ActiveIndex) -> NodeRowType {
//       let activeValue = self.getActiveValue(activeIndex: activeIndex)
//       return activeValue.getNodeRowType(nodeIO: self.nodeIOType)
//   }
}

