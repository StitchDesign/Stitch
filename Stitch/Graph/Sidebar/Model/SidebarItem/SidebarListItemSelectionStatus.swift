//
//  SelectionStatus.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/31/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

enum SidebarListItemSelectionStatus: Codable, Equatable {
    case primary, secondary, none // ie not selected

    // both primary and secondary count as 'being selected'
    var isSelected: Bool {
        switch self {
        case .primary, .secondary:
            return true
        case .none:
            return false
        }
    }
    
    // a secondarily- or hidden primarily-selected color has half the strength
    func color(_ isHidden: Bool) -> Color {
        switch self {
        // both primary selection and non-selection use white;
        // the difference whether the circle gets filled or not
        case .primary, .none:
            // return .white
            return SIDE_BAR_OPTIONS_TITLE_FONT_COLOR.opacity(isHidden ? 0.5 : 1)
        case .secondary:
            return SIDE_BAR_OPTIONS_TITLE_FONT_COLOR.opacity(0.5)
        }
    }
}

// what about when a group is collapsed?
func getSelectionStatus(_ id: LayerNodeId,
                        _ selections: SidebarSelectionState) -> SidebarListItemSelectionStatus {

    if selections.primary.contains(id) {
        return .primary
    } else if selections.secondary.contains(id) {
        return .secondary
    } else {
        return .none
    }

}
