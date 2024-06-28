//
//  NodeRowViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/26/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

protocol NodeRowViewModel: AnyObject, Identifiable {
    associatedtype FieldType: FieldViewModel
    
    var id: FieldType.PortId { get set }
    
    // View-specific value that only updates when visible
    // separate propety for perf reasons:
    var activeValue: PortValue { get set }
    
    // Holds view models for fields
    var fieldValueTypes: FieldGroupTypeViewModelList<FieldType> { get set }
    
    var anchorPoint: CGPoint? { get set }
    
    var connectedCanvasItems: Set<CanvasItemId> { get set }
    
    var rowDelegate: NodeRowObserver? { get set }
    
    @MainActor func retrieveConnectedCanvasItems() -> Set<CanvasItemId>
}

extension NodeRowViewModel {
    @MainActor
    func initializeValues(rowDelegate: NodeRowObserver,
                          coordinate: Self.FieldType.PortId) {
        let activeIndex = rowDelegate.nodeDelegate?.activeIndex ?? .init(.zero)
        
        self.activeValue = Self.getActiveValue(allLoopedValues: rowDelegate.allLoopedValues,
                                               activeIndex: activeIndex)
        self.fieldValueTypes = self
            .createFieldValueTypes(initialValue: self.activeValue,
                                   coordinate: coordinate,
                                   nodeIO: rowDelegate.nodeIOType,
                                   importedMediaObject: nil)
    }
    
    @MainActor
    func didPortValuesUpdate(values: PortValues,
                             rowDelegate: NodeRowObserver) {
        let activeIndex = rowDelegate.nodeDelegate?.activeIndex ?? .init(.zero)
        let isLayerFocusedInPropertySidebar = rowDelegate.nodeDelegate?.graphDelegate?.layerFocusedInPropertyInspector == rowDelegate.id.nodeId
        
        let oldViewValue = self.activeValue // the old cached
        let newViewValue = Self.getActiveValue(allLoopedValues: values,
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
}

extension NodeRowViewModel {
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
    var id: InputPortViewData
    var activeValue: PortValue = .number(.zero)
    var fieldValueTypes = FieldGroupTypeViewModelList<InputFieldViewModel>()
    var anchorPoint: CGPoint?
    var connectedCanvasItems: Set<CanvasItemId>
    weak var rowDelegate: NodeRowObserver?
    
    @MainActor
    init(id: InputPortViewData,
         activeValue: PortValue,
         rowDelegate: NodeRowObserver) {
        self.id = id
        self.rowDelegate = rowDelegate
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
}

final class OutputNodeRowViewModel: NodeRowViewModel {
    var id: OutputPortViewData
    var activeValue: PortValue = .number(.zero)
    var fieldValueTypes = FieldGroupTypeViewModelList<OutputFieldViewModel>()
    var anchorPoint: CGPoint?
    var connectedCanvasItems: Set<CanvasItemId>
    weak var rowDelegate: NodeRowObserver?
    
    @MainActor
    init(id: OutputPortViewData,
         activeValue: PortValue,
         rowDelegate: NodeRowObserver) {
        self.id = id
        self.rowDelegate = rowDelegate
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
}

