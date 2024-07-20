//
//  NodeRowViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/26/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

enum GraphItemType {
    case node
    case layerInspector
}

struct NodeRowViewModelId: Hashable {
    var graphItemType: GraphItemType
    var nodeId: NodeId
    var portType: NodeIOPortType
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
    
    static let empty: Self = .init(graphItemType: .node,
                                   nodeId: .init(),
                                   portType: .portIndex(-1))
    
    var coordinate: NodeIOCoordinate {
        .init(portType: self.portType,
              nodeId: self.nodeId)
    }
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
    
    var rowDelegate: RowObserver? { get set }
    
    var canvasItemDelegate: CanvasItemViewModel? { get set }
    
//    var portViewType: PortViewType { get }
    
    // Saves the port index if there's a node
    var nodeRowIndex: Int? { get set }
    
    static var nodeIO: NodeIO { get }
    
    @MainActor func calculatePortColor() -> PortColor
    
    @MainActor func portDragged(gesture: DragGesture.Value, graphState: GraphState)
    
    @MainActor func portDragEnded(graphState: GraphState)
    
    @MainActor func hasSelectedEdge() -> Bool
}

extension NodeRowViewModel {
    var portType: NodeIOPortType {
        self.id.portType
    }
    
    var portViewData: PortViewType? {
        guard let nodeRowIndex = self.nodeRowIndex,
              let canvasId = self.canvasItemDelegate?.id else {
            return nil
        }
        
        return .init(portId: nodeRowIndex,
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
    var nodeRowIndex: Int?
    var anchorPoint: CGPoint?
    var connectedCanvasItems: Set<CanvasItemId> = .init()
    var portColor: PortColor = .noEdge
    weak var rowDelegate: InputNodeRowObserver?
    weak var canvasItemDelegate: CanvasItemViewModel?
    
    // TODO: temporary property for old-style layer nodes
    var layerPortId: Int?
    
    @MainActor
    init(id: NodeRowViewModelId,
         activeValue: PortValue,
         nodeRowIndex: Int?,
         rowDelegate: InputNodeRowObserver?,
         canvasItemDelegate: CanvasItemViewModel?) {
        if !FeatureFlags.USE_LAYER_INSPECTOR && id.graphItemType == .layerInspector {
            fatalErrorIfDebug()
        }
        
        self.id = id
        self.nodeRowIndex = nodeRowIndex
        self.rowDelegate = rowDelegate
        self.canvasItemDelegate = canvasItemDelegate
        
        if let rowDelegate = rowDelegate {
            self.initializeValues(rowDelegate: rowDelegate)
        }
    }

//    @MainActor
//    var connectedUpstreamCanvasItem: CanvasItemViewModel? {
//        guard let upstreamOutputObserver = self.rowDelegate?.upstreamOutputObserver else {
//            return nil
//        }
//        
//        return upstreamOutputObserver.rowViewModel.canvasItemDelegate
//    }
    
//    var portViewType: PortViewType { .input(self.id) }
    
    func calculatePortColor() -> PortColor {
        let isEdgeSelected = self.hasSelectedEdge()
        
        // Note: inputs always ignore actively-drawn or animated (edge-edit-mode) edges etc.
        return .init(isSelected: self.isCanvasItemSelected ||
                     self.isConnectedToASelectedCanvasItem ||
                     isEdgeSelected,
                     hasEdge: hasEdge,
                     hasLoop: hasLoop)
    }
    
    @MainActor func hasSelectedEdge() -> Bool {
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
    var nodeRowIndex: Int?
    var anchorPoint: CGPoint?
    var connectedCanvasItems: Set<CanvasItemId> = .init()
    var portColor: PortColor = .noEdge
    weak var rowDelegate: OutputNodeRowObserver?
    weak var canvasItemDelegate: CanvasItemViewModel?
    
    @MainActor
    init(id: NodeRowViewModelId,
         activeValue: PortValue,
         nodeRowIndex: Int?,
         rowDelegate: OutputNodeRowObserver?,
         canvasItemDelegate: CanvasItemViewModel?) {
        self.id = id
        self.nodeRowIndex = nodeRowIndex
        self.rowDelegate = rowDelegate
        self.canvasItemDelegate = canvasItemDelegate
        
        if let rowDelegate = rowDelegate {
            self.initializeValues(rowDelegate: rowDelegate)
        }
    }
    
//    var portViewType: PortViewType { .output(self.id) }
    
    /// Note: an actively-drawn edge SITS ON TOP OF existing edges. So there is no distinction between port color vs edge color.
    /// An actively-drawn edge's color is determined only by:
    /// 1. "Do we have a loop?" (blue vs theme-color) and
    /// 2. "Do we have an eligible input?" (highlight vs non-highlighted)
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
            return PortColor(isSelected: self.isCanvasItemSelected ||
                             self.isConnectedToASelectedCanvasItem ||
                             self.hasSelectedEdge(),
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

