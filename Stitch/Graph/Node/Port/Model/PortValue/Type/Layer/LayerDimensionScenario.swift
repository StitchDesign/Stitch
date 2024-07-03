//
//  LayerDimensionScenario.swift
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
    
    func asCGFloat(_ parentLength: CGFloat) -> CGFloat {
        switch self {
        case .number(let x):
            return x
        case .parentPercent(let x):
            return parentLength * (x/100)
        }
    }
}

/// Making layer properties (e.g.`constrainHeight: Bool`, `height: CGFloat`, `minHeight: CGFloat?` etc.)
/// friendly for SwiftUI's .frame API.
/// e.g. `.frame(height:)` and `.frame(minHeight:)` are mutually exclusive.
enum LayerDimensionScenario {
    
    // LayerDimension.auto, .hug, .fill: all use `nil` i.e. are of unspecified length
    // A constrained dimension is also of unspecified length.
    case unspecified,
         
         // LayerDimension.number or .parentPercent(ParentSize)
         // Assumes .parentPercent has already been turned into a number via parentSize
         set(CGFloat),

         // We must have either min, or max, or both
         min(CGFloat), // min length only
         max(CGFloat), // max length only
         minAndMax(min: CGFloat, max: CGFloat) // both min and max length
}

extension LayerDimensionScenario {
    static func fromLayerDimension(_ layerDimension: LayerDimension?,
                                   parentLength: CGFloat,
                                   // `true` just if `ConstrainedDimension` is defined for this dimension
                                   constrained: Bool = false,
                                   minLength: NumericalLayerDimension? = nil,
                                   maxLength: NumericalLayerDimension? = nil) -> LayerDimensionScenario {
        
        let minLength = minLength?.asCGFloat(parentLength)
        let maxLength = maxLength?.asCGFloat(parentLength)
        
        if constrained {
            return .unspecified
        } else if let minLength = minLength,
           let maxLength = maxLength {
            return .minAndMax(min: minLength, max: maxLength)
        } else if let minLength = minLength {
            return .min(minLength)
        } else if let maxLength = maxLength {
            return .max(maxLength)
        }

        guard let layerDimension = layerDimension else {
            // If no layerDimension then we should have had at least constraint or min or max
            fatalErrorIfDebug()
            return .unspecified
        }
        
        switch layerDimension {
            // fill or hug = no set value along this dimension
        case .fill, .hug,
            // auto on shapes = fill
            // auto on text, textfield = hug
            // auto on media = see either image or video display views
            .auto:
            return .unspecified
            
        case .number(let x):
            return .set(x)

        case .parentPercent(let x):
            return .set(parentLength * (x/100))
        }
    }
}

