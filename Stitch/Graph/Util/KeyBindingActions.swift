//
//  KeyBindingActions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/21/22.
//

import SwiftUI
import StitchSchemaKit

extension NodeRowViewModelId {
    var asNodeIOCoordinate: NodeIOCoordinate {
        NodeIOCoordinate(portType: self.portType,
                         nodeId: self.nodeId)
    }
}

struct UpArrowPressed: GraphEvent {
    
    func handle(state: GraphState) {
        if let activelyFocusedTextFieldOnCanvas = state.graphUI.reduxFocusedField?.getTextInputEdit {
            log("UpArrowPressed: activelyFocusedTextFieldOnCanvas: \(activelyFocusedTextFieldOnCanvas)")
            // increment the value of the field
            
            // Treat this is as a user edit; find the string for the active
            let rowId = activelyFocusedTextFieldOnCanvas.rowId
            let nodeId = rowId.nodeId
            log("UpArrowPressed: nodeId: \(nodeId)")
            log("UpArrowPressed: rowId: \(rowId)")
            
            if let node = state.getNodeViewModel(nodeId),
               let rowViewModel = node.getInputRowViewModel(for: rowId) {
                
                
 //                ,
 //               let nodeRowObserver = node.getInputRowObserver(for: rowId.portType)
                
                
                let fieldObservers = rowViewModel.fieldValueTypes.first?.fieldObservers
                let fieldObserver = fieldObservers?[safeIndex: activelyFocusedTextFieldOnCanvas.fieldIndex]
                
                log("UpArrowPressed: fieldObserver?.fieldValue: \(fieldObserver?.fieldValue)")
                
                if let fieldObserver = fieldObserver {
                    switch fieldObserver.fieldValue {
                    case .number(let n):
                        log("UpArrowPressed: .number: n: \(n)")
                        state.inputEdited(fieldValue: FieldValue.number(n + 1),
                                          fieldIndex: activelyFocusedTextFieldOnCanvas.fieldIndex,
                                          coordinate: rowId.asNodeIOCoordinate,
                                          // does this matter? yes, for if we have edited a single field while actually multiple layers in the sidebar are selected
                                          isFieldInsideLayerInspector: false,
                                          isCommitting: true)
                        
                    case .layerDimension(let n):
                        log("UpArrowPressed: .layerDimension: n: \(n)")
                        switch n {
                        case .percent(let _n):
                            log("UpArrowPressed: .layerDimension: _n: \(_n)")
                            state.inputEdited(fieldValue: FieldValue.number(_n + 1),
                                              fieldIndex: activelyFocusedTextFieldOnCanvas.fieldIndex,
                                              coordinate: rowId.asNodeIOCoordinate,
                                              // does this matter? yes, for if we have edited a single field while actually multiple layers in the sidebar are selected
                                              isFieldInsideLayerInspector: false,
                                              isCommitting: true)
                        default:
                            log("UpArrowPressed: .layerDimension: did not have a number")
                        }
                    default:
                        log("UpArrowPressed: default: \(fieldObserver.fieldValue)")
                    }
                }
                
            }
        }
    }
}

/// Process arrow key events.
struct ArrowKeyPressed: GraphEvent {
    let arrowKey: ArrowKey

    func handle(state: GraphState) {
        log("ArrowKeyPressed: \(arrowKey) called.")

        // Update selected option for insert node menu
        if let activeNodeSelection = Self.willNavigateActiveNodeSelection(state.graphUI) {
            let insertNodeMenuState = state.graphUI.insertNodeMenuState

            switch arrowKey {
            case .up:
                state.graphUI.insertNodeMenuState.activeSelection =
                    Self.nodeMenuSelectionArrowUp(activeSelection: activeNodeSelection,
                                                  queryResults: insertNodeMenuState.searchResults)
            case .down:
                state.graphUI.insertNodeMenuState.activeSelection =
                    Self.nodeMenuSelectionArrowDown(activeSelection: activeNodeSelection,
                                                    queryResults: insertNodeMenuState.searchResults)
            default:
                return
            }
        }

        // Pan graph if no menu
        // TODO pan graph
        return
    }

    @MainActor
    private static func willNavigateActiveNodeSelection(_ graphUI: GraphUIState) -> InsertNodeMenuOptionData? {
        let insertNodeMenuState = graphUI.insertNodeMenuState

        guard insertNodeMenuState.show else {
            return nil
        }
        return insertNodeMenuState.activeSelection
    }

    private static func nodeMenuSelectionArrowUp(activeSelection: InsertNodeMenuOptionData,
                                                 queryResults: [InsertNodeMenuOptionData]) -> InsertNodeMenuOptionData {
        // Find current index of active selection
        guard let currentIndex = queryResults
                .firstIndex(where: { $0.data == activeSelection.data }),
              let nextResult = queryResults[safe: currentIndex - 1] else {
            return activeSelection
        }

        return nextResult
    }

    private static func nodeMenuSelectionArrowDown(activeSelection: InsertNodeMenuOptionData,
                                                   queryResults: [InsertNodeMenuOptionData]) -> InsertNodeMenuOptionData {

        // Find current index of active selection
        guard let currentIndex = queryResults.firstIndex(where: { $0.data == activeSelection.data}),
              let prevResult = queryResults[safe: currentIndex + 1] else {
            return activeSelection
        }

        return prevResult
    }
}

extension StitchStore {
    @MainActor
    func escKeyPressed() {
        // Reset GraphUI state
        if let graphState = self.currentDocument?.visibleGraph {
            graphState.resetAlertAndSelectionState()
        }
        
        // Reset alert state
        self.alertState = ProjectAlertState()
    }
}
