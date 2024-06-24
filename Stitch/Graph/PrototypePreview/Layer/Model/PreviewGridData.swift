//
//  PreviewGridData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/23/24.
//

import SwiftUI

struct PreviewGridData: Equatable {
    var horizontalSpacingBetweenColumns: CGFloat = 0.0
    var verticalSpacingBetweenRows: CGFloat = 0.0
    
    var alignmentOfItemWithinGridCell: Alignment = .center
    
    // Specific to LazyVGrid
    var horizontalAlignmentOfGrid: HorizontalAlignment = .center
}
