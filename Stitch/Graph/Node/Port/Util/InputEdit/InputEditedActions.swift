//
//  TextEditActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/1/22.
//

import Foundation
import StitchSchemaKit

// Note: used by number inputs etc. but not by JSON etc.
extension GraphState {
    // Called from CommonEditingView, AdjustmentBar etc.
    @MainActor
    func inputEditedFromUI(fieldValue: FieldValue,
                           // Single-fields always 0, multi-fields are like size or position inputs
                           fieldIndex: Int,
                           coordinate: NodeIOCoordinate,
                           isFieldInsideLayerInspector: Bool,
                           isCommitting: Bool = true) {
        
        //        log("inputEdited: fieldValue: \(fieldValue)")
        //        log("inputEdited: fieldIndex: \(fieldIndex)")
        //        log("inputEdited: coordinate: \(coordinate)")
        //        log("inputEdited: isFieldInsideLayerInspector: \(isFieldInsideLayerInspector)")
        //        log("inputEdited: isCommitting: \(isCommitting)")
        
        guard let rowObserver = self.getInputRowObserver(coordinate) else {
            log("inputEdited error: no parent values list found.")
            return
        }

        rowObserver.handleInputEdited(graph: self,
                                      fieldValue: fieldValue,
                                      fieldIndex: fieldIndex,
                                      isFieldInsideLayerInspector: isFieldInsideLayerInspector,
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

        //        log("inputEdited: fieldValue: \(fieldValue)")
        //        log("inputEdited: fieldIndex: \(fieldIndex)")
        
        let newValue = parentPortValue.parseInputEdit(fieldValue: fieldValue, fieldIndex: fieldIndex)

        //        log("inputEdited: newValue: \(newValue)")
        //        log("inputEdited: parentPortValue: \(parentPortValue)")

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
           self.id.keyPath?.layerInput == .size,
           let layerNode = node.layerNode {
            
            layerNode.layerSizeUpdated(newValue: newSize)
        }

        node.calculate()
    }
    
    @MainActor
    func handleInputEdited(graph: GraphState,
                           fieldValue: FieldValue,
                           // Single-fields always 0, multi-fields are like size or position inputs
                           fieldIndex: Int,
                           isFieldInsideLayerInspector: Bool,
                           isCommitting: Bool = true) {
                
        // If we're in the layer inspector and have selected multiple layers,
        // we'll actually update more than one input.
        if let layerMultiselectInput = graph.getLayerMultiselectInput(
            layerInput: self.id.portType.keyPath?.layerInput,
            isFieldInsideLayerInspector: isFieldInsideLayerInspector) {
            
            layerMultiselectInput.multiselectObservers(graph).forEach { observer in
                observer.rowObserver.inputEdited(graph: graph,
                                                 fieldValue: fieldValue,
                                                 fieldIndex: fieldIndex,
                                                 isCommitting: isCommitting)
            }
        }
        
        // ... else we're not editing a multiselect layer's field, so do the normal stuff
        else {
            self.inputEdited(graph: graph,
                             fieldValue: fieldValue,
                             fieldIndex: fieldIndex,
                             isCommitting: isCommitting)
        }
        
        if isCommitting {
            graph.encodeProjectInBackground()
        }
    }
}

extension NodeIOCoordinate {
    var layerInput: LayerInputType? {
        self.portType.keyPath
    }
}

extension GraphState {

    @MainActor
    func getLayerMultiselectInput(for layerInput: LayerInputPort) -> LayerInputPort? {
        self.graphUI.propertySidebar
            .inputsCommonToSelectedLayers?
            .first(where: { $0 == layerInput })
    }
}
