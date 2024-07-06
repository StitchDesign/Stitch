//
//  PreviewGridData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/23/24.
//

import SwiftUI
import StitchSchemaKit


// TODO: combine with Point4D ? Or will the names `x, y, z, w` be too unfamiliar vers `top`, `bottom` etc.; e.g. does `x` refer to `left` or `right`?
struct StitchPadding: Equatable, Hashable, Codable {
    var top: CGFloat = .zero
    var bottom: CGFloat = .zero
    var left: CGFloat = .zero
    var right: CGFloat = .zero

}

extension StitchPadding {
    init(_ number: CGFloat) {
        self.top = number
        self.bottom = number
        self.left = number
        self.right = number
    }
    
    static let zero: Self = Self.init(0)
}

extension Point4D {
    var toStitchPadding: StitchPadding {
        .init(top: self.x,
              bottom: self.y,
              left: self.z,
              right: self.w)
    }
}
                            
                            
extension StitchSpacing {
    
    static let defaultStitchSpacing: Self = .number(.zero)
    
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
            return x.description
        case .between:
            return "Between"
        case .evenly:
            return "Evenly"
        }
    }
}


struct PreviewGridData: Equatable {
    var horizontalSpacingBetweenColumns: StitchSpacing = .defaultStitchSpacing
    var verticalSpacingBetweenRows: StitchSpacing = .defaultStitchSpacing
    
    var alignmentOfItemWithinGridCell: Alignment = .center
    
    // Specific to LazyVGrid
    var horizontalAlignmentOfGrid: HorizontalAlignment = .center
}
