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
        
        //        rowObserver.inputEdited(graph: self,
        //                                fieldValue: fieldValue,
        //                                fieldIndex: fieldIndex,
        //                                isCommitting: isCommitting)
        
        rowObserver.handleInputEdited(graph: self,
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
           self.id.keyPath?.layerInput == .size {
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
    
    @MainActor
    func handleInputEdited(graph: GraphState,
                           fieldValue: FieldValue,
                           // Single-fields always 0, multi-fields are like size or position inputs
                           fieldIndex: Int,
                           isCommitting: Bool = true) {

        // Check if this was an edit for a multiselect-layer field; if so, we need to modify ALL the input observers that were implicitly edited
        
        log("handleInputEdited: called for input node row observer \(self.id)")
        
        // If we're editing a layer input,
        if let layerInput = self.id.portType.keyPath?.layerInput,
           // and we have multiselect-layer state
           let multiselectObserver = graph.graphUI.propertySidebar.layerMultiselectObserver,
           // and we're editing the
           let layerMultiselectInput: LayerMultiselectInput = multiselectObserver.inputs.get(layerInput),
           
//           layerMultiselectInput.id == self.id {
           // Always test against first observer
           layerMultiselectInput.observers.first?.rowObserver.id == self.id {
        
            // Note: heterogenous values doesn't matter; only the multiselect does

            log("handleInputEdited: will update \(layerMultiselectInput.observers.count) observers")
            
            layerMultiselectInput.observers.forEach { observer in
                observer.rowObserver.inputEdited(graph: graph,
                                                 fieldValue: fieldValue,
                                                 fieldIndex: fieldIndex,
                                                 isCommitting: isCommitting)
            }
        }
        
        // ... else we're not editing a multiselect layer's field, so do the normal stuff
        else {
            log("handleInputEdited: NORMAL EDIT")
            self.inputEdited(graph: graph,
                             fieldValue: fieldValue,
                             fieldIndex: fieldIndex,
                             isCommitting: isCommitting)
        }
    }

}

