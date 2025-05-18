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
    let layerInputObserver: LayerInputObserver?
    let layerInspectorRowId: LayerInspectorRowId
    let coordinate: NodeIOCoordinate
    let packedInputCanvasItemId: CanvasItemId?
    let isHovered: Bool
    let usesThemeColor: Bool
    
    // non-nil = this inspector row button is for a field, not an input
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
        if packedInputCanvasItemId.isDefined {
            return true
        }
        
        if isWholeInputWithAtleastOneFieldAlreadyOnCanvas {
            return true
        }
        
        if isHovered {
            return true
        }
        
        if canBeAddedToCanvas, usesThemeColor {
            return false
        }
        
        return false
    }
    
    @MainActor
    var imageString: String {
        if packedInputCanvasItemId.isDefined {
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
            if let canvasItemId = packedInputCanvasItemId {
                dispatch(JumpToCanvasItem(id: canvasItemId))
            }
            
            // Else we're adding an input (whole or field) or an output to the canvas
            else if let layerInput = coordinate.keyPath {
                
                if let fieldIndex = fieldIndex,
                   // Only for unpacked
                   layerInput.portType != .packed {
                    dispatch(LayerInputFieldAddedToCanvas(layerInput: layerInput.layerInput,
                                                         fieldIndex: fieldIndex))
                    
                } else if layerInput.portType == .packed {
                    // Only for packed
                    dispatch(LayerInputAddedToCanvas(layerInput: layerInput.layerInput))
                }
                
            } else if let portId = coordinate.portId {
                dispatch(LayerOutputAddedToCanvas(nodeId: nodeId,
                                                 portId: portId))
            }
        }
        .modifier(TrackInspectorInput(
            layerInputObserver: layerInputObserver,
            // Technically, field index is just for use of flyout and irrelevant to "dragged edge onto inspector" ?
//            fieldIndex: self.fieldIndex,
            fieldIndex: nil,
            hasActivelyDrawnEdge: graph.edgeDrawingObserver.drawingGesture.isDefined))
        
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
            .foregroundColor(usesThemeColor ? theme.fontColor : .primary)
            .frame(width: LAYER_INSPECTOR_ROW_ICON_LENGTH,
                   height: LAYER_INSPECTOR_ROW_ICON_LENGTH) // per Figma
            .onTapGesture {
                onTap()
            }
    }
}
