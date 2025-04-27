//
//  InputCommittedActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/1/22.
//

import Foundation
import StitchSchemaKit
import SwiftyJSON


extension GraphState {
  
    @MainActor
    func mediaInputEditCommitted(input: NodeIOCoordinate,
                                 value: PortValue?,
                                 activeIndex: ActiveIndex) {
        
        guard let node = self.getNodeViewModel(input.nodeId),
              let input = node.getInputRowObserver(for: input.portType) else {
            log("mediaInputEditCommitted: node or input missing?: input: \(input)")
            return
        }
        
        self.inputEditCommitted(input: input,
                                value: value,
                                activeIndex: activeIndex,
                                wasAdjustmentBarSelection: false)
    }

    /*
     Used in two different cases:
     1. text field commit: edits have actively been parsed and coerced; no need to update input again.
     2. json field, adjustment bar etc. commits: no edits have taken place; so must update input.
     
     `value: PortValue?` is nil in case 1, non-nil in case 2.
     
     `value`, when non-nil, is either:
     (A) a single value or
     (B) the parent value (multifield) for an input that has multiple fields:
     eg PortValue.Position -> (FieldValue.Number, FieldValue.Number)
     
     */
    @MainActor
    func handleInputEditCommitted(input: NodeIOCoordinate,
                                  value: PortValue?,
                                  activeIndex: ActiveIndex,
                                  isFieldInsideLayerInspector: Bool,
                                  wasAdjustmentBarSelection: Bool = false) {
        guard let node = self.getNodeViewModel(input.nodeId),
              let input = node.getInputRowObserver(for: input.portType) else {
            fatalErrorIfDebug()
            return
        }
        
        return self.handleInputEditCommitted(input: input,
                                             value: value,
                                             activeIndex: activeIndex,
                                             isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                             wasAdjustmentBarSelection: wasAdjustmentBarSelection)
    }
    
    @MainActor
    func handleInputEditCommitted(input: InputNodeRowObserver,
                                  value: PortValue?,
                                  activeIndex: ActiveIndex,
                                  isFieldInsideLayerInspector: Bool,
                                  wasAdjustmentBarSelection: Bool = false) {
        
        if let layerMultiselectInput = self.getLayerMultiselectInput(
            layerInput: input.id.keyPath?.layerInput,
            isFieldInsideLayerInspector: isFieldInsideLayerInspector) {
        
            // Note: heterogenous values doesn't matter; only the multiselect does
            layerMultiselectInput.multiselectObservers(self).forEach { (observer: LayerInputObserver) in
                if let rowObserver = observer.getInputNodeRowObserver(for: 0, self) {
                    self.inputEditCommitted(input: rowObserver,
                                            value: value,
                                            activeIndex: activeIndex,
                                            wasAdjustmentBarSelection: wasAdjustmentBarSelection)
                }
            }
        } 
        
        // just editing a single
        else {
            self.inputEditCommitted(input: input,
                                    value: value,
                                    activeIndex: activeIndex,
                                    wasAdjustmentBarSelection: wasAdjustmentBarSelection)
        }
    }
    
    @MainActor
    func inputEditCommitted(input: InputNodeRowObserver,
                            value: PortValue?,
                            activeIndex: ActiveIndex,
                            wasAdjustmentBarSelection: Bool = false) {
        
        let nodeId = input.id.nodeId
        
        // TODO: debug: why was input.nodeDelegate `nil` for e.g. the padding layer-input but not the size layer-input, and only in the context of generating an LLM action?
        guard let node = self.getNode(nodeId),
              var value = value else {
            log("GraphState.inputEditCommitted error: could not find node data.")
            return
        }
        
        self.confirmInputIsVisibleInFrame(input)
                
        // if we had a value, and the value was different than the existing value,
        // THEN we detach the edge.
        // Should be okay since whenever we connect an edge, we evaluate the node and thus extend its inputs and outputs.
        let valueAtIndex = input.getActiveValue(activeIndex: activeIndex)
        let valueChange = (valueAtIndex != value)
        
        guard valueChange else {
            log("GraphState.inputEditCommitted: value did not change, so returning early")
            
            // See note in `inputEdited`
            input.immediatelyUpdateFieldObserversAfterInputEdit(value)
            
            return
        }
        
        node.removeIncomingEdge(at: input.id, graph: self)
        
        // Block or unblock certain layer inputs
        if let layerNode = node.layerNode {
            layerNode.refreshBlockedInputs(graph: self, activeIndex: activeIndex)
        }
        
        let newCommandType = value.shapeCommandType
        
        // If we changed the command type on a ShapeCommand input,
        // then we may need to change the ShapeCommand case
        // (e.g. from .moveTo -> .curveTo).
        
        if let shapeCommand = valueAtIndex.shapeCommand,
           let newCommandType = newCommandType {
            value = .shapeCommand(shapeCommand.convert(to: newCommandType))
            log("GraphState.inputEditCommitted: value is now: \(value)")
        }
        
        // Only change the input if valued actually changed.
        input.setValuesInInput([value])
        input.immediatelyUpdateFieldObserversAfterInputEdit(value)
        
        self.scheduleForNextGraphStep(nodeId)
    }
    
    @MainActor
    func confirmInputIsVisibleInFrame(_ input: InputNodeRowObserver) {
        input.allRowViewModels.forEach { rowViewModel in
            // If we're editing a field on the canvas (pacth, or layer-input-on-canvas),
            // that field must be 'visible in frame.'
            // If the field is not visible, log this to Sentry and manually set the canvas item visible.
            if let canvasItem = rowViewModel.canvasItemDelegate,
               !canvasItem.isVisibleInFrame(self.visibleCanvasIds) {
                
                // TODO: we are firing input edit events merely when an item is added to the canvas
//                // On dev debug, crash
//                fatalErrorIfDebug()
//                
//                // On prod, log to Sentry
//                log("Canvas item \(canvasItem.id) was considered off-screen, yet we edited one of its fields?", .logToServer)
                
                // Set the item to be visible, no matter what
                self.visibleNodesViewModel.visibleCanvasIds.insert(canvasItem.id)
            }
        }
    }
}

extension InputNodeRowObserver {
    // Immediately update the field observers; do not wait until graph-step-based UI field updater runs.
    // Useful when e.g. user enters input faster than our UI update FPS
    @MainActor
    func immediatelyUpdateFieldObserversAfterInputEdit(_ value: PortValue) {
        self.allRowViewModels.forEach { $0.updateFields(value) }
    }
}
