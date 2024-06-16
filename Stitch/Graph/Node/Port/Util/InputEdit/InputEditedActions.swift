//
//  TextEditActions.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/1/22.
//

import Foundation
import StitchSchemaKit

// Note: used by number inputs etc. but not by JSON etc.
struct InputEdited: ProjectEnvironmentEvent {

    let fieldValue: FieldValue

    // Single-fields always 0, multi-fields are like size or position inputs
    let fieldIndex: Int

    let coordinate: InputCoordinate

    var isCommitting: Bool = true

    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {

        //        #if DEV_DEBUG
        //        log("InputEdited: fieldValue: \(fieldValue)")
        //        log("InputEdited: fieldIndex: \(fieldIndex)")
        //        log("InputEdited: coordinate: \(coordinate)")
        //        #endif

        let coordinate = coordinate

        guard let nodeViewModel = graphState.getNodeViewModel(coordinate.nodeId),
              let parentPortValuesList = nodeViewModel
            .getInputRowObserver(for: coordinate.portType)?.allLoopedValues else {
            log("InputEdited error: no parent values list found.")
            return .noChange
        }

        guard let nodeViewModel = graphState.getNodeViewModel(coordinate.nodeId),
              let inputObserver = nodeViewModel
            .getInputRowObserver(for: coordinate.portType) else {
            log("InputEdited error: could not retrieve node schema for node \(coordinate.nodeId).")
            return .noChange
        }

        let loopIndex = graphState.graphUI.activeIndex.adjustedIndex(parentPortValuesList.count)

        guard let parentPortValue = parentPortValuesList[safe: loopIndex] else {
            log("InputEdited error: no parent value found.")
            return .noChange
        }

        //        log("InputEdited: state.graphUI.focusedField: \(state.graphUI.focusedField)")

        let newValue = parentPortValue.parseInputEdit(fieldValue: fieldValue, fieldIndex: fieldIndex)

        //        log("InputEdited: newValue: \(newValue)")
        //        log("InputEdited: parentPortValue: \(parentPortValue)")

        // Only remove edges and recalc graph if value changed,
        // e.g. editing "2" to "2." or even "2.0" should not remove the edge.
        if newValue != parentPortValue {

            // MARK: very important to remove edges before input changes
            nodeViewModel.removeIncomingEdge(at: coordinate,
                                             activeIndex: graphState.activeIndex)

            inputObserver.setValuesInInput([newValue])
        }
        
        graphState.calculate(nodeViewModel.id)

        if isCommitting {
            graphState.maybeCreateLLMSetField(node: nodeViewModel,
                                              input: coordinate,
                                              fieldIndex: fieldIndex,
                                              value: newValue)
        }
        
        return .init(willPersist: isCommitting)
    }
}
