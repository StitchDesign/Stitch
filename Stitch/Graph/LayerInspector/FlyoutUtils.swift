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
    
    // Note: msot cases are just "is this multifield?", with exception of shadow inputs)
    var usesFlyout: Bool {
        switch self {
            
        case
            // Any input that has multiple fields
                .position, .size, .padding, .layerMargin, .layerPadding, .minSize, .maxSize, .offsetInGroup, .pinOffset,
            // Shadow inputs: multiple single-field inputs presented in a flyout
                .shadowColor, .shadowOffset, .shadowRadius, .shadowOpacity:
            
            return true
            
            // Everything else
        case .scale, .anchoring, .opacity, .zIndex, .masks, .color, .rotationX, .rotationY, .rotationZ, .lineColor, .lineWidth, .blur, .blendMode, .brightness, .colorInvert, .contrast, .hueRotation, .saturation, .pivot, .enabled, .blurRadius, .backgroundColor, .isClipped, .orientation, .isAnimating, .allAnchors, .cameraDirection, .isCameraEnabled, .isShadowsEnabled, .shape, .strokePosition, .strokeWidth, .strokeColor, .strokeStart, .strokeEnd, .strokeLineCap, .strokeLineJoin, .coordinateSystem, .cornerRadius, .canvasLineColor, .canvasLineWidth, .text, .placeholderText, .fontSize, .textAlignment, .verticalAlignment, .textDecoration, .textFont, .image, .video, .model3D, .fitStyle, .clipped, .progressIndicatorStyle, .progress, .mapType, .mapLatLong, .mapSpan, .isSwitchToggled, .startColor, .endColor, .startAnchor, .endAnchor, .centerAnchor, .startAngle, .endAngle, .startRadius, .endRadius, .sfSymbol, .videoURL, .volume, .spacingBetweenGridColumns, .spacingBetweenGridRows, .itemAlignmentWithinGridCell, .sizingScenario, .widthAxis, .heightAxis, .contentMode, .spacing, .isPinned, .pinTo, .pinAnchor, .setupMode:
            
            return false
        }

        
//        if self.usesPaddingFlyout {
//            return true
//        }
//        
//        if self.usesTwoFieldFlyout {
//            return true
//        }
//        
//        switch self {
//        case .padding, .layerMargin, .layerPadding,
//                .shadowColor, .shadowOffset, .shadowRadius, .shadowOpacity:
//            return true
//        default:
//            return false
//        }
        
        
    }
        
//    // TODO: COMPARE INPUT'S VALUES, NOT INPUT TYPE
//    var usesTwoFieldFlyout: Bool {
//        switch self {
//        case .size, .position, .offsetInGroup, .maxSize, .minSize:
//            return true
//        default:
//            return false
//        }
//    }
    
//    // TODO: better?: compare against the actual value in the input, rather than on the input's keyword
//    // But in some contexts we don't have access to the input?
    // TODO: handle padding same as
//    var usesPaddingFlyout: Bool {
//        switch self {
//        case .padding, .layerPadding, .layerMargin:
//            return true
//        default:
//            return false
//        }
//    }
        
    func usesTextFields(_ layer: Layer) -> Bool {
        self.getDefaultValue(for: layer)
            .getNodeRowType(nodeIO: .input)
            .inputUsesTextField
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
    func closeFlyout() {
//        withAnimation {
            self.propertySidebar.flyoutState = nil
//        }
    }
}

struct FlyoutToggled: GraphUIEvent {
    
    let flyoutInput: LayerInputPort
    let flyoutNodeId: NodeId
    
    func handle(state: GraphUIState) {
        if let flyoutState = state.propertySidebar.flyoutState,
           flyoutState.flyoutInput == flyoutInput,
           flyoutState.flyoutNode == flyoutNodeId {
            state.closeFlyout()
        } else {
//            withAnimation {
                state.propertySidebar.flyoutState = .init(
                    // TODO: assuming flyout state is packed here
                    flyoutInput: flyoutInput,
                    flyoutNode: flyoutNodeId)
//            }
        }
    }
}

struct LeftSidebarToggled: GraphUIEvent {
    
    func handle(state: GraphUIState) {
        // Reset flyout
        state.closeFlyout()
    }
}
