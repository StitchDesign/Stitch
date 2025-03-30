//
//  PortValueObserver.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/26/23.
//

import Foundation
import StitchSchemaKit
import StitchEngine


extension NodeIOPortType: Identifiable {
    public var id: Int {
        switch self {
        case .keyPath(let x):
            return x.hashValue
        case .portIndex(let x):
            return x
        }
    }
}

extension NodeIOCoordinate: NodeRowId {
    public var id: Int {
        self.nodeId.hashValue + self.portType.id
    }
}

extension NodeIOCoordinate: Sendable { }

extension PortValue: Sendable { }



protocol NodeRowObserver: AnyObject, Observable, Identifiable, Sendable, NodeRowCalculatable {
    associatedtype RowViewModelType: NodeRowViewModel
    
    var id: NodeIOCoordinate { get }
    
    // Data-side for values
    @MainActor var allLoopedValues: PortValues { get set }
    
    static var nodeIOType: NodeIO { get }
    
    @MainActor var allRowViewModels: [RowViewModelType] { get }
    
    @MainActor
    var nodeDelegate: NodeDelegate? { get set }
    
    @MainActor
    var connectedNodes: NodeIdSet { get set }
    
    @MainActor
    var hasLoopedValues: Bool { get set }
    
//    @MainActor var importedMediaObject: StitchMediaObject? { get }
    
    @MainActor
    var hasEdge: Bool { get }
    
    @MainActor
    init(values: PortValues,
         id: NodeIOCoordinate,
         upstreamOutputCoordinate: NodeIOCoordinate?)
    
    // OUTPUT ONLY
    @MainActor
    func kickOffPulseReversalSideEffects()
}

extension NodeRowObserver {
    @MainActor
    var nodeKind: NodeKind {
        guard let nodeKind = self.nodeDelegate?.kind else {
            // Gets called on layer deletion, commenting out fatal error
//            fatalErrorIfDebug()
            return .patch(.splitter)
        }
        
        return nodeKind
    }
}

extension NodeRowViewModel {
    var isLayerInspector: Bool {
        self.id.graphItemType.isLayerInspector
    }
    
    /// Called by parent node view model to update fields.
    @MainActor
    func activeValueChanged(oldValue: PortValue,
                            newValue: PortValue) {
        let nodeIO = Self.RowObserver.nodeIOType
        let oldRowType = oldValue.getNodeRowType(nodeIO: nodeIO,
                                                 layerInputPort: self.id.layerInputPort,
                                                 isLayerInspector: self.isLayerInspector)
        self.activeValueChanged(oldRowType: oldRowType,
                                newValue: newValue)
    }
    
    /// Called by parent node view model to update fields.
    @MainActor
    func activeValueChanged(oldRowType: NodeRowType,
                            newValue: PortValue) {
    
        let nodeIO = Self.RowObserver.nodeIOType

        let newRowType = newValue.getNodeRowType(nodeIO: nodeIO,
                                                 layerInputPort: self.id.layerInputPort,
                                                 isLayerInspector: self.isLayerInspector)
        let nodeRowTypeChanged = oldRowType != newRowType
        
        // Create new field value observers if the row type changed
        // This can happen on various input changes
        guard !nodeRowTypeChanged else {
            self.fieldValueTypes = self.createFieldValueTypes(
                initialValue: newValue,
                nodeIO: nodeIO,
                // Node Row Type change is only when a patch node changes its node type; can't happen for layer nodes
                unpackedPortParentFieldGroupType: nil,
                unpackedPortIndex: nil)
            return
        }
        
        self.updateFields(newValue)
    }
    
    @MainActor
    func updateFields(_ newValue: PortValue) {
        
        let nodeIO = Self.RowObserver.nodeIOType
        
        guard let rowDelegate = self.rowDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        let newFieldsByGroup = newValue.createFieldValuesList(nodeIO: nodeIO, rowViewModel: self)
        
        // Assert equal array counts
        guard newFieldsByGroup.count == self.fieldValueTypes.count else {
            log("NodeRowObserver error: incorrect counts of groups.")
            return
        }
        
        zip(self.fieldValueTypes, newFieldsByGroup).forEach { fieldObserverGroup, newFields in
            
            // If existing field observer group's count does not match the new fields count,
            // reset the fields on this input/output.
            // TODO: is this specifically for ShapeCommands, where a dropdown choice (e.g. .lineTo vs .curveTo) can change the number of fields without a node-type change?
            let fieldObserversCount = fieldObserverGroup.fieldObservers.count
            
            // Force update if any media--inefficient but works
//            let isMediaField = fieldObserverGroup.type == .asyncMedia
            let willUpdateFieldsCount = newFields.count != fieldObserversCount // || isMediaField
            
            if willUpdateFieldsCount {
                self.fieldValueTypes = self.createFieldValueTypes(
                    initialValue: newValue,
                    nodeIO: nodeIO,
                    // Note: this is only for a patch node whose node-type has changed (?); does not happen with layer nodes, a layer input being packed or unpacked is irrelevant here etc.
                    // Not relevant?
                    unpackedPortParentFieldGroupType: nil,
                    unpackedPortIndex:  nil)
                return
            }
            
            fieldObserverGroup.updateFieldValues(fieldValues: newFields)
        } // zip
        
        if let node = self.nodeDelegate,
           let layerNode = node.layerNodeViewModel,
           // Better?: use: `self.id.portType.keyPath`
           let layerInputForThisRow: LayerInputType = rowDelegate.id.keyPath {
            layerNode.blockOrUnblockFields(newValue: newValue,
                                           layerInput: layerInputForThisRow.layerInput,
                                           activeIndex: self.graphDelegate?.documentDelegate?.activeIndex ?? .init(.zero))
        }
    }
}

extension NodeRowObserver {
    @MainActor
    init(values: PortValues,
         id: NodeIOCoordinate,
         upstreamOutputCoordinate: NodeIOCoordinate?,
         nodeDelegate: NodeDelegate) {
        self.init(values: values,
                  id: id,
                  upstreamOutputCoordinate: upstreamOutputCoordinate)
        self.initializeDelegate(nodeDelegate)
    }
    
    @MainActor
    func initializeDelegate(_ node: NodeDelegate) {
        self.nodeDelegate = node
        self.postProcessing(oldValues: [], newValues: values)
    }
    
    @MainActor
    var values: PortValues {
        get {
            self.allLoopedValues
        }
        set(newValue) {
            self.allLoopedValues = newValue
        }
    }
    
    /// Finds row view models pertaining to a node, rather than in the layer inspector.
    /// Multiple row view models could exist in the event of a group splitter, where a view model exists for both the splitter
    /// and the parent canvas group. We pick the view model that is currently visible (aka inside the currently focused group).
    @MainActor
    var nodeRowViewModel: RowViewModelType? {
        self.allRowViewModels.first {
            // is for node (rather than layer inspector)
            $0.id.isNode &&
            // is currently visible in selected group
            $0.graphDelegate?.documentDelegate?.groupNodeFocused?.groupNodeId == $0.canvasItemDelegate?.parentGroupNodeId
        }
    }
}

extension Array where Element: NodeRowViewModel {
    @MainActor
    func first(_ id: NodeIOCoordinate) -> Element? {
        self.first { $0.rowDelegate?.id == id }
    }
}
