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
    
    var isLayerSidebarFocused: Bool {
        switch document.reduxFocusedField {
        case .sidebarLayerTitle, .sidebar:
            return true
        default:
            return false
        }
    }
    
    var hasSelectedInput: Bool {
        self.store.currentDocument?.selectedInput.isDefined ?? false
    }
    
    var selectionLabel: String {
        isLayerSidebarFocused ? "Layer" : "Patch"
    }
    
    var shouldDisablePatch: Bool {
        switch document.reduxFocusedField {
        case .any, .none:
            // Disable all scenarios except when there's any selection, no selection, or an input port is selected
            return false
        default:
            return true
        }
    }
    
    var shouldDisableLayer: Bool {
        switch document.reduxFocusedField {
        case .sidebarLayerTitle:
            return true
        default:
            return false
        }
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
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.sizeUnpack)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.sizeUnpack)))
            }
        }
        
        SwiftUIShortcutView(title: "Pack",
                            key: ADD_PACK_NODE_SHORTCUT,
                            // empty list = do not require CMD
                            eventModifiers: CMD_MODIFIER,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.sizePack)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.sizePack)))
            }
        }
        
        SwiftUIShortcutView(title: "Value",
                            key: ADD_SPLITTER_NODE_SHORTCUT,
                            // empty list = do not require CMD
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.splitter)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.splitter)))
            }
        }
        
        Divider()
        
        // Option + W = add Broadcaster
        SwiftUIShortcutView(title: "Wireless Broadcaster",
                            key: ADD_WIRELESS_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            dispatch(NodeCreatedEvent(choice: .patch(.wirelessBroadcaster)))
            // TODO: probably not needed?
            store.currentDocument?.keypressState.modifiers.remove(.option)
        }
        
        // Option + Shift + W = add Receiver
        SwiftUIShortcutView(title: "Wireless Receiver",
                            key: ADD_WIRELESS_NODE_SHORTCUT,
                            eventModifiers: [.option, .shift],
                            disabled: self.shouldDisablePatch) {
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
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.add)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.add)))
            }
        }
        
        SwiftUIShortcutView(title: "Subtract",
                            key: SUBTRACT_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.subtract)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.subtract)))
            }
        }
        
        SwiftUIShortcutView(title: "Multiply",
                            key: MULTIPLY_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.multiply)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.multiply)))
            }
        }
        
        SwiftUIShortcutView(title: "Divide",
                            key: DIVIDE_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.divide)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.divide)))
            }
        }
        
        SwiftUIShortcutView(title: "Power",
                            key: POWER_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.power)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.power)))
            }
        }
        
        SwiftUIShortcutView(title: "Mod",
                            key: MOD_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.mod)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.mod)))
            }
        }
        
        Divider()
        
        SwiftUIShortcutView(title: "Less Than",
                            key: LESS_THAN_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.lessThan)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.lessThan)))
            }
        }
        
        SwiftUIShortcutView(title: "Greater Than",
                            key: GREATER_THAN_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.greaterThan)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.greaterThan)))
            }
        }
        
        SwiftUIShortcutView(title: "Equals",
                            key: EQUALS_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.equals)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.equals)))
            }
        }
        
        Divider()
        
        SwiftUIShortcutView(title: "Classic Animation",
                            key: CLASSIC_ANIMATION_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.classicAnimation)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.classicAnimation)))
            }
        }
        
        SwiftUIShortcutView(title: "Pop Animation",
                            key: POP_ANIMATION_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.popAnimation)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.popAnimation)))
            }
        }
        
        Divider()
        
        SwiftUIShortcutView(title: "Switch",
                            key: FLIP_SWITCH_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.flipSwitch)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.flipSwitch)))
            }
        }
        
        SwiftUIShortcutView(title: "Option Picker",
                            key: OPTION_PICKER_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.optionPicker)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.optionPicker)))
            }
        }
        
        SwiftUIShortcutView(title: "Reverse Progress",
                            key: REVERSE_PROGRESS_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.reverseProgress)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.reverseProgress)))
            }
        }
        
        SwiftUIShortcutView(title: "Transition",
                            key: TRANSITION_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.transition)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.transition)))
            }
        }
        
        SwiftUIShortcutView(title: "Pulse",
                            key: PULSE_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.pulse)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.pulse)))
            }
        }
        
        Divider()
        
        SwiftUIShortcutView(title: "Delay",
                            key: DELAY_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.delay)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.delay)))
            }
        }
        
        SwiftUIShortcutView(title: "Keyboard",
                            key: KEYBOARD_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.keyboard)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.keyboard)))
            }
        }
        
        SwiftUIShortcutView(title: "Press Interaction",
                            key: PRESS_INTERACTION_NODE_SHORTCUT,
                            eventModifiers: [.option],
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .patch(.pressInteraction)))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.pressInteraction)))
            }
        }
    }
    
    @ViewBuilder
    var layers: some View {
        SwiftUIShortcutView(title: "Oval",
                            key: "O",
                            eventModifiers: [.option],
                            disabled: self.shouldDisableLayer) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .layer(.oval)))
            } else {
                dispatch(NodeCreatedEvent(choice: .layer(.oval)))
            }
        }

        SwiftUIShortcutView(title: "Rectangle",
                            key: "R",
                            eventModifiers: [.option],
                            disabled: self.shouldDisableLayer) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .layer(.rectangle)))
            } else {
                dispatch(NodeCreatedEvent(choice: .layer(.rectangle)))
            }
        }
        
        Divider()
        
        SwiftUIShortcutView(title: "Text",
                            key: "T",
                            eventModifiers: [.option],
                            disabled: self.shouldDisableLayer) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .layer(.text)))
            } else {
                dispatch(NodeCreatedEvent(choice: .layer(.text)))
            }
        }
        
        Divider()
        
        SwiftUIShortcutView(title: "Group",
                            key: "G",
                            eventModifiers: [.option],
                            disabled: self.shouldDisableLayer) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(choice: .layer(.group)))
            } else {
                dispatch(NodeCreatedEvent(choice: .layer(.group)))
            }
        }
        
    }
}
