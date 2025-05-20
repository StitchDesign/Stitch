//
//  PatchNodeShortcutKeys.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/8/24.
//

import Foundation
import SwiftUI


let ADD_PACK_NODE_SHORTCUT: KeyEquivalent = "P"
let ADD_UNPACK_NODE_SHORTCUT: KeyEquivalent = "U"

let ADD_SPLITTER_NODE_SHORTCUT: KeyEquivalent = "X"


// TODO: ineligible for input-selected ?

// Option + W = add Broadcaster
// Option + Shift + W = add Receiver
let ADD_WIRELESS_NODE_SHORTCUT: KeyEquivalent = "W"

let ADD_NODE_SHORTCUT: KeyEquivalent = "="
let SUBTRACT_NODE_SHORTCUT: KeyEquivalent = "-"
let MULTIPLY_NODE_SHORTCUT: KeyEquivalent = "8"
let DIVIDE_NODE_SHORTCUT: KeyEquivalent = "/"
let POWER_NODE_SHORTCUT: KeyEquivalent = "6"
let MOD_NODE_SHORTCUT: KeyEquivalent = "5"
let LESS_THAN_NODE_SHORTCUT: KeyEquivalent = ","
let GREATER_THAN_NODE_SHORTCUT: KeyEquivalent = "."

let CLASSIC_ANIMATION_NODE_SHORTCUT: KeyEquivalent = "C"
let POP_ANIMATION_NODE_SHORTCUT: KeyEquivalent = "A"
let FLIP_SWITCH_NODE_SHORTCUT: KeyEquivalent = "S"
let DELAY_NODE_SHORTCUT: KeyEquivalent = "D"
let KEYBOARD_NODE_SHORTCUT: KeyEquivalent = "K"
let EQUALS_NODE_SHORTCUT: KeyEquivalent = "E"
let REVERSE_PROGRESS_NODE_SHORTCUT: KeyEquivalent = "R"
let TRANSITION_NODE_SHORTCUT: KeyEquivalent = "T"
let PULSE_NODE_SHORTCUT: KeyEquivalent = "U"
let PRESS_INTERACTION_NODE_SHORTCUT: KeyEquivalent = "I"
let OPTION_PICKER_NODE_SHORTCUT: KeyEquivalent = "O"


// let SCROLL_NODE_SHORTCUT: KeyEquivalent = "Q"


extension Character {
    func patchFromShortcutKey() -> Patch? {
        switch self {
        case ADD_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .add
        case SUBTRACT_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .subtract
        case MULTIPLY_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .multiply
        case DIVIDE_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .divide
        case POWER_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .power
        case MOD_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .mod
        case LESS_THAN_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .lessThan
        case GREATER_THAN_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .greaterThan
        case CLASSIC_ANIMATION_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .classicAnimation
        case POP_ANIMATION_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .popAnimation
        case FLIP_SWITCH_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .flipSwitch
        case DELAY_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .delay
        case KEYBOARD_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .keyboard
        case EQUALS_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .equals
        case REVERSE_PROGRESS_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .reverseProgress
        case TRANSITION_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .transition
        case PULSE_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .pulse
        case PRESS_INTERACTION_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .pressInteraction
        case OPTION_PICKER_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .optionPicker
        default:
            return nil
        }
    }
}
