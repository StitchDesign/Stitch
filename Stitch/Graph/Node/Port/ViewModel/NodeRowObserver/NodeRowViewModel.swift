//
//  NodeRowViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/26/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

protocol NodeRowViewModel: AnyObject, Observable, Identifiable {
    associatedtype FieldType: FieldViewModel
    associatedtype RowObserver: NodeRowObserver
    
    var id: NodeIOPortType { get set }
    
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
    
    static var nodeIO: NodeIO { get }
    
    @MainActor func retrieveConnectedCanvasItems() -> Set<CanvasItemId>
    
    @MainActor func calculatePortColor() -> PortColor
}

extension NodeRowViewModel {
    @MainActor
    func initializeValues(rowDelegate: Self.RowObserver,
                          coordinate: Self.FieldType.PortId) {
        let activeIndex = rowDelegate.nodeDelegate?.activeIndex ?? .init(.zero)
        
        self.activeValue = Self.RowObserver.getActiveValue(allLoopedValues: rowDelegate.allLoopedValues,
                                                          activeIndex: activeIndex)
        self.fieldValueTypes = self
            .createFieldValueTypes(initialValue: self.activeValue,
                                   coordinate: coordinate,
                                   nodeIO: Self.nodeIO,
                                   importedMediaObject: nil)
    }
    
    @MainActor
    func didPortValuesUpdate(values: PortValues,
                             rowDelegate: Self.RowObserver) {
        let activeIndex = rowDelegate.nodeDelegate?.activeIndex ?? .init(.zero)
        let isLayerFocusedInPropertySidebar = rowDelegate.nodeDelegate?.graphDelegate?.layerFocusedInPropertyInspector == rowDelegate.id.nodeId
        
        let oldViewValue = self.activeValue // the old cached
        let newViewValue = Self.RowObserver.getActiveValue(allLoopedValues: values,
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

extension NodeRowObserver {
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

final class InputNodeRowViewModel: NodeRowViewModel {
    
    static let nodeIO: NodeIO = .input
    
    var id: NodeIOPortType
    var activeValue: PortValue = .number(.zero)
    var fieldValueTypes = FieldGroupTypeViewModelList<InputFieldViewModel>()
    var anchorPoint: CGPoint?
    var connectedCanvasItems: Set<CanvasItemId>
    var portColor: PortColor = .noEdge
    weak var rowDelegate: InputNodeRowObserver?
    weak var canvasItemDelegate: CanvasItemViewModel?
    
    @MainActor
    init(id: NodeIOPortType,
         activeValue: PortValue,
         rowDelegate: InputNodeRowObserver,
         canvasItemDelegate: CanvasItemViewModel) {
        self.id = id
        self.rowDelegate = rowDelegate
        self.canvasItemDelegate = canvasItemDelegate
        self.initializeValues(rowDelegate: rowDelegate,
                              coordinate: id)
    }
    
    @MainActor
    func retrieveConnectedCanvasItems() -> Set<CanvasItemId> {
       self.getConnectedUpstreamCanvasItems()
    }
    
    @MainActor
    private func getConnectedUpstreamCanvasItems() -> Set<CanvasItemId> {
        guard let upstreamOutputObserver = self.rowDelegate?.upstreamOutputObserver,
              let upstreamNodeDelegate = upstreamOutputObserver.nodeDelegate else {
            return .init()
        }
        
        // Find upstream canvas items whose output view models point to the same
        // upstream row observer
        return upstreamNodeDelegate.getAllCanvasObservers()
            .compactMap { upstreamCanvasItem in
                if upstreamCanvasItem.outputViewModels.contains(where: { outputViewModel in
                    outputViewModel.rowDelegate?.id == upstreamOutputObserver.id
                }) {
                    return upstreamCanvasItem.id
                }
                
                return nil
            }
            .toSet
    }
    
    var portViewType: PortViewType { .input(self.id) }
    
    func calculatePortColor() -> PortColor {
        let isEdgeSelected = graphDelegate?.hasSelectedEdge(at: self) ?? false
        
        // Note: inputs always ignore actively-drawn or animated (edge-edit-mode) edges etc.
        return .init(isSelected: self.isCanvasItemSelected ||
                     self.isConnectedToASelectedCanvasItem ||
                     isEdgeSelected,
                     hasEdge: hasEdge,
                     hasLoop: hasLoop)
    }
}

final class OutputNodeRowViewModel: NodeRowViewModel {
    
    static let nodeIO: NodeIO = .output
    
    var id: OutputPortViewData
    var activeValue: PortValue = .number(.zero)
    var fieldValueTypes = FieldGroupTypeViewModelList<OutputFieldViewModel>()
    var anchorPoint: CGPoint?
    var connectedCanvasItems: Set<CanvasItemId>
    var portColor: PortColor = .noEdge
    weak var rowDelegate: NodeRowObserver?
    weak var canvasItemDelegate: CanvasItemViewModel?
    
    @MainActor
    init(id: OutputPortViewData,
         activeValue: PortValue,
         rowDelegate: NodeRowObserver,
         canvasItemDelegate: CanvasItemViewModel) {
        self.id = id
        self.rowDelegate = rowDelegate
        self.canvasItemDelegate = canvasItemDelegate
        self.initializeValues(rowDelegate: rowDelegate,
                              coordinate: id)
    }
    
    @MainActor
    func retrieveConnectedCanvasItems() -> Set<CanvasItemId> {
        self.getConnectedDownstreamNodes()
    }
    
    @MainActor
    private func getConnectedDownstreamNodes() -> Set<CanvasItemId> {
        var canvasItems = Set<CanvasItemId>()
        let portId = self.id.portId
        
        guard let nodeDelegate = self.rowDelegate?.nodeDelegate,
              let connectedInputs = nodeDelegate.graphDelegate?.connections
            .get(NodeIOCoordinate(portId: portId,
                                  nodeId: nodeDelegate.id)) else {
            return .init()
        }
        
        // Find downstream canvas items whose inputs match connections here
        return connectedInputs.flatMap { inputCoordinate -> [CanvasItemId] in
            guard let node = nodeDelegate.graphDelegate?.getNodeViewModel(inputCoordinate.nodeId),
                  let inputRowObserver = node.getInputRowObserver(for: inputCoordinate.portType) else {
                return []
            }
        
            let canvasItems = node.getAllCanvasObservers()
            return canvasItems.compactMap { canvasItem in
                guard canvasItem.inputViewModels.contains(where: { $0.rowDelegate?.id == inputCoordinate }) else {
                    return nil
                }
                
                return canvasItem.id
            }
        }
        .toSet
    }
    
    var portViewType: PortViewType { .output(self.id) }
    
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
                             graphDelegate?.hasSelectedEdge(at: self) ?? false,
                         hasEdge: hasEdge,
                         hasLoop: hasLoop)
        }
    }
}

