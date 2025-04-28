//
//  PreviewGridData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/23/24.
//

import SwiftUI
import StitchSchemaKit

let WIDTH_FIELD_INDEX = 0
let HEIGHT_FIELD_INDEX = 1

extension StitchPadding {    
    static let zero: StitchPadding = .init(top: .zero,
                                           right: .zero,
                                           bottom: .zero,
                                           left: .zero)
    
    static let defaultPadding = Self.zero
    
    static let demoPadding = Self.init(top: 8, right: 8, bottom: 8, left: 8)
}
                       
struct PreviewGridData: Equatable {
    var horizontalSpacingBetweenColumns: StitchSpacing = .defaultStitchSpacing
    var verticalSpacingBetweenRows: StitchSpacing = .defaultStitchSpacing
    
    var alignmentOfItemWithinGridCell: Alignment = .center
    
    // Specific to LazyVGrid
    var horizontalAlignmentOfGrid: HorizontalAlignment = .center
}
