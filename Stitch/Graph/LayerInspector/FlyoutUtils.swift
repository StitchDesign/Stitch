//
//  FlyoutUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/17/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI


extension LayerInputPort {
    

    // Note: most cases are just "is this multifield?", with exception of shadow inputs
    // NOTE: THIS IS ONLY USED BY TAB and SHIFT+TAB
    var usesFlyout: Bool {
        switch self {
            
        case
            // Any input that has multiple fields
                .position, .size, .padding, .layerMargin, .layerPadding, .minSize, .maxSize, .offsetInGroup, .pinOffset, .scrollContentSize, .scrollJumpToXLocation, .scrollJumpToYLocation,  .transform3D,
            // Shadow inputs: multiple single-field inputs presented in a flyout
                .shadowColor, .shadowOffset, .shadowRadius, .shadowOpacity, .size3D:
            
            return true
            
            // Everything else
        case .scale, .anchoring, .opacity, .zIndex, .masks, .color, .rotationX, .rotationY, .rotationZ, .lineColor, .lineWidth, .blur, .blendMode, .brightness, .colorInvert, .contrast, .hueRotation, .saturation, .pivot, .enabled, .blurRadius, .backgroundColor, .isClipped, .orientation, .isAnimating, .cameraDirection, .isCameraEnabled, .isShadowsEnabled, .shape, .strokePosition, .strokeWidth, .strokeColor, .strokeStart, .strokeEnd, .strokeLineCap, .strokeLineJoin, .coordinateSystem, .cornerRadius, .canvasLineColor, .canvasLineWidth, .text, .placeholderText, .fontSize, .textAlignment, .verticalAlignment, .textDecoration, .textFont, .image, .video, .model3D, .fitStyle, .clipped, .progressIndicatorStyle, .progress, .mapType, .mapLatLong, .mapSpan, .isSwitchToggled, .startColor, .endColor, .startAnchor, .endAnchor, .centerAnchor, .startAngle, .endAngle, .startRadius, .endRadius, .sfSymbol, .videoURL, .volume, .spacingBetweenGridColumns, .spacingBetweenGridRows, .itemAlignmentWithinGridCell, .sizingScenario, .widthAxis, .heightAxis, .contentMode, .spacing, .isPinned, .pinTo, .pinAnchor, .setupMode, .materialThickness, .deviceAppearance, .scrollXEnabled, .scrollJumpToXStyle, .scrollJumpToX, .scrollYEnabled, .scrollJumpToYStyle, .scrollJumpToY, .anchorEntity, .isEntityAnimating, .translation3DEnabled, .scale3DEnabled, .rotation3DEnabled, .isMetallic, .radius3D, .height3D, .layerGroupAlignment:
            
            return false
        }
    }
                
    func usesTextFields(_ layer: Layer) -> Bool {
        self.getDefaultValue(for: layer)
            .getNodeRowType(nodeIO: .input,
                            layerInputPort: self,
                            isLayerInspector: true)
            .inputUsesTextField(isLayerInputInspector: true)
    }
}

// Used by a given flyout view to update its read-height in state,
// for proper positioning.
struct UpdateFlyoutSize: GraphUIEvent {
    let size: CGSize
    
    func handle(state: GraphUIState) {
        state.propertySidebar.flyoutState?.flyoutSize = size
    }
}

struct FlyoutClosed: GraphUIEvent {
    func handle(state: GraphUIState) {
        state.closeFlyout()
    }
}

extension GraphUIState {
    @MainActor
    func closeFlyout() {
//        withAnimation {
            self.propertySidebar.flyoutState = nil
//        }
    }
}

struct FlyoutToggled: StitchDocumentEvent {
    
    let flyoutInput: LayerInputPort
    let flyoutNodeId: NodeId
    let fieldToFocus: FocusedUserEditField?
    
    func handle(state: StitchDocumentViewModel) {
        if let flyoutState = state.graphUI.propertySidebar.flyoutState,
           flyoutState.flyoutInput == flyoutInput,
           flyoutState.flyoutNode == flyoutNodeId {
            state.graphUI.closeFlyout()
        } else {
//            withAnimation {
            state.graphUI.propertySidebar.flyoutState = .init(
                    // TODO: assuming flyout state is packed here
                    flyoutInput: flyoutInput,
                    flyoutNode: flyoutNodeId)
            
            if let fieldToFocus = fieldToFocus {
                state.visibleGraph
                    .reduxFieldFocused(focusedField: fieldToFocus,
                                       graphUI: state.graphUI)
            }
            
//            }
        }
    }
}

struct LeftSidebarSet: GraphUIEvent {
    
    let open: Bool
    
    func handle(state: GraphUIState) {
        // Reset flyout
        state.closeFlyout()
        
        state.leftSidebarOpen = open
    }
}
