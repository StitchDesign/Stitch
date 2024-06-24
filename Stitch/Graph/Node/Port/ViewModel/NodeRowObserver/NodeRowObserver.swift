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

// Keep this at top of file; very important information:
extension NodeRowObserver: Equatable {
    static func == (lhs: NodeRowObserver, rhs: NodeRowObserver) -> Bool {
        lhs.id == rhs.id
    }
}

@Observable
final class NodeRowObserver: Identifiable, Sendable {
    
    var canvasUIData: CanvasItemViewModel? = nil
    
    // MARK: fundamental, non-derived data
    
    // TODO: this initializer seems strange? Presumably we update and change this logic elsewhere?
    var id: NodeIOCoordinate = .init(portId: .zero, nodeId: .init())
    
    // Data-side for values
    var allLoopedValues: PortValues = .init()
    
    // statically defined inputs
    var nodeKind: NodeKind
    
    // NodeIO type cannot be changed over the life of a row, and is important enough that we should not let it default to some value
    let nodeIOType: NodeIO
    
    // Holds view models for fields
    var fieldValueTypes = FieldGroupTypeViewModelList()
    
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
    
    
    // MARK: NodeRowObserver holds a reference to its parent, the Node
    
    // TODO: better?: in contexts where we have the NodeRowObserver (Input or Output) and need the Node, just retrieve the Node directly from GraphState; don't need an additional property on the NodeRowObserver
    // Informs parent class of row-specific changes
    weak var nodeDelegate: NodeDelegate?
    
    
    // MARK: legacy data to ignore
    
    // TODO: an input's or output's type is just the type of its PortValues; what does a separate `UserVisibleType` gain for us?
    // Note: per chat with Elliot, this is mostly just for initializers; also seems to just be for inputs?
    // TODO: get rid of redundant `userVisibleType` on NodeRowObservers or make them access it via NodeDelegate
    var userVisibleType: UserVisibleType?
    
    

    // MARK: "derived data", cached for UI perf
    
    // TODO: can this really ever be nil? -- or does `nil` mean that the cache is not yet initialized?
    // Coordinate ID used for view--cached for perf
    var portViewType: PortViewType?
    
    // Tracks upstream/downstream nodes--cached for perf
    var connectedNodes: NodeIdSet = .init()

    // View-specific value that only updates when visible
    // separate propety for perf reasons:
    var activeValue: PortValue = .number(.zero)

    // Only for outputs, designed for port edge color usage
    var containsDownstreamConnection = false

    // Can't be computed for rendering purposes
    var hasLoopedValues: Bool = false
    
    // TODO: what is this for?
    var anchorPoint: CGPoint?
    
    // Cached for perf
    var portColor: PortColor = .noEdge
    

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
    
    // Because `private`, needs to be declared in same file(?) as method that uses it
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
}

extension NodeRowObserver {
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
