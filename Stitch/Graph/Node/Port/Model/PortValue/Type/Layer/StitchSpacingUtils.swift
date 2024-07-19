//
//  StitchSpacingUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/18/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension String {
    static let EVENLY_SPACING_STRING = "evenly"
    static let BETWEEN_SPACING_STRING = "between"
}


extension StitchSpacing {
    
    static func fromUserEdit(edit: String) -> StitchSpacing? {
        if edit.lowercased() == .EVENLY_SPACING_STRING {
            return .evenly
        } else if edit.lowercased() == .BETWEEN_SPACING_STRING {
            return .between
        } else {
            return nil
        }
    }
    
    // StitchSpacing's dropdown excludes the .number case
    static let choices: [String] = [
        Self.evenly.display, Self.between.display
    ]
    
    static let defaultStitchSpacing: Self = .zero

    static let zero: Self = .number(.zero)
    
    var isEvenly: Bool {
        self == .evenly
    }
    
    var isBetween: Bool {
        self == .between
    }
    
    // TODO: how to handle `evenly` and `between` spacing in adaptive grid?
    var asPointSpacing: CGFloat {
        switch self {
        case .evenly, .between:
            return .zero
        case .number(let x):
            return x
        }
    }
    
    var display: String {
        switch self {
        case .number(let x):
            return GlobalFormatter.string(for: x) ?? x.description
        case .between:
            return "Between"
        case .evenly:
            return "Evenly"
        }
    }
}
