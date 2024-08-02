//
//  InputCommittedActions.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/1/22.
//

import Foundation
import StitchSchemaKit
import SwiftyJSON


extension GraphState {
    @MainActor
    func jsonEditCommitted(input: NodeIOCoordinate,
                           json: JSON) {
        self.inputEditCommitted(
            input: input,
            value: .json(json.toStitchJSON)
        )
    }
}

extension StitchStore {
    @MainActor
    func inputEditCommitted(input: NodeIOCoordinate,
                            value: PortValue?,
                            wasAdjustmentBarSelection: Bool = false) {
        guard let node = self.currentGraph?.getNodeViewModel(input.nodeId),
              let input = node.getInputRowObserver(for: input.portType) else {
            return
        }
        
        self.inputEditCommitted(input: input,
                                value: value,
                                wasAdjustmentBarSelection: wasAdjustmentBarSelection)
    }
    
    @MainActor
    func inputEditCommitted(input: InputNodeRowObserver,
                            value: PortValue?,
                            wasAdjustmentBarSelection: Bool = false) {
        guard let graphState = self.currentGraph else {
            return
        }

        let oldDocument = graphState.createSchema()
        graphState
            .inputEditCommitted(input: input,
                                value: value,
                                wasAdjustmentBarSelection: wasAdjustmentBarSelection)

        let newDocument = graphState.createSchema()

        self.saveUndoHistory(oldState: oldDocument,
                             newState: newDocument)
    }
}

extension GraphState {
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
    func inputEditCommitted(input: NodeIOCoordinate,
                            value: PortValue?,
                            wasAdjustmentBarSelection: Bool = false) {
        guard let node = self.getNodeViewModel(input.nodeId),
              let input = node.getInputRowObserver(for: input.portType) else {
            fatalErrorIfDebug()
            return
        }
        
        self.inputEditCommitted(input: input,
                                value: value,
                                wasAdjustmentBarSelection: wasAdjustmentBarSelection)
    }
    
    @MainActor
    func inputEditCommitted(input: InputNodeRowObserver,
                            value: PortValue?,
                            wasAdjustmentBarSelection: Bool = false) {
        
        guard let nodeId = input.nodeDelegate?.id,
              let nodeViewModel = self.getNodeViewModel(nodeId),
              var value = value else {
            log("GraphState.inputEditCommitted error: could not find node data.")
            return
        }
        
        // if we had a value, and the value was different than the existing value,
        // THEN we detach the edge.
        // Should be okay since whenever we connect an edge, we evaluate the node and thus extend its inputs and outputs.
        let valueAtIndex = input.activeValue
        let valueChange = (valueAtIndex != value)
        
        guard valueChange else {
            log("GraphState.inputEditCommitted: value did not change, so returning early")
            return
        }
        
        nodeViewModel.removeIncomingEdge(at: input.id,
                                         activeIndex: self.activeIndex)

        if let sizingScenario = value.getSizingScenario {
            nodeViewModel.sizingScenarioUpdated(scenario: sizingScenario)
        }
        
        if let orientation = value.getOrientation {
            nodeViewModel.layerGroupOrientationUpdated(newValue: orientation)
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
        
        self.maybeCreateLLMSetInput(node: nodeViewModel,
                                    input: input.id,
                                    value: value)
        
        self.calculate(nodeId)
    }
}
