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
