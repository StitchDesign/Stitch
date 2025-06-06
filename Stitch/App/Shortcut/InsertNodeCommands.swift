//
//  InsertNodeCommands.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/19/25.
//

import SwiftUI

extension StitchDocumentViewModel {
    @MainActor
    var shouldDisablePatchShortcuts: Bool {
        switch self.reduxFocusedField {
        case .any, .none, .nodeInputPortSelection:
            // Disable all scenarios except when there's any selection, no selection, or an input port is selected
            return false
        default:
            return true
        }
    }
    
    @MainActor
    var shouldDisableLayerShortcuts: Bool {
        switch self.reduxFocusedField {
        case .sidebarLayerTitle:
            return true
        default:
            return false
        }
    }
    
    @MainActor
    var isLayerSidebarFocused: Bool {
        switch self.reduxFocusedField {
        case .sidebarLayerTitle, .sidebar:
            return true
        default:
            return false
        }
    }
}

struct InsertNodeCommands: View {
    @AppStorage(StitchAppSettings.IS_OPTION_REQUIRED_FOR_SHORTCUTS.rawValue) private var isOptionRequired: Bool = Bool.defaultIsOptionRequiredForShortcuts
    
    @Bindable var store: StitchStore
    @Bindable var document: StitchDocumentViewModel
    
    var isLayerSidebarFocused: Bool {
        document.isLayerSidebarFocused
    }
    
    var hasSelectedInput: Bool {
        self.store.currentDocument?.reduxFocusedField?.isInputPortSelected ?? false
    }
    
    var selectionLabel: String {
        isLayerSidebarFocused ? "Layer" : "Patch"
    }
    
    var shouldDisablePatch: Bool {
        document.shouldDisablePatchShortcuts
    }
    
    var shouldDisableLayer: Bool {
        document.shouldDisableLayerShortcuts
    }
    
    var modifiersAdjustedForOptionRequirement: EventModifiers {
        isOptionRequired ? [.option] : []
    }
    
    var shiftModifiersAdjustedForOptionRequirement: EventModifiers {
        isOptionRequired ? [.option, .shift] : [.shift]
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
                dispatch(NodeCreatedWhileInputSelected(patch: .sizeUnpack))
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
                dispatch(NodeCreatedWhileInputSelected(patch: .sizePack))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.sizePack)))
            }
        }
        
        SwiftUIShortcutView(title: "Value",
                            key: ADD_SPLITTER_NODE_SHORTCUT,
                            // empty list = do not require CMD
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
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
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            
            // Note: Wireless Broadcaster does not expose any outputs, so cannot be "inserted upstream from a selected input";
            // so we instead insert a wireless-receiver.
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .wirelessReceiver))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.wirelessBroadcaster)))
            }
            
            // TODO: probably not needed?
            store.currentDocument?.keypressState.modifiers.remove(.option)
        }
        
        // Option + Shift + W = add Receiver
        SwiftUIShortcutView(title: "Wireless Receiver",
                            key: ADD_WIRELESS_NODE_SHORTCUT,
                            eventModifiers:  shiftModifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .wirelessReceiver))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.wirelessReceiver)))
            }
            
            // Note: the Option key seems to get stuck easily when Shift is also pressed?
            store.currentDocument?.keypressState.modifiers.remove(.option)
            store.currentDocument?.keypressState.modifiers.remove(.shift)
        }
        
        Divider()
        
        // TODO: maybe it would be better if these options did not all show up in the Graph menu on Catalyst?
        SwiftUIShortcutView(title: "Add",
                            key: ADD_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .add))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.add)))
            }
        }
        
        SwiftUIShortcutView(title: "Subtract",
                            key: SUBTRACT_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .subtract))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.subtract)))
            }
        }
        
        SwiftUIShortcutView(title: "Multiply",
                            key: MULTIPLY_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .multiply))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.multiply)))
            }
        }
        
        SwiftUIShortcutView(title: "Divide",
                            key: DIVIDE_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .divide))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.divide)))
            }
        }
        
        SwiftUIShortcutView(title: "Power",
                            key: POWER_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .power))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.power)))
            }
        }
        
        SwiftUIShortcutView(title: "Mod",
                            key: MOD_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .mod))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.mod)))
            }
        }
        
        Divider()
        
        SwiftUIShortcutView(title: "Less Than",
                            key: LESS_THAN_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .lessThan))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.lessThan)))
            }
        }
        
        SwiftUIShortcutView(title: "Greater Than",
                            key: GREATER_THAN_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .greaterThan))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.greaterThan)))
            }
        }
        
        SwiftUIShortcutView(title: "Equals",
                            key: EQUALS_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .equals))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.equals)))
            }
        }
        
        SwiftUIShortcutView(title: "Equals Exactly",
                            key: EQUALS_NODE_SHORTCUT,
                            eventModifiers: shiftModifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .equalsExactly))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.equalsExactly)))
            }
        }
        
        Divider()
        
        SwiftUIShortcutView(title: "Classic Animation",
                            key: CLASSIC_ANIMATION_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .classicAnimation))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.classicAnimation)))
            }
        }
        
        SwiftUIShortcutView(title: "Pop Animation",
                            key: POP_ANIMATION_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .popAnimation))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.popAnimation)))
            }
        }
                
        Divider()
        
        SwiftUIShortcutView(title: "Not",
                            key: NOT_NODE_SHORTCUT,
                            eventModifiers: shiftModifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .not))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.not)))
            }
        }
        
        SwiftUIShortcutView(title: "And",
                            key: POP_ANIMATION_NODE_SHORTCUT,
                            eventModifiers: shiftModifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .and))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.and)))
            }
        }
        
        SwiftUIShortcutView(title: "Or",
                            key: OPTION_PICKER_NODE_SHORTCUT,
                            eventModifiers: shiftModifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .or))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.or)))
            }
        }
        
        Divider()
        
        SwiftUIShortcutView(title: "Switch",
                            key: FLIP_SWITCH_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .flipSwitch))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.flipSwitch)))
            }
        }
        
        SwiftUIShortcutView(title: "Option Picker",
                            key: OPTION_PICKER_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .optionPicker))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.optionPicker)))
            }
        }
        
        SwiftUIShortcutView(title: "Option Switch",
                            key: PRESS_INTERACTION_NODE_SHORTCUT,
                            eventModifiers: shiftModifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .optionSwitch))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.optionSwitch)))
            }
        }
        
        SwiftUIShortcutView(title: "Progress",
                            key: REVERSE_PROGRESS_NODE_SHORTCUT,
                            eventModifiers: shiftModifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .progress))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.progress)))
            }
        }
        
        SwiftUIShortcutView(title: "Reverse Progress",
                            key: REVERSE_PROGRESS_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .reverseProgress))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.reverseProgress)))
            }
        }
        
        SwiftUIShortcutView(title: "Transition",
                            key: TRANSITION_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .transition))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.transition)))
            }
        }
        
        SwiftUIShortcutView(title: "Pulse",
                            key: PULSE_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .pulse))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.pulse)))
            }
        }
        
        Divider()
        
        SwiftUIShortcutView(title: "Delay",
                            key: DELAY_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .delay))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.delay)))
            }
        }
        
        SwiftUIShortcutView(title: "Keyboard",
                            key: KEYBOARD_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .keyboard))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.keyboard)))
            }
        }
        
        SwiftUIShortcutView(title: "Press Interaction",
                            key: PRESS_INTERACTION_NODE_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisablePatch) {
            if hasSelectedInput {
                dispatch(NodeCreatedWhileInputSelected(patch: .pressInteraction))
            } else {
                dispatch(NodeCreatedEvent(choice: .patch(.pressInteraction)))
            }
        }
    }
    
    // Note: these can never be inserted "upstream" of a selected input
    @ViewBuilder
    var layers: some View {
        SwiftUIShortcutView(title: "Oval",
                            key: OVAL_LAYER_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisableLayer) {
            dispatch(NodeCreatedEvent(choice: .layer(.oval)))
        }

        SwiftUIShortcutView(title: "Rectangle",
                            key: RECTANGLE_LAYER_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisableLayer) {
            dispatch(NodeCreatedEvent(choice: .layer(.rectangle)))
        }
        
        Divider()
        
        SwiftUIShortcutView(title: "Text",
                            key: TEXT_LAYER_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisableLayer) {
            dispatch(NodeCreatedEvent(choice: .layer(.text)))
        }
        
        
        SwiftUIShortcutView(title: "Hit Area",
                            key: HIT_AREA_LAYER_SHORTCUT,
                            eventModifiers: modifiersAdjustedForOptionRequirement,
                            disabled: self.shouldDisableLayer) {
            dispatch(NodeCreatedEvent(choice: .layer(.hitArea)))
        }
        
//        Divider()
        
//        SwiftUIShortcutView(title: "Group",
//                            key: GROUP_LAYER_SHORTCUT,
//                            eventModifiers: modifiersAdjustedForOptionRequirement,
//                            disabled: self.shouldDisableLayer) {
//            dispatch(NodeCreatedEvent(choice: .layer(.group)))
//        }
        
    }
}
