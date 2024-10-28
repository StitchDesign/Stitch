//
//  SelectionStatus.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/31/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

enum SidebarListItemSelectionStatus {
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
}
