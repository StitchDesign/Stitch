//
//  NodeRowViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/26/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit


protocol NodeRowViewModel: StitchLayoutCachable, Observable, Identifiable {
    associatedtype FieldType: FieldViewModel where FieldType.NodeRowType == Self
    associatedtype RowObserver: NodeRowObserver
    associatedtype PortViewType: PortViewData
    
    var id: NodeRowViewModelId { get }
    
    // View-specific value that only updates when visible
    // separate propety for perf reasons:
    @MainActor var activeValue: PortValue { get set }
    
    // Holds view models for fields
    @MainActor var fieldValueTypes: [FieldGroupTypeData<FieldType>] { get set }
    
    @MainActor var connectedCanvasItems: Set<CanvasItemId> { get set }
    
    @MainActor var anchorPoint: CGPoint? { get set }
    
    @MainActor var portColor: PortColor { get set }
    
    @MainActor var portViewData: PortViewType? { get set }
    
    @MainActor var isDragging: Bool { get set }
    
    @MainActor var nodeDelegate: NodeDelegate? { get set }
    
    @MainActor var rowDelegate: RowObserver? { get set }
    
    @MainActor var canvasItemDelegate: CanvasItemViewModel? { get set }
    
    static var nodeIO: NodeIO { get }
    
    @MainActor func calculatePortColor() -> PortColor
    
    @MainActor func portDragged(gesture: DragGesture.Value, graphState: GraphState)
    
    @MainActor func portDragEnded(graphState: GraphState)
    
    @MainActor func hasSelectedEdge() -> Bool
    
    @MainActor func findConnectedCanvasItems() -> CanvasItemIdSet
    
    @MainActor
    init(id: NodeRowViewModelId,
         rowDelegate: RowObserver?,
         canvasItemDelegate: CanvasItemViewModel?)
}

extension NodeRowViewModel {
    @MainActor
    func updateAnchorPoint() {
        guard let canvas = self.canvasItemDelegate,
              let node = canvas.nodeDelegate,
              let size = canvas.sizeByLocalBounds else {
            return
        }
        
        let ioAdjustment: CGFloat = 10
        let standardHeightAdjustment: CGFloat = 69
        let ioConstraint: CGFloat = Self.nodeIO == .input ? ioAdjustment : -ioAdjustment
        let titleHeightOffset: CGFloat = node.hasLargeCanvasTitleSpace ? 23 : 0
        
        // Offsets needed because node position uses its center location
        let offsetX: CGFloat = canvas.position.x + ioConstraint - size.width / 2
        let offsetY: CGFloat = canvas.position.y - size.height / 2 + standardHeightAdjustment + titleHeightOffset
        
        let anchorY = offsetY + CGFloat(self.id.portId) * 28
        
        switch Self.nodeIO {
        case .input:
            self.anchorPoint = .init(x: offsetX, y: anchorY)
        case .output:
            self.anchorPoint = .init(x: offsetX + size.width, y: anchorY)
        }
    }
    
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
        
        if self.fieldValueTypes.isEmpty {
            self.initializeValues(rowDelegate: rowDelegate,
                                  unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                  unpackedPortIndex: unpackedPortIndex,
                                  initialValue: rowDelegate.getActiveValue(activeIndex: node.graphDelegate?.documentDelegate?.activeIndex ?? .init(.zero)))
        }
        
        self.portViewData = self.getPortViewData()
    }
    
    /// Considerable perf cost from `ConnectedEdgeView`, so now a function.
    @MainActor
    func getPortViewData() -> PortViewType? {
        guard let canvasId = self.canvasItemDelegate?.id else {
            return nil
        }
        
        return .init(portId: self.id.portId,
                     canvasId: canvasId)
    }
    
    @MainActor
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
                                                unpackedPortIndex: unpackedPortIndex)
        
//        let didFieldsChange = !zip(self.fieldValueTypes, fields).allSatisfy { $0 == $1 }
        
        self.fieldValueTypes = fields
//        if self.fieldValueTypes.isEmpty || didFieldsChange {
//        }
    }
    
    @MainActor
    func didPortValuesUpdate(values: PortValues) {
        guard let rowDelegate = self.rowDelegate else {
            return
        }
        
        let activeIndex = rowDelegate.nodeDelegate?.graphDelegate?.documentDelegate?.activeIndex ?? .init(.zero)
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

            self.activeValueChanged(oldValue: oldViewValue,
                                    newValue: newViewValue)
        }
    }
    
    @MainActor
    func updatePortColor() {
        let newColor = self.calculatePortColor()
        self.setPortColorIfChanged(newColor)
    }
    
    @MainActor
    var hasEdge: Bool {
        rowDelegate?.hasEdge ?? false
    }
    
    @MainActor
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


extension CanvasItemViewModel {
    // TODO: This is impossible to find via a code search; too many methods are called `sync`
    /// Syncing logic as influced from `SchemaObserverIdentifiable`.
    @MainActor
    func syncRowViewModels<RowViewModel>(with newEntities: [RowViewModel.RowObserver],
                                         keyPath: ReferenceWritableKeyPath<CanvasItemViewModel, [RowViewModel]>,
                                         unpackedPortParentFieldGroupType: FieldGroupType?,
                                         unpackedPortIndex: Int?) where RowViewModel: NodeRowViewModel {
        
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
                    let rowId = NodeRowViewModelId(graphItemType: .node(canvas.id),
                                                   // Important this is the node ID from canvas for group nodes
                                                   nodeId: canvas.nodeDelegate?.id ?? newEntity.id.nodeId,
                                                   portId: portIndex)
                    
                    let rowViewModel = RowViewModel(id: rowId,
                                                    rowDelegate: newEntity,
                                                    canvasItemDelegate: canvas)
                    
                    return rowViewModel
                }
            }
        }
    }
}
