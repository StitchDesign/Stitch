//
//  FocusedUserEditField.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/2/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

/*
 There are many different kinds of fields a user could edit,
 e.g. breadcrumb, node title, node input, adjustment bar, ...

 But we can only edit one such field at a time.
 Hence an enum.

 NOTE: adjustment bar is no longer handled here since we can no longer handle its opening and closing via redux.
 */
enum FocusedUserEditField: Equatable, Hashable {
    case textInput(FieldCoordinate), // focused text input
         nodeTitle(StitchTitleEdit), // focused stitch's title text
         mathExpression(NodeId), // editing a math expression
         projectTitle, // i.e. for Catalyst
         // when a JSON Popover output is open,
         // we can't edit it;
         // but it counts as an "input" for the purposes of disabling "select all nodes" CMD+A.
         jsonPopoverOutput(OutputCoordinate),
         commentBox(CommentBoxId),
         insertNodeMenu,
         textFieldLayer(PreviewCoordinate), // specific loop-index
         any,    // default option
         llmRecordingModal,
         stitchAIPromptModal,
         sidebarLayerTitle(String),
         previewWindowSettingsWidth,
         previewWindowSettingsHeight

    var getTextFieldLayerInputEdit: PreviewCoordinate? {
        switch self {
        case .textFieldLayer(let x):
            return x
        default:
            return nil
        }
    }

    var getTextInputEdit: FieldCoordinate? {
        switch self {
        case .textInput(let fieldCoordinate):
            return fieldCoordinate
        default:
            return nil
        }
    }
    
    @MainActor
    func inputTextFieldWithNumberIsFocused(_ graph: GraphState) -> Bool {
        guard let focusedField = self.getTextInputEdit else {
            return false
        }
        
        // Determine whether the focused-field has a number (numeric or percentage);
        // if not, then up and down arrow keys should be passed down like normal.
        let rowId = focusedField.rowId
        
        if let rowViewModel = graph.getInputRowViewModel(for: rowId),
           let fieldObserver = rowViewModel.cachedFieldGroups.first?.fieldObservers[safeIndex: focusedField.fieldIndex] {
            return fieldObserver.fieldValue.isNumberForArrowKeyIncrementAndDecrement
        }
        return false
    }

    var getNodeTitleEdit: StitchTitleEdit? {
        switch self {
        case .nodeTitle(let id):
            return id
        default:
            return nil
        }
    }
}

enum StitchTitleEdit: Equatable, Hashable {
    case canvas(CanvasItemId)
    case layerInspector(NodeId)
}
