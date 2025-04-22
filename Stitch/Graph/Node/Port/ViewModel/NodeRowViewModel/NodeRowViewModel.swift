//
//  NodeRowViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/26/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

protocol NodeRowViewModel: Observable, Identifiable, AnyObject, Sendable {

    associatedtype RowObserver: NodeRowObserver
    // fka `PortViewType`
    associatedtype PortAddressType: PortIdAddress
    
    var id: NodeRowViewModelId { get }
    
    static var nodeIO: NodeIO { get }
    
    // MARK: cached ui-data derived from underlying row observer
    
    @MainActor var cachedActiveValue: PortValue { get set }
    @MainActor var cachedFieldValueGroups: [FieldGroup] { get set } // fields
    
    
    // MARK: data specific to a draggable port on the canvas; not derived from underlying row observer and not applicable to row view models in the inspector
    
    @MainActor var anchorPoint: CGPoint? { get set }
    @MainActor var portColor: PortColor { get set }
    @MainActor var portAddress: PortAddressType? { get set }
    @MainActor var connectedCanvasItems: CanvasItemIdSet { get set }
        
    // Entrypoint for updating an input or output port's color, often when we don't know whether we specifically have an input or an output.
    // Relies on row VM's non-nil canvas id, portViewData, connectedCanvasItems
    @MainActor func calculatePortColor(
        // Restriction on type of row view model (canvas only, never inspector)
        canvasItemId: CanvasItemId,
        
        // Facts from the underlying row observer
        hasEdge: Bool,
        hasLoop: Bool,
        
        // Facts from the graph
        selectedEdges: Set<PortEdgeUI>,
        selectedCanvasItems: CanvasItemIdSet,
        // output only
        drawingObserver: EdgeDrawingObserver
    ) -> PortColor

    
    // MARK: delegates, weak references to parents
    
    @MainActor var nodeDelegate: NodeViewModel? { get set }
    @MainActor var rowDelegate: RowObserver? { get set }
    @MainActor var canvasItemDelegate: CanvasItemViewModel? { get set }
    
    @MainActor
    init(id: NodeRowViewModelId,
         initialValue: PortValue,
         rowDelegate: RowObserver?,
         canvasItemDelegate: CanvasItemViewModel?)
}


@MainActor
func getNewAnchorPoint(canvasPosition: CGPoint,
                       canvasSize: CGSize,
                       hasLargeCanvasTitle: Bool,
                       nodeIO: NodeIO,
                       portId: Int) -> CGPoint {
    
    let ioAdjustment: CGFloat = 10
    let standardHeightAdjustment: CGFloat = 69
    let ioConstraint: CGFloat = nodeIO == .input ? ioAdjustment : -ioAdjustment
    let titleHeightOffset: CGFloat = hasLargeCanvasTitle ? 23 : 0
    
    // Offsets needed because node position uses its center location
    let offsetX: CGFloat = canvasPosition.x + ioConstraint - canvasSize.width / 2
    let offsetY: CGFloat = canvasPosition.y - canvasSize.height / 2 + standardHeightAdjustment + titleHeightOffset
    
    let anchorY = offsetY + CGFloat(portId) * 28
    
    switch nodeIO {
    case .input:
        return CGPoint(x: offsetX, y: anchorY)
    case .output:
        return CGPoint(x: offsetX + canvasSize.width, y: anchorY)
    }
}

extension NodeRowViewModel {

    @MainActor
    func initializeDelegate(_ node: NodeViewModel,
                            initialValue: PortValue,
                            unpackedPortParentFieldGroupType: FieldGroupType?,
                            unpackedPortIndex: Int?,
                            layerInput: LayerInputPort?) {
        
        // Why must we set the delegate
        self.nodeDelegate = node
        
        if self.cachedFieldValueGroups.isEmpty {
            self.initializeValues(
                unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                unpackedPortIndex: unpackedPortIndex,
                initialValue: initialValue,
                rowObserverLayerInput: layerInput)
        }
                
        /// Considerable perf cost from `ConnectedEdgeView`, so now a function.
        if let canvasId = self.canvasItemDelegate?.id {
            let newPortAddress: PortAddressType = .init(portId: self.id.portId,
                                                        canvasId: canvasId)
            if self.portAddress != newPortAddress {
                self.portAddress = newPortAddress
            }
        }
    }
        
    @MainActor
    func initializeValues(unpackedPortParentFieldGroupType: FieldGroupType?,
                          unpackedPortIndex: Int?,
                          initialValue: PortValue,
                          rowObserverLayerInput: LayerInputPort?) {
        if initialValue != self.cachedActiveValue {
            self.cachedActiveValue = initialValue
        }
        
        let fields = self.createFieldValueTypes(
            initialValue: initialValue,
            nodeIO: Self.nodeIO,
            unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
            unpackedPortIndex: unpackedPortIndex,
            layerInput: rowObserverLayerInput)
        
        let didFieldsChange = !zip(self.cachedFieldValueGroups, fields).allSatisfy { $0.id == $1.id }
        
        if self.cachedFieldValueGroups.isEmpty || didFieldsChange {
            self.cachedFieldValueGroups = fields
        }
    }
    
    @MainActor
    func didPortValuesUpdate(values: PortValues,
                             layerFocusedInPropertyInspector: NodeId?,
                             activeIndex: ActiveIndex) {
                
        let isLayerFocusedInPropertySidebar = layerFocusedInPropertyInspector == self.id.nodeId
        
        let oldViewValue = self.cachedActiveValue // the old cached value
        let newViewValue = PortValue.getActiveValue(allLoopedValues: values,
                                                    activeIndex: activeIndex)
        
        let didViewValueChange = oldViewValue != newViewValue
        
        let shouldUpdate = didViewValueChange || isLayerFocusedInPropertySidebar

        if shouldUpdate {
            self.cachedActiveValue = newViewValue
            self.activeValueChanged(oldValue: oldViewValue,
                                    newValue: newViewValue)
        }
    }
    
    @MainActor
    func updatePortColor(canvasItemId: CanvasItemId,
                         hasEdge: Bool,
                         hasLoop: Bool,
                         selectedEdges: Set<PortEdgeUI>,
                         selectedCanvasItems: CanvasItemIdSet,
                         drawingObserver: EdgeDrawingObserver) {
                
        let newColor = self.calculatePortColor(canvasItemId: canvasItemId,
                                               hasEdge: hasEdge,
                                               hasLoop: hasLoop,
                                               selectedEdges: selectedEdges,
                                               selectedCanvasItems: selectedCanvasItems,
                                               drawingObserver: drawingObserver)
        self.setPortColorIfChanged(newColor)
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


extension CanvasItemViewModel {
    // TODO: This is impossible to find via a code search; too many methods are called `sync`
    /// Syncing logic as influced from `SchemaObserverIdentifiable`.
    @MainActor
    func syncRowViewModels<RowViewModel>(with newEntities: [RowViewModel.RowObserver],
                                         keyPath: ReferenceWritableKeyPath<CanvasItemViewModel, [RowViewModel]>,
                                         activeIndex: ActiveIndex) where RowViewModel: NodeRowViewModel {
        
        let canvas = self
        let incomingIds = newEntities.map { $0.id }.toSet
        let currentIds = self[keyPath: keyPath].compactMap { $0.rowDelegate?.id }.toSet
        
        let entitiesToRemove = currentIds.subtracting(incomingIds)

        let currentEntitiesMap = self[keyPath: keyPath].reduce(into: [:]) { result, currentEntity in
            result.updateValue(currentEntity, forKey: currentEntity.rowDelegate?.id)
        }

        // Remove element if no longer tracked by incoming list
        entitiesToRemove.forEach { idToRemove in
            self[keyPath: keyPath].removeAll { $0.rowDelegate?.id == idToRemove }
        }

        // Create or update entities from new list
        let didCurrentEntitiesChange = newEntities.contains {
            // If no entity found, we have a change
            currentEntitiesMap.get($0.id) == nil
        }
        
        // MARK: only self-assign if anything changed or else there will be extra render cycles
        if didCurrentEntitiesChange {
            self[keyPath: keyPath] = newEntities.enumerated().map { portIndex, newEntity in
                if let entity = currentEntitiesMap.get(newEntity.id) {
                    return entity
                } else {
                    let rowId = NodeRowViewModelId(graphItemType: .canvas(canvas.id),
                                                   // Important this is the node ID from canvas for group nodes
                                                   nodeId: canvas.nodeDelegate?.id ?? newEntity.id.nodeId,
                                                   portId: portIndex)
                    
                    let rowViewModel = RowViewModel(id: rowId,
                                                    initialValue: newEntity.getActiveValue(activeIndex: activeIndex),
                                                    rowDelegate: newEntity,
                                                    canvasItemDelegate: canvas)
                    
                    return rowViewModel
                }
            }
        }
    }
}
