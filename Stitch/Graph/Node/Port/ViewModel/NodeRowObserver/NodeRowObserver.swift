//
//  PortValueObserver.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/26/23.
//

import Foundation
import StitchSchemaKit
import StitchEngine

//typealias NodeRowObservers = [NodeRowObserver]

// Keep this at top of file; very important information:
//extension NodeRowObserver: Equatable {
//    static func == (lhs: NodeRowObserver, rhs: NodeRowObserver) -> Bool {
//        lhs.id == rhs.id
//    }
//}

protocol NodeRowObserver: Identifiable, Sendable {
    associatedtype RowViewModelType: NodeRowViewModel
    
    var id: NodeIOCoordinate { get set }
    
    // Data-side for values
    var allLoopedValues: PortValues { get set }
    
    static var nodeIOType: NodeIO { get }
    
    var rowViewModel: RowViewModelType { get set }
    
    var nodeDelegate: NodeDelegate? { get set }
    
    // TODO: an input's or output's type is just the type of its PortValues; what does a separate `UserVisibleType` gain for us?
    // Note: per chat with Elliot, this is mostly just for initializers; also seems to just be for inputs?
    // TODO: get rid of redundant `userVisibleType` on NodeRowObservers or make them access it via NodeDelegate
    var userVisibleType: UserVisibleType? { get set }
    
    var connectedNodes: NodeIdSet { get set }
    
    var hasLoopedValues: Bool { get set }
}

@Observable
final class InputNodeRowObserver: NodeRowObserver {
    static let nodeIOType: NodeIO = .input

    var id: NodeIOCoordinate = .init(portId: .zero, nodeId: .init())
    
    // Data-side for values
    var allLoopedValues: PortValues = .init()
    
    // statically defined inputs
    var nodeKind: NodeKind
    
    var rowViewModel: InputNodeRowViewModel
    
    // Connected upstream node, if input
    var upstreamOutputCoordinate: NodeIOCoordinate? {
        @MainActor
        didSet(oldValue) {
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
    }
    
    // TODO: an output row can NEVER have an `upstream output` (i.e. incoming edge)
    /// Tracks upstream output row observer for some input. Cached for perf.
    @MainActor
    var upstreamOutputObserver: OutputNodeRowObserver? {
        self.getUpstreamOutputObserver()
    }
    
    // NodeRowObserver holds a reference to its parent, the Node
    weak var nodeDelegate: NodeDelegate?
    
    var userVisibleType: UserVisibleType?
    
    // MARK: "derived data", cached for UI perf
    
    // Tracks upstream/downstream nodes--cached for perf
    var connectedNodes: NodeIdSet = .init()
    
    // Only for outputs, designed for port edge color usage
    var containsDownstreamConnection = false
    
    // Can't be computed for rendering purposes
    var hasLoopedValues: Bool = false
    
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
                  nodeDelegate: nodeDelegate)
    }
    
    @MainActor
    init(values: PortValues,
         nodeKind: NodeKind,
         userVisibleType: UserVisibleType?,
         id: NodeIOCoordinate,
         activeIndex: ActiveIndex,
         upstreamOutputCoordinate: NodeIOCoordinate?,
         nodeDelegate: NodeDelegate?) {
        
        self.id = id
        let portViewType: InputPortViewData = self.portview
        
        self.rowViewModel = .init(id: <#T##InputPortViewData#>, activeValue: <#T##PortValue#>, rowDelegate: <#T##any NodeRowObserver#>, canvasItemDelegate: <#T##CanvasItemViewModel#>)
        self.upstreamOutputCoordinate = upstreamOutputCoordinate
        self.rowViewModel = .init(id: <#T##InputPortViewData#>, activeValue: <#T##PortValue#>, rowDelegate: <#T##any NodeRowObserver#>, canvasItemDelegate: <#T##CanvasItemViewModel#>)
        self.allLoopedValues = values
        self.nodeKind = nodeKind
        self.userVisibleType = userVisibleType
        self.hasLoopedValues = values.hasLoop
        
        self.nodeDelegate = nodeDelegate
        
        postProcessing(oldValues: [], newValues: values)
    }
}

extension InputNodeRowObserver {
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
        return self.nodeDelegate?.getNode(upstreamCoordinate.nodeId)?
            .getOutputRowObserver(upstreamPortId)
    }
}

extension NodeRowViewModel {
    /// Called by parent node view model to update fields.
    @MainActor
    func activeValueChanged(oldValue: PortValue,
                            newValue: PortValue) {
        guard let rowDelegate = self.rowDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        let nodeIO = rowDelegate.nodeIOType
        let oldRowType = oldValue.getNodeRowType(nodeIO: nodeIO)
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
        
        let nodeIO = rowDelegate.nodeIOType
        let newRowType = newValue.getNodeRowType(nodeIO: nodeIO)
        let nodeRowTypeChanged = oldRowType != newRowType
        let importedMediaObject = rowDelegate.importedMediaObject
        
        // Create new field value observers if the row type changed
        // This can happen on various input changes
        guard !nodeRowTypeChanged else {
            self.fieldValueTypes = self
                .createFieldValueTypes(initialValue: newValue,
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
                self.fieldValueTypes = self
                    .createFieldValueTypes(initialValue: newValue,
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
