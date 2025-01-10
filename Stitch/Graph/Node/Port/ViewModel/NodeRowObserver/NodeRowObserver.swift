//
//  PortValueObserver.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/26/23.
//

import Foundation
import StitchSchemaKit
import StitchEngine

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
    
    @MainActor var importedMediaObject: StitchMediaObject? { get }
    
    @MainActor
    var hasEdge: Bool { get }
    
    @MainActor
    init(values: PortValues,
         id: NodeIOCoordinate,
         upstreamOutputCoordinate: NodeIOCoordinate?)
    
    @MainActor
    func didValuesUpdate()
}

extension PortValue: Sendable { }

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

@Observable
final class InputNodeRowObserver: NodeRowObserver, InputNodeRowCalculatable {
    static let nodeIOType: NodeIO = .input

    let id: NodeIOCoordinate
    
    // Data-side for values
    @MainActor
    var allLoopedValues: PortValues = .init()
    
    // Connected upstream node, if input
    @MainActor
    var upstreamOutputCoordinate: NodeIOCoordinate? {
        didSet(oldValue) {
            self.didUpstreamOutputCoordinateUpdate(oldValue: oldValue)
        }
    }
    
    // TODO: an output row can NEVER have an `upstream output` (i.e. incoming edge)
    /// Tracks upstream output row observer for some input. Cached for perf.
    @MainActor
    var upstreamOutputObserver: OutputNodeRowObserver? {
        self.getUpstreamOutputObserver()
    }
    
    // NodeRowObserver holds a reference to its parent, the Node
    @MainActor weak var nodeDelegate: NodeDelegate?

    // MARK: "derived data", cached for UI perf
    
    // Tracks upstream/downstream nodes--cached for perf
    @MainActor var connectedNodes: NodeIdSet = .init()
    
    // Can't be computed for rendering purposes
    @MainActor var hasLoopedValues: Bool = false
    
    @MainActor
    convenience init(from schema: NodePortInputEntity) {
        self.init(values: schema.portData.values ?? [],
                  id: schema.id,
                  upstreamOutputCoordinate: schema.portData.upstreamConnection)
    }
    
    @MainActor
    init(values: PortValues,
         id: NodeIOCoordinate,
         upstreamOutputCoordinate: NodeIOCoordinate?) {
        self.id = id
        self.upstreamOutputCoordinate = upstreamOutputCoordinate
        self.allLoopedValues = values
        self.hasLoopedValues = values.hasLoop
    }
    
    @MainActor
    func didValuesUpdate() { }
}

extension NodeIOCoordinate: Sendable { }

@Observable
final class OutputNodeRowObserver: NodeRowObserver {
    static let nodeIOType: NodeIO = .output
    let containsUpstreamConnection = false  // always false

    // TODO: Outputs can only use portIds, so this should be something more specific than NodeIOCoordinate
    let id: NodeIOCoordinate
    
    // Data-side for values
    @MainActor var allLoopedValues: PortValues = .init()
    
    // NodeRowObserver holds a reference to its parent, the Node
    @MainActor weak var nodeDelegate: NodeDelegate?
    
    // MARK: "derived data", cached for UI perf
    
    // Tracks upstream/downstream nodes--cached for perf
    @MainActor var connectedNodes: NodeIdSet = .init()
    
    // Only for outputs, designed for port edge color usage
    @MainActor var containsDownstreamConnection = false
    
    // Can't be computed for rendering purposes
    @MainActor var hasLoopedValues: Bool = false
    
    // Always nil for outputs
    let importedMediaObject: StitchMediaObject? = nil
    
    @MainActor
    init(values: PortValues,
         id: NodeIOCoordinate,
         // always nil but needed for protocol
         upstreamOutputCoordinate: NodeIOCoordinate? = nil) {
        
        assertInDebug(upstreamOutputCoordinate == nil)
        
        self.id = id
        self.allLoopedValues = values
        self.hasLoopedValues = values.hasLoop
    }
    
    @MainActor
    func didValuesUpdate() {
        let graphTime = self.nodeDelegate?.graphDelegate?.graphStepState.graphTime ?? .zero
        
        // Must also run pulse reversion effects
        self.allLoopedValues
            .getPulseReversionEffects(id: self.id,
                                      graphTime: graphTime)
            .processEffects()
    }
}

extension InputNodeRowObserver {
    @MainActor
    func didUpstreamOutputCoordinateUpdate(oldValue: NodeIOCoordinate?) {
        let coordinateValueChanged = oldValue != self.upstreamOutputCoordinate
        
        guard let upstreamOutputCoordinate = self.upstreamOutputCoordinate else {
            if let oldUpstreamObserver = self.upstreamOutputObserver {
                log("upstreamOutputCoordinate: removing edge")
                
                // Remove edge data
                oldUpstreamObserver.containsDownstreamConnection = false
            }
            
            if coordinateValueChanged {
                // Flatten values
                let newFlattenedValues = self.allLoopedValues.flattenValues()
                self.updateValues(newFlattenedValues)
                
                // Recalculate node once values update
                self.nodeDelegate?.calculate()
            }
            
            return
        }
        
        // Update that upstream observer of new edge
        self.upstreamOutputObserver?.containsDownstreamConnection = true
    }

    /// Values for import dropdowns don't hold media directly, so we need to find it.
    @MainActor var importedMediaObject: StitchMediaObject? {
        guard self.id.portId == 0,
              self.upstreamOutputCoordinate == nil else {
            return nil
        }
        
        if let ephemeralObserver = self.nodeDelegate?.ephemeralObservers?.first,
           let mediaObserver = ephemeralObserver as? MediaEvalOpObservable {
            return mediaObserver.currentMedia?.mediaObject
        }
        
        return nil
    }
    
    // Because `private`, needs to be declared in same file(?) as method that uses it
    @MainActor
    private func getUpstreamOutputObserver() -> OutputNodeRowObserver? {
        guard let upstreamCoordinate = self.upstreamOutputCoordinate,
              let upstreamPortId = upstreamCoordinate.portId else {
            return nil
        }

        // Set current upstream observer
        return self.nodeDelegate?.graphDelegate?.getNodeViewModel(upstreamCoordinate.nodeId)?
            .getOutputRowObserver(upstreamPortId)
    }
    
    @MainActor
    var hasEdge: Bool {
        self.upstreamOutputCoordinate.isDefined
    }
    
    @MainActor var allRowViewModels: [InputNodeRowViewModel] {
        guard let node = self.nodeDelegate else {
            return []
        }
        
        var inputs = [InputNodeRowViewModel]()
        
        switch node.nodeType {
        case .patch(let patchNode):
            guard let portId = self.id.portId,
                  let patchInput = patchNode.canvasObserver.inputViewModels[safe: portId] else {
                // MathExpression is allowed to have empty inputs
                #if DEV_DEBUG || DEBUG
                if patchNode.patch != .mathExpression {
                    fatalErrorIfDebug()
                }
                #endif
                return []
            }
            
            inputs.append(patchInput)
            
            // Find row view models for group if applicable
            if patchNode.splitterNode?.type == .input {
                // Group id is the only other row view model's canvas's parent ID
                if let groupNodeId = inputs.first?.canvasItemDelegate?.parentGroupNodeId,
                   let groupNode = self.nodeDelegate?.graphDelegate?.getNodeViewModel(groupNodeId)?.nodeType.groupNode {
                    inputs += groupNode.inputViewModels.filter {
                        $0.rowDelegate?.id == self.id
                    }
                }
            }
            
        case .layer(let layerNode):
            guard let keyPath = id.keyPath else {
                fatalErrorIfDebug()
                return []
            }
            
            let port = layerNode[keyPath: keyPath.layerNodeKeyPath]
            inputs.append(port.inspectorRowViewModel)
            
            if let canvasInput = port.canvasObserver?.inputViewModels.first {
                inputs.append(canvasInput)
            }
            
        case .group(let canvas):
            guard let portId = self.id.portId,
                  let groupInput = canvas.inputViewModels[safe: portId] else {
                fatalErrorIfDebug()
                return []
            }
            
            inputs.append(groupInput)
            
        case .component(let component):
            let canvas = component.canvas
            guard let portId = self.id.portId,
                  let groupInput = canvas.inputViewModels[safe: portId] else {
                fatalErrorIfDebug()
                return []
            }
            
            inputs.append(groupInput)
        }

        return inputs
    }
    
    @MainActor
    func buildUpstreamReference() {
        guard let connectedOutputObserver = self.upstreamOutputObserver else {
            // Upstream values are cached and need to be refreshed if disconnected
            if self.upstreamOutputCoordinate != nil {
                self.upstreamOutputCoordinate = nil
            }
            
            return
        }

        // Check for connected row observer rather than just setting ID--makes for
        // a more robust check in ensuring the connection actually exists
        assertInDebug(self.nodeDelegate?.graphDelegate?.visibleNodesViewModel.getOutputRowObserver(for: connectedOutputObserver.id) != nil)
        
        // Report to output observer that there's an edge (for port colors)
        // We set this to false on default above
        connectedOutputObserver.containsDownstreamConnection = true
    }
}

extension OutputNodeRowObserver {
    @MainActor
    var hasEdge: Bool {
        self.containsDownstreamConnection
    }
    
    @MainActor var allRowViewModels: [OutputNodeRowViewModel] {
        guard let node = self.nodeDelegate else {
            return []
        }
        
        var outputs = [OutputNodeRowViewModel]()
        
        switch node.nodeType {
        case .patch(let patchNode):
            guard let portId = self.id.portId,
                  let patchOutput = patchNode.canvasObserver.outputViewModels[safe: portId] else {
                fatalErrorIfDebug()
                return []
            }
            
            outputs.append(patchOutput)
            
            // Find row view models for group if applicable
            if patchNode.splitterNode?.type == .output {
                // Group id is the only other row view model's canvas's parent ID
                if let groupNodeId = outputs.first?.canvasItemDelegate?.parentGroupNodeId,
                   let groupNode = self.nodeDelegate?.graphDelegate?.getNodeViewModel(groupNodeId)?.nodeType.groupNode {
                    outputs += groupNode.outputViewModels.filter {
                        $0.rowDelegate?.id == self.id
                    }
                }
            }
            
        case .layer(let layerNode):
            guard let portId = id.portId,
                  let port = layerNode.outputPorts[safe: portId] else {
                fatalErrorIfDebug()
                return []
            }
            
            outputs.append(port.inspectorRowViewModel)
            
            if let canvasOutput = port.canvasObserver?.outputViewModels.first {
                outputs.append(canvasOutput)
            }
            
        case .group(let canvas):
            guard let portId = self.id.portId,
                  let groupOutput = canvas.outputViewModels[safe: portId] else {
                fatalErrorIfDebug()
                return []
            }
            
            outputs.append(groupOutput)
            
        case .component(let component):
            let canvas = component.canvas
            guard let portId = self.id.portId,
                  let groupOutput = canvas.outputViewModels[safe: portId] else {
                fatalErrorIfDebug()
                return []
            }
            
            outputs.append(groupOutput)
        }

        return outputs
    }
    
    @MainActor
    func getConnectedDownstreamNodes() -> [CanvasItemViewModel] {
        guard let graph = self.nodeDelegate?.graphDelegate,
              let downstreamConnections: Set<NodeIOCoordinate> = graph.connections
            .get(self.id) else {
            return .init()
        }
        
        // Find all connected downstream canvas items
        let connectedDownstreamNodes: [CanvasItemViewModel] = downstreamConnections
            .flatMap { downstreamCoordinate -> [CanvasItemViewModel] in
                guard let node = graph.getNodeViewModel(downstreamCoordinate.nodeId) else {
                    return .init()
                }
                
                return node.getAllCanvasObservers()
            }
        
        // Include group nodes if any splitters are found
        let downstreamGroupNodes: [CanvasItemViewModel] = connectedDownstreamNodes.compactMap { canvas in
            guard let node = canvas.nodeDelegate,
                  node.splitterType?.isGroupSplitter ?? false,
                  let groupNodeId = canvas.parentGroupNodeId else {
                      return nil
                  }
            
            return graph.getNodeViewModel(groupNodeId)?.nodeType.groupNode
        }
        
        return connectedDownstreamNodes + downstreamGroupNodes
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
                                                 isLayerInspector: self.isLayerInspector)
        self.activeValueChanged(oldRowType: oldRowType,
                                newValue: newValue)
    }
    
    /// Called by parent node view model to update fields.
    @MainActor
    func activeValueChanged(oldRowType: NodeRowType,
                            newValue: PortValue) {
        
        guard let rowDelegate = self.rowDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        let nodeIO = Self.RowObserver.nodeIOType
        let newRowType = newValue.getNodeRowType(nodeIO: nodeIO,
                                                 isLayerInspector: self.isLayerInspector)
        let nodeRowTypeChanged = oldRowType != newRowType
        let importedMediaObject = rowDelegate.importedMediaObject
        
        // Create new field value observers if the row type changed
        // This can happen on various input changes
        guard !nodeRowTypeChanged else {
            self.fieldValueTypes = self.createFieldValueTypes(
                initialValue: newValue,
                nodeIO: nodeIO,
                // Node Row Type change is only when a patch node changes its node type; can't happen for layer nodes
                unpackedPortParentFieldGroupType: nil,
                unpackedPortIndex: nil,
                importedMediaObject: importedMediaObject)
            return
        }
        
        let newFieldsByGroup = newValue.createFieldValuesList(nodeIO: nodeIO,
                                                              importedMediaObject: importedMediaObject,
                                                              isLayerInspector: self.isLayerInspector)
        
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
            let willUpdateField = newFields.count != fieldObserversCount || importedMediaObject.isDefined
            
            if willUpdateField {
                self.fieldValueTypes = self.createFieldValueTypes(
                    initialValue: newValue,
                    nodeIO: nodeIO,
                    // Note: this is only for a patch node whose node-type has changed (?); does not happen with layer nodes, a layer input being packed or unpacked is irrelevant here etc.
                    // Not relevant?
                    unpackedPortParentFieldGroupType: nil,
                    unpackedPortIndex:  nil,
                    importedMediaObject: importedMediaObject)
                return
            }
            
            fieldObserverGroup.updateFieldValues(fieldValues: newFields)
        } // zip
        
        if let node = self.nodeDelegate,
           let layerNode = node.layerNodeViewModel,
           let layerInputForThisRow = rowDelegate.id.keyPath {
            
            layerNode.blockOrUnblockFields(newValue: newValue, 
                                           layerInput: layerInputForThisRow.layerInput)
        }
    }
}

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
            $0.graphDelegate?.groupNodeFocused == $0.canvasItemDelegate?.parentGroupNodeId
        }
    }
}
