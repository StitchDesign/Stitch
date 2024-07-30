//
//  PreviewLayerDimensionModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/3/24.
//

import SwiftUI
import StitchSchemaKit

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

    // TODO: non-frame-growing views like `Text`, `ProgressIndicator` etc. need .frame(width:height:alignment:) to be properly positioned with their frame; such views' dimennsions cannot be split up across separate `.frame(width:)`, `.frame(height:)` calls.
    // Do you need an additional `pos: adjustPosition` modifier specifically for something like `Text` ?
    let alignment: Alignment
    
    let usesParentPercentForWidth: Bool
    let usesParentPercentForHeight: Bool
    
    // nil = dimension is unspecified
    let width: CGFloat?
    let height: CGFloat?
        
    let minWidth: CGFloat?
    let maxWidth: CGFloat?
    let minHeight: CGFloat?
    let maxHeight: CGFloat?
    
    var someMinMaxDefined: Bool {
        minOrMaxWidthIsDefined || minOrMaxHeightIsDefined
    }
    
    var minOrMaxWidthIsDefined: Bool {
        minWidth.isDefined || maxWidth.isDefined
    }
    
    var minOrMaxHeightIsDefined: Bool {
        minHeight.isDefined || maxHeight.isDefined
    }
    
   
    func body(content: Content) -> some View {
        //        logInView("LayerSizeModifier: alignment: \(alignment)")
        //
        //        logInView("LayerSizeModifier: usesParentPercentForWidth: \(usesParentPercentForWidth)")
        //        logInView("LayerSizeModifier: usesParentPercentForHeight: \(usesParentPercentForHeight)")
        //
        //        logInView("LayerSizeModifier: width: \(width)")
        //        logInView("LayerSizeModifier: height: \(height)")
        //
        //        logInView("LayerSizeModifier: minWidth: \(minWidth)")
        //        logInView("LayerSizeModifier: maxWidth: \(maxWidth)")
        //        logInView("LayerSizeModifier: minHeight: \(minHeight)")
        //        logInView("LayerSizeModifier: maxHeight: \(maxHeight)")
        //
               
        // TODO: the below conditionals can be simplified, but are currently evolving; will be cleaned up after final iterations on conditional input logic
        
        // Width is pt, but height is auto (so can use min/max height)
        if let width = width, !height.isDefined {
            //             logInView("LayerSizeModifier: defined width but not height")
            
            content
            // Note: parent-percentage supports min/max along a dimension
                .frame(minWidth: usesParentPercentForWidth ? minWidth : nil)
                .frame(maxWidth: usesParentPercentForWidth ? maxWidth : nil)
                .frame(width: width)
                .frame(minHeight: minHeight, maxHeight: maxHeight)
        }
        
        // Height is pt, but width is auto (so can use min/max width)
        else if let height = height, !width.isDefined {
            //             logInView("LayerSizeModifier: defined height but not width")
                
            content
                .frame(minHeight: usesParentPercentForHeight ? minHeight : nil)
                .frame(maxHeight: usesParentPercentForHeight ? maxHeight : nil)
                .frame(height: height)
                .frame(minWidth: minWidth, maxWidth: maxWidth)
        }
        
        // Both height and width are pt (so no min/max size at all)
        else if let width = width, let height = height {
            //             logInView("LayerSizeModifier: defined width and height")
            content
                .frame(minWidth: usesParentPercentForWidth ? minWidth : nil)
                .frame(maxWidth: usesParentPercentForWidth ? maxWidth : nil)
                .frame(width: width)
                .frame(minHeight: usesParentPercentForHeight ? minHeight : nil)
                .frame(maxHeight: usesParentPercentForHeight ? maxHeight : nil)
                .frame(height: height)
        }
        
        // Both height and width are auto, so use min/max height and width
        else if someMinMaxDefined {
            //             logInView("LayerSizeModifier: defined min-max")
            content.frame(minWidth: minWidth,
                          maxWidth: maxWidth,
                          minHeight: minHeight,
                          maxHeight: maxHeight,
                          alignment: alignment)
        } 
        
        // Default
        else {
            // logInView("LayerSizeModifier: default")
            content.frame(width: width,
                          height: height,
                          alignment: alignment)
        }
    }
}
