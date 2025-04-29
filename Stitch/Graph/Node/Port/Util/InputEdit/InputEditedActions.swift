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
                           rowId: NodeRowViewModelId,
                           activeIndex: ActiveIndex,
                           isFieldInsideLayerInspector: Bool,
                           isCommitting: Bool = true) {
        
        //        log("inputEdited: fieldValue: \(fieldValue)")
        //        log("inputEdited: fieldIndex: \(fieldIndex)")
        //        log("inputEdited: coordinate: \(coordinate)")
        //        log("inputEdited: isFieldInsideLayerInspector: \(isFieldInsideLayerInspector)")
        //        log("inputEdited: isCommitting: \(isCommitting)")
        
        if let rowObserver = self.getInputRowObserver(rowId.asNodeIOCoordinate) {
            rowObserver.handleInputEdited(graph: self,
                                          fieldValue: fieldValue,
                                          fieldIndex: fieldIndex,
                                          rowId: rowId,
                                          activeIndex: activeIndex,
                                          isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                          isCommitting: isCommitting)
        }
    }
}

extension LayerInputObserver {
    
    @MainActor
    func getInputNodeRowObserver(for fieldIndex: Int, _ graph: GraphState) -> InputNodeRowObserver? {
        
        guard let layerNode = graph.getNode(self.nodeId)?.layerNode else {
            return nil
        }
        
        let layerInputType = self.layerInputType(fieldIndex: fieldIndex)
        return layerNode[keyPath: layerInputType.layerNodeKeyPath].rowObserver
    }
}

extension InputNodeRowObserver {
    @MainActor
    func inputEdited(graph: GraphState,
                     fieldValue: FieldValue,
                     // Single-fields always 0, multi-fields are like size or position inputs
                     fieldIndex: Int,
                     rowId: NodeRowViewModelId, // debug assert onlu
                     activeIndex: ActiveIndex,
                     isCommitting: Bool = true) {
        
        guard let node = graph.getNode(self.id.nodeId) else {
            fatalErrorIfDebug()
            return
        }
    
        graph.confirmInputIsVisibleInFrame(self)
        
        let parentPortValue = self.getActiveValue(activeIndex: activeIndex)

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
                                    graph: graph)

            // TODO: better place for this?
            
            // Note: `graph.connectedEdges` is otherwise only called in `graph.initializeDelegate`,
            // which is called in e.g. `updateGraphData`
            // which is usually only called when some persistence-event occurs.
            // An input edit alone, however, does not cause persistence; otherwise we would stutter as we type.

            // graph.connectedEdges = graph.getVisualEdgeData(groupNodeFocused: graph.documentDelegate?.groupNodeFocused?.groupNodeId)
            
            // Note: need to do full update, since upstream output's port-color needs to change as well
            // TODO: APRIL 11: do we really need to do this?!
            guard let document = graph.documentDelegate else {
                fatalErrorIfDebug()
                return
            }
            graph.updateGraphData(document)
             
            
            self.setValuesInInput([newValue])
            
            // self.immediatelyUpdateFieldObserversAfterInputEdit(newValue)
        }
        
#if DEBUG || DEV_DEBUG
        let expectedFieldsUI: [FieldValues] = newValue.createFieldValuesList(
            nodeIO: .input,
            layerInputPort: rowId.portType.keyPath?.layerInput, // assume canvas
            // "Flyout with one field blocked" case is a little different (`[FieldValues].count` did not change); can dig deeper there if necessary, but for now can just isolate canvas incidents
            isLayerInspector: false)
        
        if let currentFieldsUI: [FieldValues] = graph.getInputRowViewModel(for: rowId)?.fieldsUIViewModel.cachedActiveValue
            .createFieldValuesList(nodeIO: .input,
                                   layerInputPort: rowId.portType.keyPath?.layerInput,
                                   isLayerInspector: false) {
            
            // If the underlying pre- and edit-values are the same, then the fields-UI ought to match
            if newValue == parentPortValue,
               !rowId.graphItemType.isLayerInspector {
                assertInDebug(expectedFieldsUI == currentFieldsUI)
            }
        }
#endif
            
        // Note: ALWAYS update the field observers; this handles a rare case where the row observer's value had changed but the cached-field-UI had not. We already handle cases like "When a canvas item comes on-screen again, update fields UI."
        // TODO: track down exactly how underlying row observer and cached/derived-fields-UI get out of sync. For now, this solution here (and in `inputEditCommitted`) work because they are true:
        self.immediatelyUpdateFieldObserversAfterInputEdit(newValue)
        
        node.scheduleForNextGraphStep()
    }
    
    @MainActor
    func handleInputEdited(graph: GraphState,
                           fieldValue: FieldValue,
                           // Single-fields always 0, multi-fields are like size or position inputs
                           fieldIndex: Int,
                           rowId: NodeRowViewModelId, // debug assert only
                           activeIndex: ActiveIndex,
                           isFieldInsideLayerInspector: Bool,
                           isCommitting: Bool = true) {
                
        // If we're in the layer inspector and have selected multiple layers,
        // we'll actually update more than one input.
        if let layerMultiselectInput = graph.getLayerMultiselectInput(
            layerInput: self.id.portType.keyPath?.layerInput,
            isFieldInsideLayerInspector: isFieldInsideLayerInspector) {
            
            layerMultiselectInput.multiselectObservers(graph).forEach { (observer: LayerInputObserver) in
                if let rowObserver = observer.getInputNodeRowObserver(for: fieldIndex, graph) {
                    rowObserver.inputEdited(graph: graph,
                                            fieldValue: fieldValue,
                                            fieldIndex: fieldIndex,
                                            rowId: rowId,
                                            activeIndex: activeIndex,
                                            isCommitting: isCommitting)
                    
                    let _ = rowObserver.getActiveValue(activeIndex: activeIndex)
                }
            }
        }
        
        // ... else we're not editing a multiselect layer's field, so do the normal stuff
        else {
            self.inputEdited(graph: graph,
                             fieldValue: fieldValue,
                             fieldIndex: fieldIndex,
                             rowId: rowId,
                             activeIndex: activeIndex,
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
        self.propertySidebar
            .inputsCommonToSelectedLayers?
            .first(where: { $0 == layerInput })
    }
}
