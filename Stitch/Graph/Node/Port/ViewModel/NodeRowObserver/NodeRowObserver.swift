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
            
    @MainActor var nodeDelegate: NodeViewModel? { get set }
    
    // Just for updating port color; cached
    @MainActor
    var hasLoopedValues: Bool { get set }
    
    // Just for updating port color; derived from input's or output's connection
    @MainActor
    var hasEdge: Bool { get }
    
    @MainActor
    init(values: PortValues,
         id: NodeIOCoordinate,
         upstreamOutputCoordinate: NodeIOCoordinate?)
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
            self.cachedFieldValueGroups = self.createFieldValueTypes(
                initialValue: newValue,
                nodeIO: nodeIO,
                // Node Row Type change is only when a patch node changes its node type; can't happen for layer nodes
                unpackedPortParentFieldGroupType: nil,
                unpackedPortIndex: nil,
                layerInput: nil)
            return
        }
        
        self.updateFields(newValue)
    }
    
    // TODO: this needs to take a little more data (layer input's row observer, document's active index, graph state for retrieving layer groups), since update ui-fields' values may require blocking or unblocking other fields
    @MainActor
    func updateFields(_ newValue: PortValue) {
        
        let nodeIO = Self.RowObserver.nodeIOType
                
        let newFieldsByGroup = newValue.createFieldValuesList(nodeIO: nodeIO, rowViewModel: self)
        
        // Assert equal array counts
        guard newFieldsByGroup.count == self.cachedFieldValueGroups.count else {
            log("NodeRowObserver error: incorrect counts of groups.")
            return
        }
        
        zip(self.cachedFieldValueGroups, newFieldsByGroup).forEach { fieldObserverGroup, newFields in
            
            // If existing field observer group's count does not match the new fields count,
            // reset the fields on this input/output.
            // TODO: is this specifically for ShapeCommands, where a dropdown choice (e.g. .lineTo vs .curveTo) can change the number of fields without a node-type change?
            let fieldObserversCount = fieldObserverGroup.fieldObservers.count
            
            // Force update if any media--inefficient but works
//            let isMediaField = fieldObserverGroup.type == .asyncMedia
            let willUpdateFieldsCount = newFields.count != fieldObserversCount // || isMediaField
            
            if willUpdateFieldsCount {
                self.cachedFieldValueGroups = self.createFieldValueTypes(
                    initialValue: newValue,
                    nodeIO: nodeIO,
                    // Note: this is only for a patch node whose node-type has changed (?); does not happen with layer nodes, a layer input being packed or unpacked is irrelevant here etc.
                    // Not relevant?
                    unpackedPortParentFieldGroupType: nil,
                    unpackedPortIndex:  nil,
                    layerInput: nil)
                return
            }
            
            fieldObserverGroup.updateFieldValues(fieldValues: newFields)
        } // zip
        
        
        // Whenever we update ui-fields' values, we need to potentially block or unblock the same/other fields.
        if let node = self.nodeDelegate,
           let graph = node.graphDelegate,
           let layerNode = node.layerNodeReader,
           let activeIndex = graph.documentDelegate?.activeIndex {
            
            layerNode.refreshBlockedInputs(graph: graph, activeIndex: activeIndex)
        }
    }
}

extension NodeRowObserver {
    @MainActor
    init(values: PortValues,
         id: NodeIOCoordinate,
         upstreamOutputCoordinate: NodeIOCoordinate?,
         nodeDelegate: NodeViewModel,
         graph: GraphState) {
        self.init(values: values,
                  id: id,
                  upstreamOutputCoordinate: upstreamOutputCoordinate)
        self.initializeDelegate(nodeDelegate, graph: graph)
    }
    
    @MainActor
    func initializeDelegate(_ node: NodeViewModel, graph: GraphState) {
        self.nodeDelegate = node
        
        // TODO: why do we handle post-processing when we've assigned the nodeDelegate? ... is it just because post-processing requires a nodeDelegate?
        switch Self.nodeIOType {
        case .input:
            self.inputPostProcessing(oldValues: [],
                                     newValues: self.values,
                                     graph: graph)
        case .output:
            self.outputPostProcessing(graph)
        }
                    
        // Update visual color data
        self.allRowViewModels.forEach {
            if let canvasItemId = $0.id.graphItemType.getCanvasItemId {
                $0.updatePortColor(canvasItemId: canvasItemId,
                                   hasEdge: self.hasEdge,
                                   hasLoop: self.hasLoopedValues,
                                   selectedEdges: graph.selectedEdges,
                                   selectedCanvasItems: graph.selection.selectedCanvasItems,
                                   drawingObserver: graph.edgeDrawingObserver)
            }
        }
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
