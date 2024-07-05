//
//  TextEditActions.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/1/22.
//

import Foundation
import StitchSchemaKit

// Note: used by number inputs etc. but not by JSON etc.
extension GraphState {
    @MainActor
    func inputEdited(fieldValue: FieldValue,
                     // Single-fields always 0, multi-fields are like size or position inputs
                     fieldIndex: Int,
                     inputField: InputFieldViewModel,
                     isCommitting: Bool = true) {

        //        #if DEV_DEBUG
        //        log("InputEdited: fieldValue: \(fieldValue)")
        //        log("InputEdited: fieldIndex: \(fieldIndex)")
        //        log("InputEdited: coordinate: \(coordinate)")
        //        #endif

        guard let rowViewModel = inputField.rowViewModelDelegate,
              let rowObserver = rowViewModel.rowDelegate,
              let nodeId = rowViewModel.nodeDelegate?.id,
              let nodeViewModel = self.getNodeViewModel(nodeId) else {
            log("InputEdited error: no parent values list found.")
            return
        }
//        
//        let parentPortValuesList = rowObserver.allLoopedValues
//
//        let loopIndex = self.graphUI.activeIndex.adjustedIndex(parentPortValuesList.count)
//
//        guard let parentPortValue = parentPortValuesList[safe: loopIndex] else {
//            log("InputEdited error: no parent value found.")
//            return .noChange
//        }
        
        let parentPortValue = rowViewModel.activeValue

        //        log("InputEdited: state.graphUI.focusedField: \(state.graphUI.focusedField)")

        let newValue = parentPortValue.parseInputEdit(fieldValue: fieldValue, fieldIndex: fieldIndex)

        //        log("InputEdited: newValue: \(newValue)")
        //        log("InputEdited: parentPortValue: \(parentPortValue)")

        // Only remove edges and recalc graph if value changed,
        // e.g. editing "2" to "2." or even "2.0" should not remove the edge.
        if newValue != parentPortValue {

            // MARK: very important to remove edges before input changes
            nodeViewModel.removeIncomingEdge(at: rowObserver.id,
                                             activeIndex: self.activeIndex)

            rowObserver.setValuesInInput([newValue])
        }
        
        self.calculate(nodeViewModel.id)

        if isCommitting {
            self.maybeCreateLLMSetField(node: nodeViewModel,
                                              input: rowObserver.id,
                                              fieldIndex: fieldIndex,
                                              value: newValue)
        }
        
        self.encodeProjectInBackground()
    }
}
