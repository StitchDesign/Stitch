//
//  PreviewLayerDimensionModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/3/24.
//

import SwiftUI

extension CGFloat {
    func atleastZero() -> CGFloat {
        CGFloat.maximum(self, .zero)
    }
}

// Directly calling SwiftUI's .frame API
// NOTE: it is the responsibility of the caller to make sure that sensible nil/non-nil params are passed in
struct LayerSizeModifier: ViewModifier {

    let alignment: Alignment
    
    // nil = dimension is unspecified
    
    let width: CGFloat?
    let height: CGFloat?
        
    let minWidth: CGFloat?
    let maxWidth: CGFloat?
    let minHeight: CGFloat?
    let maxHeight: CGFloat?
    
    var someMinMaxDefined: Bool {
        minWidth.isDefined || maxWidth.isDefined || minHeight.isDefined || maxHeight.isDefined
    }
    
    func body(content: Content) -> some View {
        
        // If we have at least one min-max dimension,
        // we cannot use the `.frame(width:height:)` API
        if someMinMaxDefined {
            content.frame(minWidth: minWidth?.atleastZero(),
                          maxWidth: maxWidth?.atleastZero(),
                          minHeight: minHeight?.atleastZero(),
                          maxHeight: maxHeight?.atleastZero(),
                          alignment: alignment)
        } else {
            content.frame(width: width?.atleastZero(),
                          height: height?.atleastZero(),
                          alignment: alignment)
        }
    }
}

//struct PreviewLayerSizeModifier: ViewModifier {
//    let dimension: LengthDimension
//    let scenario: LayerDimensionScenario
//    
//    func body(content: Content) -> some View {
//
//        switch scenario {
//
//        case .unspecified:
//            content
//            
//        case .set(let x):
//            switch dimension {
//            case .width:
//                content.frame(width: x.atleastZero())
//            case .height:
//                content.frame(height: x.atleastZero())
//            }
//            
//        case .min(let x):
//            switch dimension {
//            case .width:
//                content.frame(minWidth: x.atleastZero())
//            case .height:
//                content.frame(minHeight: x.atleastZero())
//            }
//            
//        case .max(let x):
//            switch dimension {
//            case .width:
//                content.frame(maxWidth: x.atleastZero())
//            case .height:
//                content.frame(maxHeight: x.atleastZero())
//            }
//            
//        case .minAndMax(let x, let y):
//            switch dimension {
//            case .width:
//                content.frame(minWidth: x.atleastZero(),
//                              maxWidth: y.atleastZero())
//            case .height:
//                content.frame(minHeight: x.atleastZero(),
//                              maxHeight: y.atleastZero())
//            }
//        }
//    }
//}
//
////#Preview {
////    PreviewLayerDimensionModifier()
////}
