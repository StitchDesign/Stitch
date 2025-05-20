//
//  InsertNodeCommands.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/19/25.
//

import SwiftUI

struct InsertNodeCommands: View {
    @Bindable var store: StitchStore
    @Bindable var document: StitchDocumentViewModel
    
    let textFieldFocused: Bool
    let hasSelectedInput: Bool
    
    var isLayerSidebarFocused: Bool {
        switch document.reduxFocusedField {
        case .sidebarLayerTitle, .sidebar:
            return true
        default:
            return false
        }
    }
    
    var selectionLabel: String {
        isLayerSidebarFocused ? "Layer" : "Patch"
    }
    
    var body: some View {
        Menu("Insert \(selectionLabel) Node") {
            if isLayerSidebarFocused {
                layers
            } else {
                patches
            }
        }
    }
    
    @ViewBuilder
    var patches: some View {
        SwiftUIShortcutView(title: "Unpack",
                            key: ADD_UNPACK_NODE_SHORTCUT,
                            // empty list = do not require CMD
                            eventModifiers: CMD_MODIFIER,
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .sizeUnpack))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.sizeUnpack)))
            }
        }
        
        SwiftUIShortcutView(title: "Pack",
                            key: ADD_PACK_NODE_SHORTCUT,
                            // empty list = do not require CMD
                            eventModifiers: CMD_MODIFIER,
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .sizePack))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.sizePack)))
            }
        }
        
        SwiftUIShortcutView(title: "Value",
                            key: ADD_SPLITTER_NODE_SHORTCUT,
                            // empty list = do not require CMD
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .splitter))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.splitter)))
            }
        }
        
        Divider()
        
        // Option + W = add Broadcaster
        SwiftUIShortcutView(title: "Wireless Broadcaster",
                            key: ADD_WIRELESS_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            dispatch(NodeCreatedEvent(choice: .patch(.wirelessBroadcaster)))
            // TODO: probably not needed?
            store.currentDocument?.keypressState.modifiers.remove(.option)
        }
        
        // Option + Shift + W = add Receiver
        SwiftUIShortcutView(title: "Wireless Receiver",
                            key: ADD_WIRELESS_NODE_SHORTCUT,
                            eventModifiers: [.option, .shift],
                            disabled: textFieldFocused) {
            dispatch(NodeCreatedEvent(choice: .patch(.wirelessReceiver)))
            // Note: the Option key seems to get stuck easily when Shift is also pressed?
            store.currentDocument?.keypressState.modifiers.remove(.option)
            store.currentDocument?.keypressState.modifiers.remove(.shift)
        }
        
        Divider()
        
        // TODO: maybe it would be better if these options did not all show up in the Graph menu on Catalyst?
        SwiftUIShortcutView(title: "Add",
                            key: ADD_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .add))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.add)))
            }
        }
        
        SwiftUIShortcutView(title: "Subtract",
                            key: SUBTRACT_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .subtract))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.subtract)))
            }
        }
        
        SwiftUIShortcutView(title: "Multiply",
                            key: MULTIPLY_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .multiply))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.multiply)))
            }
        }
        
        SwiftUIShortcutView(title: "Divide",
                            key: DIVIDE_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .divide))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.divide)))
            }
        }
        
        SwiftUIShortcutView(title: "Power",
                            key: POWER_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .power))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.power)))
            }
        }
        
        SwiftUIShortcutView(title: "Mod",
                            key: MOD_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .mod))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.mod)))
            }
        }
        
        Divider()
        
        SwiftUIShortcutView(title: "Less Than",
                            key: LESS_THAN_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .lessThan))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.lessThan)))
            }
        }
        
        SwiftUIShortcutView(title: "Greater Than",
                            key: GREATER_THAN_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .greaterThan))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.greaterThan)))
            }
        }
        
        SwiftUIShortcutView(title: "Equals",
                            key: EQUALS_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .equals))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.equals)))
            }
        }
        
        Divider()
        
        SwiftUIShortcutView(title: "Classic Animation",
                            key: CLASSIC_ANIMATION_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .classicAnimation))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.classicAnimation)))
            }
        }
        
        SwiftUIShortcutView(title: "Pop Animation",
                            key: POP_ANIMATION_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .popAnimation))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.popAnimation)))
            }
        }
        
        Divider()
        
        SwiftUIShortcutView(title: "Switch",
                            key: FLIP_SWITCH_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .flipSwitch))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.flipSwitch)))
            }
        }
        
        SwiftUIShortcutView(title: "Option Picker",
                            key: OPTION_PICKER_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .optionPicker))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.optionPicker)))
            }
        }
        
        SwiftUIShortcutView(title: "Reverse Progress",
                            key: REVERSE_PROGRESS_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .reverseProgress))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.reverseProgress)))
            }
        }
        
        SwiftUIShortcutView(title: "Transition",
                            key: TRANSITION_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .transition))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.transition)))
            }
        }
        
        SwiftUIShortcutView(title: "Pulse",
                            key: PULSE_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .pulse))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.pulse)))
            }
        }
        
        Divider()
        
        SwiftUIShortcutView(title: "Delay",
                            key: DELAY_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .delay))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.delay)))
            }
        }
        
        SwiftUIShortcutView(title: "Keyboard",
                            key: KEYBOARD_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .keyboard))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.keyboard)))
            }
        }
        
        SwiftUIShortcutView(title: "Press Interaction",
                            key: PRESS_INTERACTION_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: textFieldFocused) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .pressInteraction))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.pressInteraction)))
            }
        }
    }
    
    @ViewBuilder
    var layers: some View {
        Color.clear
    }
}
