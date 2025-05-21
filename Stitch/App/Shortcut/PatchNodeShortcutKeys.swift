//
//  PatchNodeShortcutKeys.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/8/24.
//

import Foundation
import SwiftUI

// MARK: PATCH SHORTCUTS

let ADD_PACK_NODE_SHORTCUT: KeyEquivalent = "P"
let ADD_UNPACK_NODE_SHORTCUT: KeyEquivalent = "U"

let ADD_SPLITTER_NODE_SHORTCUT: KeyEquivalent = "X"

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

// + shift = And
let POP_ANIMATION_NODE_SHORTCUT: KeyEquivalent = "A"

// N + shift = Not
let NOT_NODE_SHORTCUT: KeyEquivalent = "N"

let FLIP_SWITCH_NODE_SHORTCUT: KeyEquivalent = "S"
let DELAY_NODE_SHORTCUT: KeyEquivalent = "D"
let KEYBOARD_NODE_SHORTCUT: KeyEquivalent = "K"

// + shift = equals exactly
let EQUALS_NODE_SHORTCUT: KeyEquivalent = "E"

// + shift = progress
let REVERSE_PROGRESS_NODE_SHORTCUT: KeyEquivalent = "R"

let TRANSITION_NODE_SHORTCUT: KeyEquivalent = "T"
let PULSE_NODE_SHORTCUT: KeyEquivalent = "U"

// + shift = option switch
let PRESS_INTERACTION_NODE_SHORTCUT: KeyEquivalent = "I"

// + shift = or
let OPTION_PICKER_NODE_SHORTCUT: KeyEquivalent = "O"


// MARK: LAYER SHORCUTS

let OVAL_LAYER_SHORTCUT: KeyEquivalent = "O"
let RECTANGLE_LAYER_SHORTCUT: KeyEquivalent = "R"
let TEXT_LAYER_SHORTCUT: KeyEquivalent = "T"
//let GROUP_LAYER_SHORTCUT: KeyEquivalent = "G"
let HIT_AREA_LAYER_SHORTCUT: KeyEquivalent = "H"


// let SCROLL_NODE_SHORTCUT: KeyEquivalent = "Q"


extension Character {
    func layerFromShortcutKey() -> Layer? {
        let lowercaseCharacter = self.lowercased().toCharacter
        
        switch lowercaseCharacter {
        case OVAL_LAYER_SHORTCUT.character.lowercased().toCharacter:
            return .oval
        case RECTANGLE_LAYER_SHORTCUT.character.lowercased().toCharacter:
            return .rectangle
        case TEXT_LAYER_SHORTCUT.character.lowercased().toCharacter:
            return .text
//        case GROUP_LAYER_SHORTCUT.character.lowercased().toCharacter:
//            return .group
        case HIT_AREA_LAYER_SHORTCUT.character.lowercased().toCharacter:
            return .hitArea
        default:
            return nil
        }
    }
    
    func patchFromShortcutKey(isShiftDown: Bool) -> Patch? {
        log("patchFromShortcutKey: isShiftDown: \(isShiftDown)")
        
        let lowercaseCharacter = self.lowercased().toCharacter
        
        if isShiftDown {
            switch lowercaseCharacter {
                // Always requires shift ?
            case NOT_NODE_SHORTCUT.character.lowercased().toCharacter:
                return .not
            default:
                break
            }
        }
        
        switch lowercaseCharacter {
        
        case ADD_PACK_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .sizePack
            
        case ADD_UNPACK_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .sizeUnpack

        case ADD_SPLITTER_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .splitter
            
        case ADD_WIRELESS_NODE_SHORTCUT.character.lowercased().toCharacter:
            return isShiftDown ? .wirelessReceiver : .wirelessBroadcaster
            
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
            return isShiftDown ? .and : .popAnimation
        
        case FLIP_SWITCH_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .flipSwitch
        
        case DELAY_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .delay
        
        case KEYBOARD_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .keyboard
        
        case EQUALS_NODE_SHORTCUT.character.lowercased().toCharacter:
            return isShiftDown ? .equalsExactly : .equals
        
        case REVERSE_PROGRESS_NODE_SHORTCUT.character.lowercased().toCharacter:
            return isShiftDown ? .progress : .reverseProgress
        
        case TRANSITION_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .transition
        
        case PULSE_NODE_SHORTCUT.character.lowercased().toCharacter:
            return .pulse
        
        case PRESS_INTERACTION_NODE_SHORTCUT.character.lowercased().toCharacter:
            return isShiftDown ? .optionSwitch : .pressInteraction
        
        case OPTION_PICKER_NODE_SHORTCUT.character.lowercased().toCharacter:
            return isShiftDown ? .or : .optionPicker
        
        default:
            return nil
        }
    }
}
