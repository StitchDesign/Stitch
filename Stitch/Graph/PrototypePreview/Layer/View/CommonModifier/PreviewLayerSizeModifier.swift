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
    
//    var finalMinWidth: CGFloat? {
//        // no matter what is passed in, if we are using parent-percent al
//    }
//    var finalMaxWidth: CGFloat? {
//        // no matter what is passed in, if we are using parent-percent al
//    }
//    var finalMinHeight: CGFloat? {
//        // no matter what is passed in, if we are using parent-percent al
//    }
//    var finalMaxHeight: CGFloat? {
//        // no matter what is passed in, if we are using parent-percent al
//    }
//
    
//    let width: LayerDimension?
//    let height: LayerDimension?
//        
//    let minWidth: LayerDimension?
//    let maxWidth: LayerDimension?
//    let minHeight: LayerDimension?
//    let maxHeight: LayerDimension?
    
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
        logInView("LayerSizeModifier: width: \(width)")
        logInView("LayerSizeModifier: height: \(height)")
        logInView("LayerSizeModifier: minWidth: \(minWidth)")
        logInView("LayerSizeModifier: maxWidth: \(maxWidth)")
        logInView("LayerSizeModifier: minHeight: \(minHeight)")
        logInView("LayerSizeModifier: maxHeight: \(maxHeight)")
                
        // Width is pt, but height is auto (so can use min/max height)
        if let width = width, !height.isDefined {
            logInView("LayerSizeModifier: defined width but not height")
            
            // How to handle case where "set width, but non-nil min and max width passed down"
            
            content
            // parent percentage supports min/max along a dimension
                .frame(minWidth: usesParentPercentForWidth ? minWidth : nil)
                .frame(maxWidth: usesParentPercentForWidth ? maxWidth : nil)
                .frame(width: width)
                .frame(minHeight: minHeight, maxHeight: maxHeight)
            
            // ^^ this will mess up the `alignment` for views like `Text`, `ProgressIndicator` etc.
            // Do you need an additional `pos: adjustPosition` modifier specifically for something like `Text` ?
        } 
        
        // Height is pt, but width is auto (so can use min/max width)
        else if let height = height, !width.isDefined {
            logInView("LayerSizeModifier: defined height but not width")
            
            content
                .frame(minHeight: usesParentPercentForHeight ? minHeight : nil)
                .frame(maxHeight: usesParentPercentForHeight ? maxHeight : nil)
                .frame(height: height)
                .frame(minWidth: minWidth, maxWidth: maxWidth)
        }
        
        // Both height and width are pt (so no min/max size at all)
        else if let width = width, let height = height {
            logInView("LayerSizeModifier: defined width and height")
            
            
            content
//                .frame(width: width, height: height)
            
                .frame(minWidth: usesParentPercentForWidth ? minWidth : nil)
                .frame(maxWidth: usesParentPercentForWidth ? maxWidth : nil)
                .frame(width: width)
            
                .frame(minHeight: usesParentPercentForHeight ? minHeight : nil)
                .frame(maxHeight: usesParentPercentForHeight ? maxHeight : nil)
                .frame(height: height)
        }
        
        // Both height and width are auto, so use min/max height and width
        else if someMinMaxDefined {
            logInView("LayerSizeModifier: defined min-max")
            content.frame(minWidth: minWidth,
                          maxWidth: maxWidth,
                          minHeight: minHeight,
                          maxHeight: maxHeight,
                          alignment: alignment)
        } 
        
        // Default case
        else {
            logInView("LayerSizeModifier: default")
            content.frame(width: width,
                          height: height,
                          alignment: alignment)
        }

                
//
//        if someDimensionFixed {
//            content
//                .frame(width: width?.atleastZero(),
//                       height: height?.atleastZero(),
//                       alignment: alignment)
//            
//        } else {
//                        
//            // If we have at least one min-max dimension,
//            // we cannot use the `.frame(width:height:)` API
//            //        if someMinMaxDefined {
//            content.frame(minWidth: minWidth?.atleastZero(),
//                          maxWidth: maxWidth?.atleastOne(),
//                          minHeight: minHeight?.atleastZero(),
//                          maxHeight: maxHeight?.atleastOne(),
//                          alignment: alignment)
//        }
//        
        
        //        } else {
        //            content
        //            .frame(width: width?.atleastZero(),
        //                          height: height?.atleastZero(),
        //                          alignment: alignment)
        //        }
    }
}
