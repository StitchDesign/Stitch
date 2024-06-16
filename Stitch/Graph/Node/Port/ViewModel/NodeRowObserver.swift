//
//  PortValueObserver.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/26/23.
//

import Foundation
import StitchSchemaKit
import StitchEngine

typealias NodeRowObservers = [NodeRowObserver]

@Observable
final class NodeRowObserver: Identifiable, Sendable {
    // TODO: this initializer seems strange? Presumably we update and change this logic elsewhere?
    var id: NodeIOCoordinate = .init(portId: .zero, nodeId: .init())
    
    // TODO: can this really ever be nil? -- or does `nil` mean that the cache is not yet initialized?
    // Coordinate ID used for view--cached for perf
    var portViewType: PortViewType?
    
    // Tracks upstream/downstream nodes--cached for perf
    var connectedNodes: NodeIdSet = .init()

    // Data-side for values
    var allLoopedValues: PortValues = .init()

    // View-specific value that only updates when visible
    // separate propety for perf reasons:
    var activeValue: PortValue = .number(.zero)

    // Holds view models for fields
    var fieldValueTypes = FieldGroupTypeViewModelList()

    // statically defined inputs
    var nodeKind: NodeKind
    
    // TODO: an input's or output's type is just the type of its PortValues; what does a separate `UserVisibleType` gain for us?
    // Note: per chat with Elliot, this is mostly just for initializers; also seems to just be for inputs?
    // TODO: get rid of redundant `userVisibleType` on NodeRowObservers or make them access it via NodeDelegate
    var userVisibleType: UserVisibleType?
    
    // Connected upstream node, if input
    var upstreamOutputCoordinate: NodeIOCoordinate? {
        @MainActor
        didSet(oldValue) {
            let coordinateValueChanged = oldValue != self.upstreamOutputCoordinate
            let activeIndex = self.nodeDelegate?.activeIndex ?? .init(.zero)

            guard let upstreamOutputCoordinate = self.upstreamOutputCoordinate else {
                if let oldUpstreamObserver = self.upstreamOutputObserver {
                    log("upstreamOutputCoordinate: removing edge")

                    // Remove edge data
                    oldUpstreamObserver.containsDownstreamConnection = false
                }

                if coordinateValueChanged {
                    // Flatten values
                    let newFlattenedValues = self.allLoopedValues.flattenValues()
                    self.updateValues(newFlattenedValues,
                                      activeIndex: activeIndex,
                                      isVisibleInFrame: self.nodeDelegate?.isVisibleInFrame ?? false)

                    // Recalculate node once values update
                    self.nodeDelegate?.calculate()
                }

                return
            }

            // Update that upstream observer of new edge
            self.upstreamOutputObserver?.containsDownstreamConnection = true
        }
    }

    // TODO: an output row can NEVER have an `upstream output` (i.e. incoming edge)
    /// Tracks upstream output row observer for some input. Cached for perf.
    @MainActor
    var upstreamOutputObserver: NodeRowObserver? {
        self.getUpstreamOutputObserver()
    }

    // Only for outputs, designed for port edge color usage
    var containsDownstreamConnection = false

    // Can't be computed for rendering purposes
    var hasLoopedValues: Bool = false

    // NodeIO type cannot be changed over the life of a row, and is important enough that we should not let it default to some value
    let nodeIOType: NodeIO
    
    var anchorPoint: CGPoint?
    
    // Cached for perf
    var portColor: PortColor = .noEdge

    // Informs parent class of row-specific changes
    weak var nodeDelegate: NodeDelegate?

    @MainActor
    convenience init(from schema: NodePortInputEntity,
                     activeIndex: ActiveIndex,
                     nodeDelegate: NodeDelegate?) {
        self.init(values: schema.values ?? [],
                  nodeKind: schema.nodeKind,
                  userVisibleType: schema.userVisibleType,
                  id: schema.id,
                  activeIndex: activeIndex,
                  upstreamOutputCoordinate: schema.upstreamOutputCoordinate,
                  nodeIOType: .input,
                  nodeDelegate: nodeDelegate)
    }

    @MainActor
    init(values: PortValues,
         nodeKind: NodeKind,
         userVisibleType: UserVisibleType?,
         id: NodeIOCoordinate,
         activeIndex: ActiveIndex,
         upstreamOutputCoordinate: NodeIOCoordinate?,
         nodeIOType: NodeIO,
         nodeDelegate: NodeDelegate?) {
        #if DEBUG || DEV_DEBUG
        if nodeIOType == .input {
            assert(!values.isEmpty || upstreamOutputCoordinate != nil)
        }
        #endif
        
        self.id = id

        self.upstreamOutputCoordinate = upstreamOutputCoordinate
        self.nodeIOType = nodeIOType
        self.allLoopedValues = values
        self.nodeKind = nodeKind
        self.userVisibleType = userVisibleType
        self.activeValue = Self.getActiveValue(allLoopedValues: values,
                                               activeIndex: activeIndex)
        self.hasLoopedValues = values.hasLoop

        self.fieldValueTypes = .init(initialValue: self.getActiveValue(activeIndex: activeIndex),
                                     coordinate: id,
                                     nodeIO: nodeIOType, 
                                     importedMediaObject: nil)
        self.nodeDelegate = nodeDelegate
        
//        self.updatePortViewData() // Initialize NodeRowObserver with appropriate cached data
        postProcessing(oldValues: [], newValues: values)
    }
    
    @MainActor
    static func empty(_ layerInputType: LayerInputType,
                      layer: Layer) -> Self {
        Self.init(values: [layerInputType.getDefaultValue(for: layer)],
                  nodeKind: .layer(.rectangle),
                  userVisibleType: nil,
                  id: .init(portId: -1, nodeId: .init()),
                  activeIndex: .init(.zero),
                  upstreamOutputCoordinate: nil,
                  nodeIOType: .input,
                  nodeDelegate: nil)
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

    /// Called by parent node view model to update fields.
    @MainActor
    func activeValueChanged(oldValue: PortValue,
                            newValue: PortValue) {
        let nodeIO = self.nodeIOType
        let oldRowType = oldValue.getNodeRowType(nodeIO: nodeIO)
        self.activeValueChanged(oldRowType: oldRowType,
                                newValue: newValue)
    }
    
    /// Called by parent node view model to update fields.
    @MainActor
    func activeValueChanged(oldRowType: NodeRowType,
                            newValue: PortValue) {
        let nodeIO = self.nodeIOType
        let newRowType = newValue.getNodeRowType(nodeIO: nodeIO)
        let nodeRowTypeChanged = oldRowType != newRowType
        let importedMediaObject = self.importedMediaObject

        // Create new field value observers if the row type changed
        // This can happen on various input changes
        guard !nodeRowTypeChanged else {
            self.fieldValueTypes = .init(initialValue: newValue,
                                         coordinate: self.id,
                                         nodeIO: nodeIO, 
                                         importedMediaObject: importedMediaObject)
            return
        }

        let newFieldsByGroup = newValue.createFieldValues(nodeIO: nodeIO, 
                                                          importedMediaObject: importedMediaObject)

        // Assert equal array counts
        guard newFieldsByGroup.count == self.fieldValueTypes.count else {
            log("NodeRowObserver error: incorrect counts of groups.")
            return
        }

        zip(self.fieldValueTypes, newFieldsByGroup).forEach { fieldObserverGroup, newFields in
            
            // If existing field observer group's count does not match the new fields count,
            // reset the fields on this input/output.
            let fieldObserversCount = fieldObserverGroup.fieldObservers.count
            
            // Force update if any media--inefficient but works
            let willUpdateField = newFields.count != fieldObserversCount || importedMediaObject.isDefined
            
            if willUpdateField {
                self.fieldValueTypes = .init(initialValue: newValue,
                                             coordinate: self.id,
                                             nodeIO: nodeIO,
                                             importedMediaObject: importedMediaObject)
                return
            }
            
            fieldObserverGroup.updateFieldValues(fieldValues: newFields)
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

extension NodeRowObserver: NodeRowCalculatable {
    var values: PortValues {
        get {
            self.allLoopedValues
        }
        set(newValue) {
            self.allLoopedValues = newValue
        }
    }
}

extension NodeRowObserver: SchemaObserverIdentifiable {
    static func createObject(from entity: NodePortInputEntity) -> Self {
        self.init(from: entity,
                  activeIndex: .init(.zero),
                  nodeDelegate: nil)
    }

    /// Only updates values for inputs without connections.
    @MainActor
    func update(from schema: NodePortInputEntity,
                activeIndex: ActiveIndex) {
        self.upstreamOutputCoordinate = schema.upstreamOutputCoordinate

        // Update values if no upstream connection
        if let values = schema.values {
            self.updateValues(values,
                              activeIndex: activeIndex,
                              isVisibleInFrame: true)
        }
    }

    /// Only updates values for inputs without connections.
    @MainActor
    func update(from schema: NodePortInputEntity) {
        self.update(from: schema, activeIndex: .init(.zero))
    }
    
    /// Schema updates from layer.
    @MainActor
    func update(from nodeConnection: NodeConnectionType,
                inputType: LayerInputType) {
        switch nodeConnection {
        case .upstreamConnection(let upstreamOutputCoordinate):
            self.upstreamOutputCoordinate = upstreamOutputCoordinate
            
        case .values(let values):
            guard let layer = self.nodeKind.getLayer else {
                fatalErrorIfDebug()
                return
            }
            
            let values = values.isEmpty ? [inputType.getDefaultValue(for: layer)] : values
            self.updateValues(values,
                              activeIndex: .init(.zero),
                              isVisibleInFrame: true)
        }
    }

    func createSchema() -> NodePortInputEntity {
        guard let upstreamOutputObserver = self.upstreamOutputObserver else {
            return NodePortInputEntity(id: id,
                                       nodeKind: self.nodeKind,
                                       userVisibleType: self.userVisibleType,
                                       values: self.allLoopedValues,
                                       upstreamOutputCoordinate: self.upstreamOutputCoordinate)
        }

        return NodePortInputEntity(id: id,
                                   nodeKind: self.nodeKind,
                                   userVisibleType: self.userVisibleType,
                                   values: nil,
                                   upstreamOutputCoordinate: upstreamOutputObserver.id)
    }
    
    func onPrototypeRestart() {
        
        // Set inputs to defaultValue
        if self.nodeIOType == .input {
            
            // test out first on just non-layer-node inputs
            if self.upstreamOutputCoordinate.isDefined,
               let patch = self.nodeKind.getPatch,
               let portId = self.id.portId {
                
                let defaultInputs: NodeInputDefinitions = self.nodeKind
                    .rowDefinitions(for: self.userVisibleType)
                    .inputs
                
                if let defaultValues = getDefaultValueForPatchNodeInput(portId,
                                                                        defaultInputs,
                                                                        patch: patch) {
                    
                    // log("will reset patch node input \(self.id) to default value \(defaultValues)")
                    self.updateValues(
                        defaultValues,
                        activeIndex: self.nodeDelegate?.graphDelegate?.activeIndex ?? .init(0),
                        isVisibleInFrame: true)
                } 
                //                else {
                //                    log("was not able to reset patch node input to default value")
                //                }
                                
            }
        }
        
        // Set outputs to be empty
        if self.nodeIOType == .output {
            self.allLoopedValues = []
        }
    }
}


extension NodeRowObserver {    
    /// Caches perf-costly operations for tracking various data used for view.
    @MainActor
    func updatePortViewData() {
        self.portViewType = self.getPortViewType()
    }
    
    @MainActor
    func updateConnectedNodes() {
        self.connectedNodes = self.getConnectedNodes()
        
        // Update port color data
        self.updatePortColor()
    }
    
    @MainActor
    var inputPortViewData: InputPortViewData? {
        self.portViewType?.input
    }
    
    @MainActor
    var outputPortViewData: OutputPortViewData? {
        self.portViewType?.output
    }
    
    /// Gets node ID for currently visible node. Covers edge cause where group nodes use splitter nodes,
    /// which save a differnt node ID.
    @MainActor
    var visibleNodeId: NodeId? {
        guard self.nodeDelegate?.isVisibleInFrame ?? false else {
            return nil
        }
        
        // We use the group node ID only if it isn't in focus
        if self.nodeDelegate?.splitterType == .input &&
            self.nodeDelegate?.graphDelegate?.groupNodeFocused != self.nodeDelegate?.parentGroupNodeId {
            return self.nodeDelegate?.parentGroupNodeId
        }
        
        return self.id.nodeId
    }
    
    @MainActor
    private func getUpstreamOutputObserver() -> NodeRowObserver? {
        guard let upstreamCoordinate = self.upstreamOutputCoordinate,
              let upstreamPortId = upstreamCoordinate.portId else {
            return nil
        }

        // Set current upstream observer
        return self.nodeDelegate?.getNode(upstreamCoordinate.nodeId)?
            .getOutputRowObserver(upstreamPortId)
    }
    
    // MARK: This has expensive perf (esp `getGroupSplitters`) so it's been relegated to only be called on visible nodes sync.
    @MainActor
    private func getPortViewType() -> PortViewType? {
        guard let nodeId = self.nodeDelegate?.id else {
            return nil
        }

        // Row observers use splitters inside groups
        let isGroup = self.nodeKind == .patch(.splitter) &&
        // Splitter is visible if it's parent group ID is focused in graph
        self.nodeDelegate?.parentGroupNodeId != self.nodeDelegate?.graphDelegate?.groupNodeFocused
        
        guard !isGroup else {
            let splitterType: SplitterType = self.nodeIOType == .input ? .input : .output
            
            // Groups can't use ID's directly since these are splitter IDs
            guard let groupNodeId = self.nodeDelegate?.parentGroupNodeId,
                  let groupSplitters = self.nodeDelegate?.graphDelegate?
                      .getSplitterRowObservers(for: groupNodeId, type: splitterType),
                  let groupPortId = groupSplitters
                .firstIndex(where: { $0.id == self.id }) else {
//                fatalErrorIfDebug()
                return nil
            }
            
            return .init(nodeIO: self.nodeIOType,
                         portId: groupPortId,
                         nodeId: groupNodeId)
        }
        
        // Check for layers and patches
        switch self.id.portType {
        case .keyPath(let layerInputType):
            assertInDebug(self.nodeIOType == .input)
            
            guard let layer = self.nodeKind.getLayer,
                  let index = layer.layerGraphNode.inputDefinitions.firstIndex(of: layerInputType) else {
                fatalErrorIfDebug()
                return nil
            }
            
            return .init(nodeIO: self.nodeIOType,
                         portId: index,
                         nodeId: nodeId)
            
        case .portIndex(let portId):
            return .init(nodeIO: self.nodeIOType,
                         portId: portId,
                         nodeId: nodeId)
        }
    }
    
    /// Nodes connected via edge.
    @MainActor
    private func getConnectedNodes() -> NodeIdSet {
        guard let nodeId = self.nodeDelegate?.id else {
            fatalErrorIfDebug()
            return .init()
        }
        
        // Include self
        var nodes = Set([nodeId])
        
        // Must get port UI data. Helpers below will get group or splitter data depending on focused group.
        switch self.portViewType {
        case .none:
            return .init()
        case .input:
            guard let connectedUpstreamNode = self.getConnectedUpstreamNode() else {
                return nodes
            }
            
            nodes.insert(connectedUpstreamNode)
            return nodes
            
        case .output:
            return nodes.union(getConnectedDownstreamNodes())
        }
    }
    
    @MainActor
    func getConnectedUpstreamNode() -> NodeId? {
        guard let upstreamOutputObserver = self.upstreamOutputObserver else {
            return nil
        }
        
        guard let outputPort = upstreamOutputObserver.outputPortViewData else {
            return nil
        }
        
        return outputPort.nodeId
    }
    
    @MainActor
    func getConnectedDownstreamNodes() -> NodeIdSet {
        var nodes = NodeIdSet()
        
        guard let portId = self.id.portId,
              let connectedInputs = self.nodeDelegate?.graphDelegate?.connections
            .get(NodeIOCoordinate(portId: portId,
                                  nodeId: id.nodeId)) else {
            return nodes
        }
        
        connectedInputs.forEach { inputCoordinate in
            guard let node = self.nodeDelegate?.graphDelegate?.getNodeViewModel(inputCoordinate.nodeId),
                  let inputRowObserver = node.getInputRowObserver(for: inputCoordinate.portType),
                  let inputPortViewData = inputRowObserver.inputPortViewData else {
                return
            }
            
            nodes.insert(inputPortViewData.nodeId)
        }
        
        return nodes
    }
    
    /// Same as `createSchema()` but used for layer schema data.
    @MainActor
    func createLayerSchema() -> NodeConnectionType {
        guard let upstreamOutputObserver = self.upstreamOutputObserver else {
            return .values(self.allLoopedValues)
        }
        
        return .upstreamConnection(upstreamOutputObserver.id)
    }
    
    @MainActor
    var label: String {
        switch id.portType {
        case .portIndex(let portId):
            if self.nodeIOType == .input,
               let mathExpr = self.nodeDelegate?.getMathExpression?.getSoulverVariables(),
               let variableChar = mathExpr[safe: portId] {
//                return String(variableChar)
                return String(variableChar)
            }
            
            let rowDefinitions = self.nodeKind.graphNode?.rowDefinitions(for: userVisibleType) ?? self.nodeKind.rowDefinitions(for: userVisibleType)
            
            // Note: when an input is added (e.g. adding an input to an Add node),
            // the newly-added input will not be found in the rowDefinitions,
            // so we can use an empty string as its label.
            return self.nodeIOType == .input
            ? rowDefinitions.inputs[safe: portId]?.label ?? ""
            : rowDefinitions.outputs[safe: portId]?.label ?? ""
            
        case .keyPath(let keyPath):
            return keyPath.label
        }
    }

    @MainActor
    func updateValues(_ newValues: PortValues,
                      activeIndex: ActiveIndex,
                      isVisibleInFrame: Bool,
                      // Used for layer nodes which haven't yet initialized fields
                      isInitialization: Bool = false) {
        // Save these for `postProcessing`
        let oldValues = self.allLoopedValues
        
        // Always update the non-view data in the NodeRowObserver
        self.allLoopedValues = newValues
        
        // Always update "hasLoop", since offscreen node may have an onscreen edge.
        let hasLoop = newValues.hasLoop
        if hasLoop != self.hasLoopedValues {
            self.hasLoopedValues = hasLoop
        }
        
        // Update cached view-specific data: "viewValue" i.e. activeValue
        
        let oldViewValue = self.activeValue // the old cached
        let newViewValue = self.getActiveValue(activeIndex: activeIndex)
        let didViewValueChange = oldViewValue != newViewValue

        // Conditions for forcing fields update:
        // 1. Is at time of initialization--used for layers
        // 2. Did values change AND visible in frame
        let shouldUpdate = isInitialization || (didViewValueChange && isVisibleInFrame)

        if shouldUpdate {
            self.activeValue = newViewValue

            // TODO: pass in media to here!
            self.activeValueChanged(oldValue: oldViewValue,
                                    newValue: newViewValue)
        }
        
        self.postProcessing(oldValues: oldValues, newValues: newValues)
    }
    
    @MainActor
    func postProcessing(oldValues: PortValues, 
                        newValues: PortValues) {
        // Update cached interactions data in graph
        self.updateInteractionNodeData(oldValues: oldValues,
                                       newValues: newValues)
        
        // Update visual color data
        self.updatePortColor()
    }
    
    /// Updates layer selections for interaction patch nodes for perf.
    @MainActor
    func updateInteractionNodeData(oldValues: PortValues,
                                   newValues: PortValues) {
        // Interaction nodes ignore loops of assigned layers and only use the first
        let firstValueOld = oldValues.first
        let firstValueNew = newValues.first
        
        guard let graphDelegate = self.nodeDelegate?.graphDelegate,
              let patch = self.nodeKind.getPatch,
              patch.isInteractionPatchNode,
              self.nodeIOType == .input,
              self.id.portId == 0 else { //, // the "assigned layer" input
            
            // TODO: how was `updateInteractionNodeData` being called with the exact same value for `firstValueOld` and `firstValueNew`?
            // NOTE: Over-updating a dictionary is probably fine, perf-wise; an interaction node's assigned layer is not something that is updated at 120 FPS...
            
//              firstValueOld != firstValueNew else {
            return
        }
        
        // Remove old value from graph state
        if let oldLayerId = firstValueOld?.getInteractionId {
            switch patch {
            case .dragInteraction:
                graphDelegate.dragInteractionNodes.removeValue(forKey: oldLayerId)
            case .pressInteraction:
                graphDelegate.pressInteractionNodes.removeValue(forKey: oldLayerId)
            case .scrollInteraction:
                graphDelegate.scrollInteractionNodes.removeValue(forKey: oldLayerId)
            default:
                fatalErrorIfDebug()
            }
        }
        
        if let newLayerId = firstValueNew?.getInteractionId {
            switch patch {
            case .dragInteraction:
                var currentIds = graphDelegate.dragInteractionNodes.get(newLayerId) ?? NodeIdSet()
                currentIds.insert(self.id.nodeId)
                graphDelegate.dragInteractionNodes.updateValue(currentIds, forKey: newLayerId)
            case .pressInteraction:
                var currentIds = graphDelegate.pressInteractionNodes.get(newLayerId) ?? NodeIdSet()
                currentIds.insert(self.id.nodeId)
                graphDelegate.pressInteractionNodes.updateValue(currentIds, forKey: newLayerId)
            case .scrollInteraction:
                var currentIds = graphDelegate.scrollInteractionNodes.get(newLayerId) ?? NodeIdSet()
                currentIds.insert(self.id.nodeId)
                graphDelegate.scrollInteractionNodes.updateValue(currentIds, forKey: newLayerId)
            default:
                fatalErrorIfDebug()
            }
        }
    }
    
    var hasEdge: Bool {
        self.upstreamOutputCoordinate.isDefined ||
            self.containsDownstreamConnection
    }
    
    @MainActor
    func updatePortColor() {
        guard let graph = self.nodeDelegate?.graphDelegate,
              let portViewType = self.portViewType else {
            // log("updatePortColor: did not have graph delegate and/or portViewType; will default to noEdge")
            self.setPortColorIfChanged(.noEdge)
            return
        }
        
        switch portViewType {
        case .output:
            updateOutputColor(output: self, graphState: graph)
        case .input:
            updateInputColor(input: self, graphState: graph)
        }
    }

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

    func getActiveValue(activeIndex: ActiveIndex) -> PortValue {
        Self.getActiveValue(allLoopedValues: self.allLoopedValues,
                            activeIndex: activeIndex)
    }

    // Tracked by subscriber to know when a new view model should be created
    private func getNodeRowType(activeIndex: ActiveIndex) -> NodeRowType {
        let activeValue = self.getActiveValue(activeIndex: activeIndex)
        return activeValue.getNodeRowType(nodeIO: self.nodeIOType)
    }

    var currentBroadcastChoiceId: NodeId? {
        guard self.nodeKind == .patch(.wirelessReceiver),
              self.id.portId == 0,
              self.nodeIOType == .input else {
            // log("NodeRowObserver: currentBroadcastChoice: did not have wireless node: returning nil")
            return nil
        }

        // the id of the connected wireless broadcast node
        // TODO: why was there an `upstreamOutputCoordinate` but not a `upstreamOutputObserver` ?
        //        let wirelessBroadcastId = self.upstreamOutputObserver?.id.nodeId
        let wirelessBroadcastId = self.upstreamOutputCoordinate?.nodeId
        // log("NodeRowObserver: currentBroadcastChoice: wirelessBroadcastId: \(wirelessBroadcastId)")
        return wirelessBroadcastId
    }
    
    func getMediaObjects() -> [StitchMediaObject] {
        self.allLoopedValues
            .compactMap { $0.asyncMedia?.mediaObject }
    }
}

extension NodeRowObserver: Equatable {
    static func == (lhs: NodeRowObserver, rhs: NodeRowObserver) -> Bool {
        lhs.id == rhs.id
    }
}

extension NodeRowObservers {
    @MainActor
    init(values: PortValuesList,
         kind: NodeKind,
         userVisibleType: UserVisibleType?,
         id: NodeId,
         nodeIO: NodeIO,
         activeIndex: ActiveIndex,
         nodeDelegate: NodeDelegate) {
        self = values.enumerated().map { portId, values in
            NodeRowObserver(values: values,
                            nodeKind: kind,
                            userVisibleType: userVisibleType,
                            id: NodeIOCoordinate(portId: portId, nodeId: id),
                            activeIndex: activeIndex,
                            upstreamOutputCoordinate: nil,
                            nodeIOType: nodeIO,
                            nodeDelegate: nodeDelegate)
        }
    }

    var values: PortValuesList {
        self.map {
            $0.allLoopedValues
        }
    }

    @MainActor
    func updateAllValues(_ newValuesList: PortValuesList,
                         nodeIO: NodeIO,
                         nodeId: NodeId,
                         nodeKind: NodeKind,
                         userVisibleType: UserVisibleType?,
                         nodeDelegate: NodeDelegate,
                         activeIndex: ActiveIndex) {
        
        let oldValues = self.values
        let oldLongestPortLength = oldValues.count
        let newLongestPortLength = newValuesList.count
        let currentObserverCount = self.count

        // Remove view models if loop count decreased
        if newLongestPortLength < oldLongestPortLength {
            // Sub-array can't exceed its current bounds or we get index-out-of-bounds
            // Helpers below will create any missing observers
            let arrayBoundary = Swift.min(newLongestPortLength, currentObserverCount)

            nodeDelegate.portCountShortened(to: arrayBoundary, nodeIO: nodeIO)
        }

        newValuesList.enumerated().forEach { portId, values in
            let observer = self[safe: portId] ??
                // Sometimes observers aren't yet created for nodes with adjustable inputs
                NodeRowObserver(values: values,
                                nodeKind: nodeDelegate.kind,
                                userVisibleType: userVisibleType,
                                id: .init(portId: portId, nodeId: nodeId),
                                activeIndex: .init(.zero),
                                upstreamOutputCoordinate: nil,
                                nodeIOType: nodeIO,
                                nodeDelegate: nodeDelegate)

            // Only update values if there's no upstream connection
            if !observer.upstreamOutputObserver.isDefined {
                observer.updateValues(values,
                                      activeIndex: nodeDelegate.activeIndex,
                                      isVisibleInFrame: nodeDelegate.isVisibleInFrame)
            }
        }
    }
}

