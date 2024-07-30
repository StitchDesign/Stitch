//
//  NodeRowViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/26/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

enum GraphItemType: Hashable {
    case node(CanvasItemId)
    
    // Passing in layer input type ensures uniqueness of IDs in inspector
    case layerInspector(LayerInputType)
}

extension GraphItemType {
    var isLayerInspector: Bool {
        switch self {
        case .layerInspector:
            return true
        default:
            return false
        }
    }
}

struct NodeRowViewModelId: Hashable {
    var graphItemType: GraphItemType
    var nodeId: NodeId
    
    // TODO: this is always 0 for layer inpsector which creates issues for tabbing
    var portId: Int
}

extension NodeRowViewModelId {
    /// Determines if some row view model reports to a node, rather than to the layer inspector
    var isNode: Bool {
        switch self.graphItemType {
        case .node:
            return true
        default:
            return false
        }
    }
    
    static let empty: Self = .init(graphItemType: .node(.node(.init())),
                                   nodeId: .init(),
                                   portId: -1)
}

protocol NodeRowViewModel: AnyObject, Observable, Identifiable {
    associatedtype FieldType: FieldViewModel
    associatedtype RowObserver: NodeRowObserver
    associatedtype PortViewType: PortViewData
    
    var id: NodeRowViewModelId { get set }
    
    // View-specific value that only updates when visible
    // separate propety for perf reasons:
    var activeValue: PortValue { get set }
    
    // Holds view models for fields
    var fieldValueTypes: [FieldGroupTypeViewModel<FieldType>] { get set }
    
    var anchorPoint: CGPoint? { get set }
    
    var connectedCanvasItems: Set<CanvasItemId> { get set }
    
    var portColor: PortColor { get set }
    
    var nodeDelegate: NodeDelegate? { get set }
    
    var rowDelegate: RowObserver? { get set }
    
    var canvasItemDelegate: CanvasItemViewModel? { get set }
    
    static var nodeIO: NodeIO { get }
    
    @MainActor func calculatePortColor() -> PortColor
    
    @MainActor func portDragged(gesture: DragGesture.Value, graphState: GraphState)
    
    @MainActor func portDragEnded(graphState: GraphState)
    
    @MainActor func hasSelectedEdge() -> Bool
    
    @MainActor func findConnectedCanvasItems() -> CanvasItemIdSet
    
    @MainActor
    init(id: NodeRowViewModelId,
         activeValue: PortValue,
         nodeDelegate: NodeDelegate?,
         rowDelegate: RowObserver?,
         canvasItemDelegate: CanvasItemViewModel?)
}

extension NodeRowViewModel {
    var portViewData: PortViewType? {
        guard let canvasId = self.canvasItemDelegate?.id else {
            return nil
        }
        
        return .init(portId: self.id.portId,
                     canvasId: canvasId)
    }
    
    @MainActor
    func initializeValues(rowDelegate: Self.RowObserver) {
        let activeIndex = rowDelegate.nodeDelegate?.activeIndex ?? .init(.zero)
        
        self.activeValue = PortValue.getActiveValue(allLoopedValues: rowDelegate.allLoopedValues,
                                                    activeIndex: activeIndex)
        self.createFieldValueTypes(initialValue: self.activeValue,
                                   nodeIO: Self.nodeIO,
                                   importedMediaObject: nil)
    }
    
    @MainActor
    func didPortValuesUpdate(values: PortValues) {
        if self.id.graphItemType == .layerInspector(.anchoring) {
            log("had anchoring")
        }
        
        guard let rowDelegate = self.rowDelegate else {
            return
        }
        
        let activeIndex = rowDelegate.nodeDelegate?.activeIndex ?? .init(.zero)
        let isLayerFocusedInPropertySidebar = rowDelegate.nodeDelegate?.graphDelegate?.layerFocusedInPropertyInspector == rowDelegate.id.nodeId
        let oldViewValue = self.activeValue // the old cached
        let newViewValue = PortValue.getActiveValue(allLoopedValues: values,
                                                          activeIndex: activeIndex)
        let didViewValueChange = oldViewValue != newViewValue
        
        /*
         Conditions for forcing fields update:
         1. Is at time of initialization--used for layers, or
         2. Did values change AND visible in frame, or
         3. Is this an input for a layer node that is focused in the property sidebar?
         */
        let shouldUpdate = didViewValueChange || isLayerFocusedInPropertySidebar

        if shouldUpdate {
            self.activeValue = newViewValue
            
            // TODO: pass in media to here!
            self.activeValueChanged(oldValue: oldViewValue,
                                    newValue: newViewValue)
        }
    }
    
    @MainActor
    func updatePortColor() {
        let newColor = self.calculatePortColor()
        self.setPortColorIfChanged(newColor)
    }
    
    var hasEdge: Bool {
        rowDelegate?.hasEdge ?? false
    }
    
    var hasLoop: Bool {
        rowDelegate?.hasLoopedValues ?? false
    }
}

extension PortValue {
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
}

// UI data
@Observable
final class InputNodeRowViewModel: NodeRowViewModel {
    typealias PortViewType = InputPortViewData
    
    static let nodeIO: NodeIO = .input
    
    var id: NodeRowViewModelId
    var activeValue: PortValue = .number(.zero)
    var fieldValueTypes = FieldGroupTypeViewModelList<InputFieldViewModel>()
    var anchorPoint: CGPoint?
    var connectedCanvasItems: Set<CanvasItemId> = .init()
    var portColor: PortColor = .noEdge
    weak var nodeDelegate: NodeDelegate?
    weak var rowDelegate: InputNodeRowObserver?
    weak var canvasItemDelegate: CanvasItemViewModel? // also nil when the layer input is not on the canvas
    
    // TODO: temporary property for old-style layer nodes
    var layerPortId: Int?
    
    @MainActor
    init(id: NodeRowViewModelId,
         activeValue: PortValue,
         nodeDelegate: NodeDelegate?,
         rowDelegate: InputNodeRowObserver?,
         canvasItemDelegate: CanvasItemViewModel?) {
        if !FeatureFlags.USE_LAYER_INSPECTOR && id.graphItemType.isLayerInspector {
            fatalErrorIfDebug()
        }
        
        self.id = id
        self.nodeDelegate = nodeDelegate
        self.rowDelegate = rowDelegate
        self.canvasItemDelegate = canvasItemDelegate
        
        if let rowDelegate = rowDelegate {
            self.initializeValues(rowDelegate: rowDelegate)
        }
    }
}

extension InputNodeRowViewModel {
    @MainActor
    func findConnectedCanvasItems() -> CanvasItemIdSet {
        guard let upstreamOutputObserver = self.rowDelegate?.upstreamOutputObserver,
              let upstreamNodeRowViewModel = upstreamOutputObserver.nodeRowViewModel,
              let upstreamId = upstreamNodeRowViewModel.canvasItemDelegate?.id else {
            return .init()
        }
        
        return Set([upstreamId])
    }
    
    @MainActor
    func calculatePortColor() -> PortColor {
        let isEdgeSelected = self.hasSelectedEdge()
        
        // Note: inputs always ignore actively-drawn or animated (edge-edit-mode) edges etc.
        let isSelected = self.isCanvasItemSelected ||
            self.isConnectedToASelectedCanvasItem ||
            isEdgeSelected
        return .init(isSelected: isSelected,
                     hasEdge: hasEdge,
                     hasLoop: hasLoop)
    }
    
    @MainActor 
    func hasSelectedEdge() -> Bool {
        guard let portViewData = portViewData,
              let graphDelegate = graphDelegate else {
            return false
        }
        
        return graphDelegate.selectedEdges.contains { $0.to == portViewData }
    }
}

@Observable
final class OutputNodeRowViewModel: NodeRowViewModel {
    typealias PortViewType = OutputPortViewData
    
    static let nodeIO: NodeIO = .output
    
    var id: NodeRowViewModelId
    var activeValue: PortValue = .number(.zero)
    var fieldValueTypes = FieldGroupTypeViewModelList<OutputFieldViewModel>()
    var anchorPoint: CGPoint?
    var connectedCanvasItems: Set<CanvasItemId> = .init()
    var portColor: PortColor = .noEdge
    weak var nodeDelegate: NodeDelegate?
    weak var rowDelegate: OutputNodeRowObserver?
    weak var canvasItemDelegate: CanvasItemViewModel?
    
    @MainActor
    init(id: NodeRowViewModelId,
         activeValue: PortValue,
         nodeDelegate: NodeDelegate?,
         rowDelegate: OutputNodeRowObserver?,
         canvasItemDelegate: CanvasItemViewModel?) {
        self.id = id
        self.nodeDelegate = nodeDelegate
        self.rowDelegate = rowDelegate
        self.canvasItemDelegate = canvasItemDelegate
        
        if let rowDelegate = rowDelegate {
            self.initializeValues(rowDelegate: rowDelegate)
        }
    }
}

extension OutputNodeRowViewModel {
    @MainActor
    func findConnectedCanvasItems() -> CanvasItemIdSet {
        guard let downstreamCanvases = self.rowDelegate?.getConnectedDownstreamNodes() else {
            return .init()
        }
            
        let downstreamCanvasIds = downstreamCanvases.map { $0.id }
        return Set(downstreamCanvasIds)
    }
    
    /// Note: an actively-drawn edge SITS ON TOP OF existing edges. So there is no distinction between port color vs edge color.
    /// An actively-drawn edge's color is determined only by:
    /// 1. "Do we have a loop?" (blue vs theme-color) and
    /// 2. "Do we have an eligible input?" (highlight vs non-highlighted)
    @MainActor
    func calculatePortColor() -> PortColor {
        if let drawingObserver = self.graphDelegate?.edgeDrawingObserver,
           let drawnEdge = drawingObserver.drawingGesture,
           drawnEdge.output.id == self.id {
            return PortColor(
                isSelected: drawingObserver.nearestEligibleInput.isDefined,
                hasEdge: hasEdge,
                hasLoop: hasLoop)
        }
        
        
        // Otherwise, common port color logic applies:
        else {
            let isSelected = self.isCanvasItemSelected ||
                self.isConnectedToASelectedCanvasItem ||
                self.hasSelectedEdge()
            return PortColor(isSelected: isSelected,
                         hasEdge: hasEdge,
                         hasLoop: hasLoop)
        }
    }
    
    @MainActor func hasSelectedEdge() -> Bool {
        guard let portViewData = portViewData,
              let graphDelegate = graphDelegate else {
            return false
        }
        
        return graphDelegate.selectedEdges.contains { $0.from == portViewData }
    }
}

extension Array where Element: NodeRowViewModel {
    @MainActor
    /// Syncing logic as influced from `SchemaObserverIdentifiable`.
    mutating func sync(with newEntities: [Element.RowObserver],
                       canvas: CanvasItemViewModel) {
        let incomingIds = newEntities.map { $0.id }.toSet
        let currentIds = self.compactMap { $0.rowDelegate?.id }.toSet
        let entitiesToRemove = currentIds.subtracting(incomingIds)

        let currentEntitiesMap = self.reduce(into: [:]) { result, currentEntity in
            result.updateValue(currentEntity, forKey: currentEntity.rowDelegate?.id)
        }

        // Remove element if no longer tracked by incoming list
        entitiesToRemove.forEach { idToRemove in
            self.removeAll { $0.rowDelegate?.id == idToRemove }
        }

        // Create or update entities from new list
        self = newEntities.enumerated().map { portIndex, newEntity in
            if let entity = currentEntitiesMap.get(newEntity.id) {
                return entity
            } else {
                let rowId = NodeRowViewModelId(graphItemType: .node(canvas.id),
                                               // Important this is the node ID from canvas for group nodes
                                               nodeId: canvas.nodeDelegate?.id ?? newEntity.id.nodeId,
                                               portId: portIndex)
                
                return Element(id: rowId,
                               activeValue: newEntity.activeValue, 
                               nodeDelegate: canvas.nodeDelegate, // TODO: is this accurate?
                               rowDelegate: newEntity,
                               canvasItemDelegate: canvas)
            }
        }
    }
}
