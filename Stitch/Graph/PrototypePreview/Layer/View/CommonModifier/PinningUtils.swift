//
//  PinningUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/23/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

extension PinToId {
    static let defaultPinToId = Self.root

    var display: String {
        switch self {
        case .root:
            return LayerDropdownChoice.RootLayerDropDownChoice.name
        case .parent:
            return LayerDropdownChoice.ParentLayerDropDownChoice.name
        case .layer(let x):
            return x.id.description
        }
    }
    
    static func fromString(_ s: String) -> Self? {
        if let id = UUID(uuidString: s) {
            return .layer(.init(id))
        } else if s.lowercased() == LayerDropdownChoice.RootLayerDropDownChoice.name.lowercased() {
            return .root
        } else if s.lowercased() == LayerDropdownChoice.ParentLayerDropDownChoice.name.lowercased() {
            return .parent
        } else {
            return nil
        }
        
    }
}


/// the data for "View B", which receives the pinned View A
struct PinReceiverData: Equatable {

    // for anchoring
    var size: CGSize
    var origin: CGPoint // always 0,0 for

    // for rotation
    // Note: not applicable for PinTo.root, since PreviewWindow cannot be rotated
    var center: CGPoint

    // Note: for PinTo.root, will always be 0
    var rotationX: CGFloat
    var rotationY: CGFloat
    var rotationZ: CGFloat
}

// MARK: SORTING

/*
 "A is pinned on top of B," "D is pinned on top of B"
 B -> A i.e. "pin-receiving layer -> pinned layer"
  
 Oval A has pinTo input loop = [B, B, C]
 Oval D has pinTo input loop = [C]
 
 pinMap will be [
     B: { A },
     C: { A, D },
 ]
 */

typealias PinMap = [LayerNodeId?: LayerIdSet]

/// Key: root hierarchy group layer ID
/// Value: all possibled nested key-value pairs of pinning views
/// Problem to solve: we need to find chain of connected layers say if there's a pinning relationship like A -> B -> C,
/// at which point we need to pin views at the group context of C.
typealias RootPinMap = [LayerNodeId?: LayerPinData]

struct LayerPinData: Equatable {
    let id: LayerNodeId?
    var pins: [Self]?
}

extension LayerPinData {
    func getAllPins() -> Set<LayerNodeId?> {
        var set = Set<LayerNodeId?>([self.id])
        
        self.pins?.forEach { pin in
            set = set.union(pin.getAllPins())
        }
        
        return set
    }
    
    func recursiveContains(id: LayerNodeId) -> Bool {
        if self.id == id {
            return true
        }
        
        guard let pins = self.pins else {
            return false
        }
        
        return pins.contains { $0.recursiveContains(id: id) }
    }
    
    /// Calculates nested level of some pin given its ID. A value of 0 means no match was found.
    func getPinnedNestedLayerCount(id: LayerNodeId) -> Int {
        if self.id == id {
            return 1
        }
        
        guard let pins = self.pins else {
            return 0
        }
        
        let maxCountInChildren = pins.getMaxPinnedNestedLayerCount(id: id)
        
        return 1 + maxCountInChildren
    }
}

extension RootPinMap {
    /// Getter which ignores layers receiving pins.
    var allPinnedLayerIds: Set<LayerNodeId> {
        let pinDataList: [LayerPinData] = self.values.flatMap { $0.pins ?? [] }
        
        return pinDataList.flatMap {
            $0.getAllPins()
        }
        .compactMap { $0 }
        .toSet
    }
    
    /// Returns set of layer IDs which pin to each other given one of its members.
    func getLinkedPinnedLayers(from id: LayerNodeId) -> LayerIdSet {
        guard let root = self.findRootPinReceiver(from: id) else {
            return .init()
        }
        
        return self.get(root)?
            .getAllPins()
            .compactMap { $0 }
            .toSet ?? .init()
    }
    
    /// Recursively checks most upstream parent ID for pinning data.
    func findRootPinReceiver(from id: LayerNodeId) -> LayerNodeId? {
        for pinData in self.values {
            if pinData.recursiveContains(id: id) {
                return pinData.id
            }
        }
        
        // No match
        return nil
    }
    
    func getPinnedNestedLayerCount(id: LayerNodeId) -> Int {
        Array(self.values).getMaxPinnedNestedLayerCount(id: id)
    }
    
    /// Given some layer ID set, checks if each member of the set is located in the same pinning linked list.
    func areLayersInSamePinFamily(idSet: LayerIdSet) -> Bool {
        for pinData in self.values {
            let allPins = pinData.getAllPins()
            
            if allPins.intersection(idSet) == idSet {
                // If pins contains each member in ID set, exit and return true
                return true
            }
        }
        
        // No matches
        return false
    }
}

extension [LayerPinData] {
    func getMaxPinnedNestedLayerCount(id: LayerNodeId) -> Int {
        self.reduce(0) { currentMaxCount, pin in
            let pinNestedCount = pin.getPinnedNestedLayerCount(id: id)
            return Swift.max(pinNestedCount, currentMaxCount)
        }
    }
}

// TODO: should the passed-in `layerNodes` only be non-hidden layer nodes?
@MainActor
func getFlattenedPinMap(layerNodes: LayerNodesDict,
                        graph: GraphReader) -> PinMap {
    // Iterate through all layer nodes, checking each layer node's pinTo input loop; turn that loop into entries in the PinMap
    layerNodes.values.reduce(into: PinMap()) { pinMap, node in
        
        let nodeId = node.id
        
        // Iterate th
        node.previewLayerViewModels.forEach({ (viewModel: LayerViewModel) in
            // have to check whether the viewModel is actually pinned as well
            if (viewModel.isPinned.getBool ?? false),
               var pinToId = viewModel.pinTo.getPinToId {
                
                // `PinToId.root` case does not have a corresponding layer node,
                //
                let pinReceivingLayer = pinToId.asLayerNodeId(viewModel.id.layerNodeId,
                                                              from: graph)
                
                if pinReceivingLayer == nil && pinToId != .root {
                    // log("getPinMap: had nil pin-receiving-layer but PinToId was not 'root'; will default to 'root'")
                    // e.g. The layer referred to by `pinReceivingLayer` was deleted
                    pinToId = .root
                }
                
                let pinnedLayer = nodeId.asLayerNodeId
                
                // log("getPinMap: pinMap was: \(pinMap)")
                // log("getPinMap: \(pinnedLayer) layer view model is pinned to layer \(pinnedLayer)")
                
                var current = pinMap.get(pinReceivingLayer) ?? .init()
                // log("getPinMap: current was: \(current)")
                
                current.insert(pinnedLayer)
                // log("getPinMap: current is now: \(current)")
                
                pinMap.updateValue(current, forKey: pinReceivingLayer)
                // log("getPinMap: pinMap is now: \(pinMap)")
                
            }
        })
    } // self.layerNodes.forEach
}

func getRootPinMap(pinMap: PinMap) -> RootPinMap {
    // 1. Identify root pairs
    // 2. For each pin via root, check list for chains
    // 3. Assert keys count == root pairs count from 1
    
    let allValues = pinMap.values.flatMap { $0 }
    let rootNodes = pinMap.keys
        .filter { key in
            guard let key = key else {
                // nil = root, which counts
                return true
            }
            
            return !allValues.contains(key)
        }
    
    let rootPinMap = rootNodes.reduce(into: RootPinMap()) { result, rootNode in
        let pinData = pinMap.getRecursiveData(from: rootNode)
        result.updateValue(pinData, forKey: rootNode)
    }
    
    return rootPinMap
}

extension PinMap {
    func getRecursiveData(from layerNodeId: LayerNodeId?,
                          visitedSet: Set<LayerNodeId?> = .init()) -> LayerPinData {
        var pinData = LayerPinData(id: layerNodeId)
        
        guard let values = self.get(layerNodeId) else {
            return pinData
        }
        
        // Prevents cycle
        if let layerNodeId = layerNodeId,
           visitedSet.contains(layerNodeId) {
            log("PinMap.getRecursive pairs: cycle detected for \(layerNodeId)")
            return pinData
        }
        
        var visitedSet = visitedSet
        visitedSet.insert(layerNodeId)
        
        pinData.pins = values.map { layerNodePinId in
            self.getRecursiveData(from: layerNodePinId,
                                  visitedSet: visitedSet)
        }
        
        return pinData
    }
}

// MARK: POSITIONING

extension PinReceiverData {
    static func rootPinReceiverData(_ previewWindowSize: CGSize) -> PinReceiverData {
        PinReceiverData(
            // anchoring
            size: previewWindowSize,

            origin: .zero, // should be okay, since preview window is root of PreviewWindowCoordinate space anyway?
            
            // rotation this will be ignored
            center: .zero,
            rotationX: .zero,
            rotationY: .zero,
            rotationZ: .zero)
    }
}

extension GraphState {
    
    @MainActor func getPinReceiverData(for pinnedLayerViewModel: LayerViewModel) -> PinReceiverData? {
        
        guard let document = self.documentDelegate else {
            fatalErrorIfDebug()
            return nil
        }
        
        let rootPinReceiverData: PinReceiverData = .rootPinReceiverData(document.previewWindowSize)
        
        //    log("getPinReceiverData: pinned layer \(pinnedLayerViewModel.layer) had pinTo of \(pinnedLayerViewModel.pinTo)")
        
        guard let pinnedTo: PinToId = pinnedLayerViewModel.pinTo.getPinToId else {
            log("getPinReceiverData: no pinnedTo for layer \(pinnedLayerViewModel.layer)")
            return rootPinReceiverData
        }
        
        switch pinnedTo {
            
        case .root:
            return rootPinReceiverData
            
            // Note: PinTo = Parent is perhaps redundant vs layer's Anchoring, which is always relative to parent
            // Worst case we can just remove this enum case in the next migration; Root still represents a genuinely new scenario
        case .parent:
            if let layerNode = self.getNode(pinnedLayerViewModel.id.layerNodeId.asNodeId)?.layerNode,
               let parent = layerNode.layerGroupId {
                return self.getPinReceiverData(pinReceiverId: parent.asLayerNodeId,
                                               for: pinnedLayerViewModel)
            } else {
                return rootPinReceiverData
            }
            
        case .layer(let x):
            return self.getPinReceiverData(pinReceiverId: x,
                                           for: pinnedLayerViewModel)
        }
    }
    
    @MainActor func getPinReceiverData(pinReceiverId: LayerNodeId,
                                       for pinnedLayerViewModel: LayerViewModel) -> PinReceiverData? {
        
        guard let document = self.documentDelegate else {
            fatalErrorIfDebug()
            return nil
        }
        
        guard let rootPinReceiverId = self.pinMap.findRootPinReceiver(from: pinReceiverId),
              let pinReceiver = self.nodes.get(rootPinReceiverId.id) else {
            log("getPinReceiverData: no pinReceiver for layer \(pinnedLayerViewModel.layer)")
            return .rootPinReceiverData(document.previewWindowSize)
        }
        
        // TODO: suppose View A (pinned) has a loop of 5, but View B (pin-receiver) has a loop of only 2; which pin-receiver view model should we return?
        let pinReceiverAtSameLoopIndex = pinReceiver.layerNodeViewModel?.previewLayerViewModels[safe: pinnedLayerViewModel.id.loopIndex]
        
        let firstPinReceiver = pinReceiver.layerNodeViewModel?.previewLayerViewModels.first
        
        guard let pinReceiverLayerViewModel = (pinReceiverAtSameLoopIndex ?? firstPinReceiver) else {
            log("getPinReceiverData: no pinReceiver layer view model for layer \(pinnedLayerViewModel)")
            return nil
        }
        
        guard let pinReceiverSize = pinReceiverLayerViewModel.pinReceiverSize,
              let pinReceiverOrigin = pinReceiverLayerViewModel.pinReceiverOrigin,
              let pinReceiverCenter = pinReceiverLayerViewModel.pinReceiverCenter,
              let pinReceiverRotationX = pinReceiverLayerViewModel.rotationX.getNumber,
              let pinReceiverRotationY = pinReceiverLayerViewModel.rotationY.getNumber,
              let pinReceiverRotationZ = pinReceiverLayerViewModel.rotationZ.getNumber else {
            log("getPinReceiverData: missing pinReceiver size, origin and/or center for layer \(pinnedLayerViewModel.layer)")
            return nil
        }
        
        return PinReceiverData(
            // anchoring
            size: pinReceiverSize,
            origin: pinReceiverOrigin,
            
            // rotation
            center: pinReceiverCenter,
            rotationX: pinReceiverRotationX,
            rotationY: pinReceiverRotationY,
            rotationZ: pinReceiverRotationZ)
    }
}

extension PinToId {
    // nil: either pinToId = root or  pinToId could not be found
    @MainActor
    func asLayerNodeId(_ pinnedViewId: LayerNodeId,
                       from graph: GraphReader) -> LayerNodeId? {
        switch self {
        case .root:
            return nil // root has no associated layer node id
        case .layer(let x):
            // Confirm that the layer exists; else return `nil`
            guard (graph.getNode(x.asNodeId)?.layerNode.isDefined ?? false) else {
                log("PinToId.asLayerNodeId: did not have layer node for pinToId.layer \(x)")
                return nil
            }
            return x
        case .parent:
            return graph.getNode(pinnedViewId.asNodeId)?.layerNode?.layerGroupId?.asLayerNodeId
        }
    }
}

@MainActor
func getPinnedViewPosition(pinnedLayerViewModel: LayerViewModel,
                           pinReceiverData: PinReceiverData) -> CGPoint {
    
    adjustPosition(size: pinnedLayerViewModel.pinnedSize ?? .zero,
                   position: pinReceiverData.origin,
                   anchor: pinnedLayerViewModel.pinAnchor.getAnchoring ?? .topLeft,
                   parentSize: pinReceiverData.size,
                   ignoreOffsetTransform: true)
}


// TODO: there must be a more elegant formula here
@MainActor
func getRotationAnchor(lengthA: CGFloat,
                       lengthB: CGFloat,
                       pointA: CGFloat,
                       pointB: CGFloat) -> CGFloat {
    
    // ASSUMES View B's rotation anchor is center i.e. `(0.5, 0.5)`
    let defaultAnchor = 0.5
    
    guard lengthA != lengthB else {
        // Default to center
        // print("getRotationAnchor: length: defaultAnchor")
        return defaultAnchor
    }
    
    guard pointA != pointB else {
        // Default to center
        // print("getRotationAnchor: point: defaultAnchor")
        return defaultAnchor
    }
    
    // e.g. if View B = 200 and View A = 800,
    // (i.e. pinned View A is larger than the View B which it is pinned to.)
    // then anchor diff (0.5)(1/4) i.e. 1/8 = 0.125
    let anchorDiff = defaultAnchor * (lengthB / lengthA)
    
    let aLarger = lengthA > lengthB
    let aBelowOrRight = pointA > pointB
    
    if aLarger {
        return aBelowOrRight ? anchorDiff : (1 - anchorDiff)
    } else {
        return aBelowOrRight ? (1 - anchorDiff) : anchorDiff
    }
}
