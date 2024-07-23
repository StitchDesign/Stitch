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
                     coordinate: NodeIOCoordinate,
                     isCommitting: Bool = true) {
        
        //        #if DEV_DEBUG
        //        log("InputEdited: fieldValue: \(fieldValue)")
        //        log("InputEdited: fieldIndex: \(fieldIndex)")
        //        log("InputEdited: coordinate: \(coordinate)")
        //        #endif
        
        guard let rowObserver = self.getInputRowObserver(coordinate) else {
            log("InputEdited error: no parent values list found.")
            return
        }
        
        rowObserver.inputEdited(graph: self,
                                fieldValue: fieldValue,
                                fieldIndex: fieldIndex,
                                isCommitting: isCommitting)
    }
}

extension InputNodeRowObserver {
    @MainActor
    func inputEdited(graph: GraphState,
                     fieldValue: FieldValue,
                     // Single-fields always 0, multi-fields are like size or position inputs
                     fieldIndex: Int,
                     isCommitting: Bool = true) {        
        guard let node = graph.getNodeViewModel(self.id.nodeId) else {
            fatalErrorIfDebug()
            return
        }
        
        let parentPortValue = self.activeValue

        //        log("InputEdited: state.graphUI.focusedField: \(state.graphUI.focusedField)")

        let newValue = parentPortValue.parseInputEdit(fieldValue: fieldValue, fieldIndex: fieldIndex)

        //        log("InputEdited: newValue: \(newValue)")
        //        log("InputEdited: parentPortValue: \(parentPortValue)")

        // Only remove edges and recalc graph if value changed,
        // e.g. editing "2" to "2." or even "2.0" should not remove the edge.
        if newValue != parentPortValue {

            // MARK: very important to remove edges before input changes
            node.removeIncomingEdge(at: self.id,
                                                  activeIndex: graph.activeIndex)

            self.setValuesInInput([newValue])
        }
        
        // If we edited a field on a layer-size input, we may need to block or unblock certain other fields.
        if let newSize = newValue.getSize,
           // Only look at size (not min/max size) changes
           self.id.keyPath == .size {
            node.layerSizeUpdated(newValue: newSize)
        }

        node.calculate()

        if isCommitting {
            graph.maybeCreateLLMSetInput(node: node,
                                         input: self.id,
                                         value: newValue)
        }
        
        graph.encodeProjectInBackground()
    }
}
