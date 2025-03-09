//
//  LayerInspectorRowButton.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/5/25.
//

import SwiftUI

struct LayerInspectorRowButton: View {
    
    @Environment(\.appTheme) var theme
    
    @Bindable var graph: GraphState
    @Bindable var graphUI: StitchDocumentViewModel
    let layerInputObserver: LayerInputObserver?
    let layerInspectorRowId: LayerInspectorRowId
    let coordinate: NodeIOCoordinate
    let canvasItemId: CanvasItemId?
    let isHovered: Bool
    
    // non-nil = this inspector row button is for a field, not a
    var fieldIndex: Int? = nil
    
    @MainActor
    var isWholeInputWithAtleastOneFieldAlreadyOnCanvas: Bool {
        if case let .layerInput(layerInputType) = layerInspectorRowId,
           layerInputType.portType == .packed,
           let layerInputObserver = layerInputObserver,
           layerInputObserver.observerMode.isUnpacked,
           !layerInputObserver.getAllCanvasObservers().isEmpty {
            return true
        }
        
        return false
    }
    
    var isPortSelected: Bool {
        graph.propertySidebar.selectedProperty == layerInspectorRowId
    }
    
    @MainActor
    var canBeAddedToCanvas: Bool {
        
        // If this is a button for a whole input,
        // and then input already has a field on the canvas,
        // then we cannot add the whole input to the canvas
        if isWholeInputWithAtleastOneFieldAlreadyOnCanvas {
            return false
        }
        
        switch layerInspectorRowId {
        case .layerInput(let layerInputType):
            return layerInputType.layerInput != SHADOW_FLYOUT_LAYER_INPUT_PROXY
        case .layerOutput:
            return true
        }
    }
    
    @MainActor
    var showButton: Bool {
        if canvasItemId.isDefined || isWholeInputWithAtleastOneFieldAlreadyOnCanvas ||  isHovered || (canBeAddedToCanvas && isPortSelected) {
            return true
        } else {
            return false
        }
    }
    
    @MainActor
    var imageString: String {
        if canvasItemId.isDefined {
            return "scope"
        } else if isWholeInputWithAtleastOneFieldAlreadyOnCanvas {
            return "circle.fill"
        } else {
            return "plus.circle"
        }
    }
        
    var body: some View {
        
        button(imageString: imageString) {
            
            let nodeId = coordinate.nodeId
            
            // If we're already on the canvas, jump to that canvas item
            if let canvasItemId = canvasItemId {
                graph.jumpToCanvasItem(id: canvasItemId,
                                       document: graphUI)
            }
            
            // Else we're adding an input (whole or field) or an output to the canvas
            else if let layerInput = coordinate.keyPath {
                
                if let fieldIndex = fieldIndex {
                    dispatch(LayerInputFieldAddedToGraph(layerInput: layerInput.layerInput,
                                                         nodeId: nodeId,
                                                         fieldIndex: fieldIndex))
                } else {
                    dispatch(LayerInputAddedToGraph(
                        nodeId: nodeId,
                        coordinate: layerInput))
                }
                
            } else if let portId = coordinate.portId {
                dispatch(LayerOutputAddedToGraph(nodeId: nodeId,
                                                 portId: portId))
            }
        }
        // Shrink down the dot view
        .scaleEffect(isWholeInputWithAtleastOneFieldAlreadyOnCanvas ? 0.5 : 1)
        
        // Only show the dot / plus button if we're hovering or row is selected or ...
        .opacity(showButton ? 1 : 0)
        
        .animation(.linear(duration: 0.1), value: showButton)
    }
    
    @MainActor
    func button(imageString: String,
                onTap: @escaping () -> Void) -> some View {
        Image(systemName: imageString)
            .resizable()
            .foregroundColor(isPortSelected ? theme.fontColor : .primary)
            .frame(width: LAYER_INSPECTOR_ROW_ICON_LENGTH,
                   height: LAYER_INSPECTOR_ROW_ICON_LENGTH) // per Figma
            .onTapGesture {
                onTap()
            }
    }
}
