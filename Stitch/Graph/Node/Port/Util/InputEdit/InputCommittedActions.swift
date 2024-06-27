//
//  InputCommittedActions.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/1/22.
//

import Foundation
import StitchSchemaKit
import SwiftyJSON

struct JsonEditCommitted: GraphEvent {
    let coordinate: InputCoordinate
    let json: JSON

    func handle(state: GraphState) {
        state.inputEditCommitted(
            input: coordinate,
            value: .json(json.toStitchJSON)
        )
    }
}

extension StitchStore {
    // TODO: reuse the logic in `InputEdited` ?
    @MainActor
    func inputEditCommitted(input: InputCoordinate,
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
    func inputEditCommitted(input: InputCoordinate,
                            value: PortValue?,
                            wasAdjustmentBarSelection: Bool = false) {

        let nodeId = input.nodeId
        let coordinate = input

        // NOTE: THIS IS BAD; WE COMPARE THE INCOMING VALUE FROM THE COMMIT-ACTION AGAINST THE NODE SCHEMA, WHEREAS THE RELEVANT INPUT VALUE MIGHT INSTEAD BE FROM THE NODE VIEW MODEL IF WE HAD A HOSE-FLOW ETC.
        if var value = value {

            // if we had a value, and the value was different than the existing value,
            // THEN we detach the edge.
            guard let nodeViewModel = self.getNodeViewModel(nodeId),
                  let inputObserver = nodeViewModel.getInputRowObserver(for: input.portType) else {
                log("GraphState.inputEditCommitted error: could not find node data.")
                return
            }

            // Should be okay since whenever we connect an edge, we evaluate the node and thus extend its inputs and outputs.
            let valueAtIndex = inputObserver.getActiveValue(activeIndex: self.activeIndex)
            let nodeKind = nodeViewModel.kind
            let valueChange = (valueAtIndex != value)

            guard valueChange else {
                log("GraphState.inputEditCommitted: value did not change, so returning early")
                return
            }

            nodeViewModel.removeIncomingEdge(at: input,
                                             activeIndex: self.activeIndex)

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
            inputObserver.setValuesInInput([value])
            
            self.maybeCreateLLMSetInput(node: nodeViewModel,
                                        input: coordinate,
                                        value: value)
            
            self.calculate(coordinate.nodeId)
        }
    }
}
