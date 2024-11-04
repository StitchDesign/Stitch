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
    case layerInspector(NodeIOPortType) // portId (layer output) or layer-input-type (layer input)
}

extension GraphItemType {
    static let empty: Self = .layerInspector(.keyPath(.init(layerInput: .size,
                                                            portType: .packed)))
    
    var isLayerInspector: Bool {
        switch self {
        case .layerInspector:
            return true
        default:
            return false
        }
    }
    
    var getLayerInputCoordinateOnGraph: LayerInputCoordinate? {
        switch self {
        case .node(let x):
            switch x {
            case .layerInput(let x):
                return x
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

struct NodeRowViewModelId: Hashable {
    var graphItemType: GraphItemType
    var nodeId: NodeId
    
    // TODO: this is always 0 for layer inspector which creates issues for tabbing
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
    
    var portViewData: PortViewType? { get set }
    
    var nodeDelegate: NodeDelegate? { get set }
    
    var rowDelegate: RowObserver? { get set }
    
    var canvasItemDelegate: CanvasItemViewModel? { get set }
    
    static var nodeIO: NodeIO { get }
    
    func calculatePortColor() -> PortColor
    
    @MainActor func portDragged(gesture: DragGesture.Value, graphState: GraphState)
    
    @MainActor func portDragEnded(graphState: GraphState)
    
    @MainActor func hasSelectedEdge() -> Bool
    
    @MainActor func findConnectedCanvasItems() -> CanvasItemIdSet
    
    init(id: NodeRowViewModelId,
         rowDelegate: RowObserver?,
         canvasItemDelegate: CanvasItemViewModel?)
}

extension NodeRowViewModel {
    /// Ignores group nodes to ensure computation logic still works.
    @MainActor
    var computationNode: NodeDelegate? {
        self.rowDelegate?.nodeDelegate
    }
     
    @MainActor
    func initializeDelegate(_ node: NodeDelegate,
                            unpackedPortParentFieldGroupType: FieldGroupType?,
                            unpackedPortIndex: Int?) {
        guard let rowDelegate = self.rowDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        self.nodeDelegate = node
        
        self.initializeValues(rowDelegate: rowDelegate,
                              unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                              unpackedPortIndex: unpackedPortIndex,
                              initialValue: rowDelegate.activeValue)
        
        self.portViewData = self.getPortViewData()
    }
    
    /// Considerable perf cost from `ConnectedEdgeView`, so now a function.
    func getPortViewData() -> PortViewType? {
        guard let canvasId = self.canvasItemDelegate?.id else {
            return nil
        }
        
        return .init(portId: self.id.portId,
                     canvasId: canvasId)
    }
    
    func initializeValues(rowDelegate: Self.RowObserver,
                          unpackedPortParentFieldGroupType: FieldGroupType?,
                          unpackedPortIndex: Int?,
                          initialValue: PortValue) {        
        if initialValue != self.activeValue {
            self.activeValue = initialValue
        }
        
        let fields = self.createFieldValueTypes(initialValue: initialValue,
                                                nodeIO: Self.nodeIO,
                                                unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                                unpackedPortIndex: unpackedPortIndex,
                                                importedMediaObject: nil)
        
        /*
         Note: we seem to call `initializeValues` several times in row for the *same* NodeRowViewModel,
         e.g. when generating an AI project from a prompt "Add 2 + 3", first with initialValue = 0, then again with e.g. initialValue = 2.
         
         The first call creates fields with proper types and values for 0, and the second call creates fields with proper types and values for 2;
         but since the field count and type did not change, the `didFieldsChange` check below prevents us from setting the fields with the new, proper values (2).
         
         It should be fine to set the fields more than once, since presumably `initializeValues` is only called when `NodeRowViewModel` (and parent view models like `CanvasItemViewModel` etc.)
         
         TODO: why do we call `initializeValues` so often?
         */
        //        let didFieldsChange = self.fieldValueTypes.isEmpty || self.fieldValueTypes.first?.type != fields.first?.type
        
        //        if didFieldsChange {
            self.fieldValueTypes = fields
        //        }
    }
    
    @MainActor
    func didPortValuesUpdate(values: PortValues) {
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
    var portViewData: PortViewType?
    weak var nodeDelegate: NodeDelegate?
    weak var rowDelegate: InputNodeRowObserver?
    
    // TODO: input node row view model for an inspector should NEVER have canvasItemDelegate
    weak var canvasItemDelegate: CanvasItemViewModel? // also nil when the layer input is not on the canvas
    
    // TODO: temporary property for old-style layer nodes
    var layerPortId: Int?
    
    init(id: NodeRowViewModelId,
         rowDelegate: InputNodeRowObserver?,
         canvasItemDelegate: CanvasItemViewModel?) {
        self.id = id
        self.nodeDelegate = nodeDelegate
        self.rowDelegate = rowDelegate
        self.canvasItemDelegate = canvasItemDelegate
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
    var portViewData: PortViewType?
    weak var nodeDelegate: NodeDelegate?
    weak var rowDelegate: OutputNodeRowObserver?
    weak var canvasItemDelegate: CanvasItemViewModel?
    
    init(id: NodeRowViewModelId,
         rowDelegate: OutputNodeRowObserver?,
         canvasItemDelegate: CanvasItemViewModel?) {
        self.id = id
        self.nodeDelegate = nodeDelegate
        self.rowDelegate = rowDelegate
        self.canvasItemDelegate = canvasItemDelegate
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
    // easier code search
    mutating func syncRowViewModelsWithCanvasItem(with newEntities: [Element.RowObserver],
                                                  canvas: CanvasItemViewModel,
                                                  unpackedPortParentFieldGroupType: FieldGroupType?,
                                                  unpackedPortIndex: Int?) {
        self.sync(with: newEntities,
                  canvas: canvas,
                  unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                  unpackedPortIndex: unpackedPortIndex)
    }
    
    // TODO: This is impossible to find via a code search; too many methods are called `sync`
    /// Syncing logic as influced from `SchemaObserverIdentifiable`.
    mutating func sync(with newEntities: [Element.RowObserver],
                       canvas: CanvasItemViewModel,
                       unpackedPortParentFieldGroupType: FieldGroupType?,
                       unpackedPortIndex: Int?) {
        
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
                // Update index if ports for node were removed
                entity.id = .init(graphItemType: entity.id.graphItemType,
                                  nodeId: entity.id.nodeId,
                                  portId: portIndex)
                
                return entity
            } else {
                let rowId = NodeRowViewModelId(graphItemType: .node(canvas.id),
                                               // Important this is the node ID from canvas for group nodes
                                               nodeId: canvas.nodeDelegate?.id ?? newEntity.id.nodeId,
                                               portId: portIndex)
                
                let rowViewModel = Element(id: rowId,
                                           rowDelegate: newEntity,
                                           canvasItemDelegate: canvas)
                
                return rowViewModel
            }
        }
    }
}
