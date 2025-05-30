//
//  PreviewLayerTextUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

struct ReduxFieldFocused: StitchDocumentEvent {
    let focusedField: FocusedUserEditField

    func handle(state: StitchDocumentViewModel) {
        state.reduxFieldFocused(focusedField: focusedField)
    }
}

extension StitchDocumentViewModel {
    @MainActor
    var isSidebarFocused: Bool {
        switch self.reduxFocusedField {
        case .sidebar, .sidebarLayerTitle:
            return true
            
        default:
            return false
        }
    }
    
    @MainActor
    var isPrototypePreviewFocused: Bool {
        switch self.reduxFocusedField {
        case .prototypeWindow, .prototypeTextField:
            return true
            
        default:
            return false
        }
    }
}

extension FocusedUserEditField {
    var inputPortSelected: NodeRowViewModelId? {
        switch self {
        case .nodeInputPortSelection(let id):
            return id
            
        default:
            return nil
        }
    }
    
    var isInputPortSelected: Bool {
        self.inputPortSelected != nil
    }
    
    // Find the parent canvas item for this focused-field (whether a patch node, a layer input or layer output), and select that canvas item.
    var canvasFieldId: CanvasItemId? {
        switch self {
        case .textInput(let fieldCoordinate):
            switch fieldCoordinate.rowId.graphItemType {
            case .canvas(let x):
                // log("canvasFieldId: .textInput: .node: x \(x)")
                return x
            // TODO: what is a .textInput with a .layerInspector graphItemType?
            case .layerInspector:
                // log("canvasFieldId: .textInput: .layerInspector: x \(x)")
                return nil
            }
        case .nodeTitle(let stitchTitleEdit):
            switch stitchTitleEdit {
            case .canvas(let x):
                // log("canvasFieldId: .textInput: .canvas: x \(x)")
                return x
                // TODO: what is a .textInput with a .layerInspector graphItemType?
            case .layerInspector:
                // log("canvasFieldId: .textInput: .layerInspector: x \(x)")
                return nil
            }
        case .mathExpression(let nodeId):
            return CanvasItemId.node(nodeId)
            
        // TODO: update comment boxes to use CanvasItemId
        case .commentBox:
            return nil
            
        case .projectTitle, .jsonPopoverOutput, .insertNodeMenu, .textFieldLayer, .any, .llmRecordingModal, .stitchAIPromptModal, .sidebarLayerTitle, .previewWindowSettingsWidth, .previewWindowSettingsHeight, .prototypeWindow, .prototypeTextField, .sidebar, .nodeInputPortSelection, .aiPreviewerTextField:
            return nil
        }
    }
}

extension StitchDocumentViewModel {
    @MainActor
    func reduxFieldFocused(focusedField: FocusedUserEditField) {
        log("reduxFieldFocused: focusedField: \(focusedField)")
        log("reduxFieldFocused: self.reduxFocusedField was: \(self.reduxFocusedField)")
        let graph = self.visibleGraph
        
        if self.reduxFocusedField != focusedField {
            self.reduxFocusedField = focusedField
        }
        
        // if we selected a canvas item, we also thereby selected it:
        if let canvasItemId = focusedField.canvasFieldId {
            graph.selectSingleCanvasItem(canvasItemId)
        }
    }
    
    @MainActor
    func reduxFieldDefocused(focusedField: FocusedUserEditField) {
        log("reduxFieldDefocused: focusedField: \(focusedField)")
        log("reduxFieldDefocused: self.reduxFocusedField was: \(self.reduxFocusedField)")
        
        switch focusedField {
        case .sidebarLayerTitle:
            // Make sure focus state becomes the sidebar when submitting new layer text name
            self.reduxFocusedField = .sidebar
            
        default:
            if self.reduxFocusedField == focusedField {
                self.reduxFocusedField = nil
            }
        }
    }
}

struct ReduxFieldDefocused: StitchDocumentEvent {
    let focusedField: FocusedUserEditField
    
    func handle(state: StitchDocumentViewModel) {
        state.reduxFieldDefocused(focusedField: focusedField)
    }
}

// just directly update the output; don't even need the `edit` saved on the text-field layer view model?
//
struct TextFieldInputEdited: ProjectEnvironmentEvent {

    let id: PreviewCoordinate
    let newEdit: String

    func handle(graphState: GraphState,
                environment: StitchEnvironment) -> GraphResponse {

        // set the newEdit in the text field layer node's output (id.nodeId) at the given loop index (id.loopIndex)

        // log("TextFieldInputEdited called: id: \(id)")

        guard let layerNodeViewModel = graphState.getLayerNode(id.layerNodeId.id),
              let layerViewModelAtIndex = layerNodeViewModel.previewLayerViewModels[safe: id.loopIndex] else {
            log("TextFieldInputEdited: could not find layer node view model for \(id.layerNodeId) or layer view model for loop-index \(id.loopIndex)")
            return .noChange
        }

        layerViewModelAtIndex.text = .string(.init(newEdit))

        graphState.scheduleForNextGraphStep(id.layerNodeId.id)

        return .noChange
    }
}
