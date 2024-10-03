//
//  GraphCommands.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/22.
//

import SwiftUI
import StitchSchemaKit

let CMD_MODIFIER: EventModifiers = [.command]

// TODO: Why does SwiftUI commands API require "I" rather than "i"?
let INSERT_NODE_MENU_SHORTCUT: KeyEquivalent = "I"

let DUPLICATE_SELECTED_NODES_SHORTCUT: KeyEquivalent = "D"

let GROUP_LAYERS_SHORTCUT: KeyEquivalent = "G"

let DELETE_SELECTED_NODES_SHORTCUT: KeyEquivalent = .delete
let DELETE_SELECTED_NODES_SHORTCUT_MODIFIERS: EventModifiers = []

let ADD_PACK_NODE_SHORTCUT: KeyEquivalent = "P"

let ADD_UNPACK_NODE_SHORTCUT: KeyEquivalent = "U"

let NEW_PROJECT_SHORTCUT: KeyEquivalent = "n"

/*
 TODO: finalize `tab` shortcuts

 Why does `.tab` or eg `tab + shift + control` not work?

 Why does `.tab` or `'\t'` alone show up in Commands menu,
 and can be manually clicked from there,
 but the tab key itself does nothing?
 */

let CLOSE_GRAPH_SHORTCUT: KeyEquivalent = "W"

// TODO: Why does this have to be "A" rather than "a"?
let SELECT_ALL_NODES_SHORTCUT: KeyEquivalent = "A"

let CUT_SELECTED_NODES_SHORTCUT: KeyEquivalent = "X"
let COPY_SELECTED_NODES_SHORTCUT: KeyEquivalent = "C"
let PASTE_SELECTED_NODES_SHORTCUT: KeyEquivalent = "V"

let UNDO_SHORTCUT: KeyEquivalent = "Z"

enum ArrowKey {
    case up, down, left, right

    @MainActor
    var uiKeyCommand: String {
        switch self {
        case .up:
            return UIKeyCommand.inputUpArrow
        case .down:
            return UIKeyCommand.inputDownArrow
        case .left:
            return UIKeyCommand.inputLeftArrow
        case .right:
            return UIKeyCommand.inputRightArrow
        }
    }
}

extension String {
    var toCharacter: Character {
        Character(self)
    }
}

struct Qwerty: Equatable {

    static let qwertyLetters: [String] = [
        "q", "w", "e", "r", "t", "y", "u", "i", "o", "p",
        "a", "s", "d", "f", "g", "h", "j", "k", "l",
        "z", "x", "c", "v", "b", "n", "m"
    ]

    static let qwertyNumbers: [String] = [
        1, 2, 3, 4, 5, 6, 7, 8, 9, 0
    ].map(String.init)

    // For iPad, where pressesEnded works.
    static let qwertyOther: [String] = [
        "`", "-", "=",
        "[", "]", "\\",
        ";", "\'",
        ",", ".", "/"
        , " " // to handle spacebar on Catalyst
    ]

    // TODO: for our "broken Catalyst pressesEnded" workaround,
    // we need to explicitly add the e.g. SHIFT + SOME_KEY combo to our KeyAddedSet.
    static let qwertyNumbersShift: [String] = [
        "!", "@", "#", "$", "%", "^", "&", "*", "(", ")"
    ]

    static let qwertyOtherExpanded: [String] = Self.qwertyOther + [
        "~", "_", "+",
        "{", "}", "|",
        ":", "\"",
        "<", ">", "?"
    ]

}
