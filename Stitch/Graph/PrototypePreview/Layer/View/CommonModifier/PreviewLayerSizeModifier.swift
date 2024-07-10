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
    
    func atleastOne() -> CGFloat {
        CGFloat.maximum(self, 1.0)
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
    
    // If user provided a pt  dimension (width or height),
    // then we must use SwiftUI's `.frame(width:height:)`.
    // Note that grow/hug for a dimension = `nil`, and so we can instead provide
    var someDimensionFixed: Bool {
        width.isDefined || height.isDefined
    }
    
    func body(content: Content) -> some View {
        
        if someDimensionFixed {
            content
                .frame(width: width?.atleastZero(),
                       height: height?.atleastZero(),
                       alignment: alignment)
            
        } else {
                        
            // If we have at least one min-max dimension,
            // we cannot use the `.frame(width:height:)` API
            //        if someMinMaxDefined {
            content.frame(minWidth: minWidth?.atleastZero(),
                          maxWidth: maxWidth?.atleastOne(),
                          minHeight: minHeight?.atleastZero(),
                          maxHeight: maxHeight?.atleastOne(),
                          alignment: alignment)
        }
        
        
        //        } else {
        //            content
        //            .frame(width: width?.atleastZero(),
        //                          height: height?.atleastZero(),
        //                          alignment: alignment)
        //        }
    }
}
