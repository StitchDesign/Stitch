//
//  FlyoutUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/17/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI


extension LayerInputType {
    var usesFlyout: Bool {
        switch self {
        case .padding, .shadowColor, .shadowOffset, .shadowRadius, .shadowOpacity:
            return true
        default:
            return false
        }
    }
    
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
        withAnimation {
            self.propertySidebar.flyoutState = nil
        }
    }
}

struct FlyoutToggled: GraphUIEvent {
    
    let flyoutInput: LayerInputType
    let flyoutNodeId: NodeId
    
    func handle(state: GraphUIState) {
        if let flyoutState = state.propertySidebar.flyoutState,
           flyoutState.flyoutInput == flyoutInput,
           flyoutState.flyoutNode == flyoutNodeId {
            state.closeFlyout()
        } else {
//            withAnimation {
                state.propertySidebar.flyoutState = .init(
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
