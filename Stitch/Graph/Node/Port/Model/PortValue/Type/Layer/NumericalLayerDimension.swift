//
//  NumericalLayerDimension.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/3/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// TODO: compose LayerDimension as two separate enums?: `(Number, ParentPercent) || (Hug || Grow || Auto)`
// Not bad; but what happens with e.g. media's `auto` setting?
enum UnspecifiedLayerDimension: Equatable, Codable, Hashable {
    case hug, // parent shrinks to hug child
         grow // child expands to fill parent
}

// What a user can select / enter within a min/max-height/width field

// Min/max lengths (if we have one) can only be Number || ParentPercent
enum NumericalLayerDimension: Equatable, Codable, Hashable {
    case number(CGFloat),
         // parentPercent(100), // use 100% of parent dimenion
         // parentPercent(50) // use 50% of parent dimension
         parentPercent(Double)
    
    func asFrameDimension(_ parentLength: CGFloat) -> CGFloat {
           switch self {
           case .number(let x):
               return x
           case .parentPercent(let x):
               return parentLength * (x/100)
           }
       }
}
