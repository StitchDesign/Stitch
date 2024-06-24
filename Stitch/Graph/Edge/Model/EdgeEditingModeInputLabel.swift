//
//  EdgeEditingModeInputLabel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/31/24.
//

import SwiftUI

// Edge-Editing-Mode Button Label -> PortId on a node
enum EdgeEditingModeInputLabel: Equatable, Hashable, CaseIterable {
    // case 1, 2, 3, 4, 5, 6, 7, 8, 9 // Cannot use number literals as enum cases

    // labels for up to 19 ports (portId 0 -> 18); can expand later
    case one, two, three, four, five, six, seven, eight, nine, Q, W, E, R, T, Y, U, I, O, P
}

// MARK: DISPLAYING AN EDGE-EDIT-MODE LABEL TO A USER ON THE BUTTON

extension EdgeEditingModeInputLabel {

    // The value displayed on the edge-edit-mode button
    // in front of the input.
    var display: String {
        switch self {
        case .one:
            // TODO: will this be "1.0" ?
            return 1.description
        case .two:
            return 2.description
        case .three:
            return 3.description
        case .four:
            return 4.description
        case .five:
            return 5.description
        case .six:
            return 6.description
        case .seven:
            return 7.description
        case .eight:
            return 8.description
        case .nine:
            return 9.description
        case .Q:
            return "Q"
        case .W:
            return "W"
        case .E:
            return "E"
        case .R:
            return "R"
        case .T:
            return "T"
        case .Y:
            return "Y"
        case .U:
            return "U"
        case .I:
            return "I"
        case .O:
            return "O"
        case .P:
            return "P"
        }
    }
}

// MARK: TURNING A USER'S KEY CHAR PRESS INTO A KNOWN EDGE-EDIT-MODE LABEL

extension EdgeEditingModeInputLabel {

    // key char -> edge-edit-mode input label
    static func fromKeyCharacter(_ char: Character) -> Self? {
        let string: String = String(char)

        switch string {
        case "1":
            return .one
        case "2":
            return .two
        case "3":
            return .three
        case "4":
            return .four
        case "5":
            return .five
        case "6":
            return .six
        case "7":
            return .seven
        case "8":
            return .eight
        case "9":
            return .nine
        case "q":
            return .Q
        case "w":
            return .W
        case "e":
            return .E
        case "r":
            return .R
        case "t":
            return .T
        case "y":
            return .Y
        case "u":
            return .U
        case "i":
            return .I
        case "o":
            return .O
        case "p":
            return .P
        default:
            log("fromKeyCharacter: default for char: \(char)")
            return nil
        }
    }
}

// MARK: CONVERTING BETWEEN EDGE-EDIT-MODE LABELS AND A NODE'S PORT ID NUMBERS

extension EdgeEditingModeInputLabel {

    // edge-edit-mode label -> portId;
    // for creating an edge from a process key char press.
    // Alternatively?: make this enum CaseIterable, and use case's index + 1
    var toPortId: Int {
        switch self {
        case .one:
            return 0 // first index
        case .two:
            return 1
        case .three:
            return 2
        case .four:
            return 3
        case .five:
            return 4
        case .six:
            return 5
        case .seven:
            return 6
        case .eight:
            return 7
        case .nine:
            return 8
        case .Q:
            return 9
        case .W:
            return 10
        case .E:
            return 11
        case .R:
            return 12
        case .T:
            return 13
        case .Y:
            return 14
        case .U:
            return 15
        case .I:
            return 16
        case .O:
            return 17
        case .P:
            return 18
        }
    }
}

extension Int {
    // portId -> edge-edit-mode input label;
    // for turning a node's input port to a known label.
    var toEdgeEditingModeInputLabel: EdgeEditingModeInputLabel? {
        switch self {
        case 0:
            return .one
        case 1:
            return .two
        case 2:
            return .three
        case 3:
            return .four
        case 4:
            return .five
        case 5:
            return .six
        case 6:
            return .seven
        case 7:
            return .eight
        case 8:
            return .nine
        case 9:
            return .Q
        case 10:
            return .W
        case 11:
            return .E
        case 12:
            return .R
        case 13:
            return .T
        case 14:
            return .Y
        case 15:
            return .U
        case 16:
            return .I
        case 17:
            return .O
        case 18:
            return .P
        default:
            return nil // in this case, don't show the
        }
    }
}
