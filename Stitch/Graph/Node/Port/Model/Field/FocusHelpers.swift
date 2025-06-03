//
//  FocusHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/3/25.
//

import Foundation

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
            
        default:
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
