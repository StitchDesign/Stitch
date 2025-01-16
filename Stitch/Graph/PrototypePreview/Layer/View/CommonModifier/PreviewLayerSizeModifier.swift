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

extension Layer {
    /*
     Does this layer's view has an 'inherent SwiftUI size'?
     
     e.g. Text and Toggle views in SwiftUI have inherent sizes which do not expand when we apply a larger .frame;
     compare vs. a SwiftUI Ellipse which expands to fill its provided .frame.
     
     Note: for now, we consider media layers to NOT have an inherent SwiftUI size, although the resource has an inherent size.
     */
    // TODO: treat media as having inherent-size?
    var hasInherentSwiftUISize: Bool {
        switch self {
        case .text, .textField, .progressIndicator, .switchLayer:
            return true
        case .oval, .rectangle, .image, .group, .video, .model3D, .realityView, .shape, .colorFill, .hitArea, .canvasSketch, .map, .linearGradient, .radialGradient, .angularGradient, .sfSymbol, .videoStreaming, .material, .box, .sphere, .cylinder, .cone:
            return false
        }
    }
    
    var canUseAutoLayerDimension: Bool {
        if self.hasInherentSwiftUISize {
            return true
        } else {
            switch self {
            case .image, .video, .videoStreaming:
                return true
            default:
                return false
            }
        }
    }
}

// Directly calling SwiftUI's .frame API
// NOTE: it is the responsibility of the caller to make sure that sensible nil/non-nil params are passed in
struct LayerSizeModifier: ViewModifier {
    
    @Bindable var viewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    
    // TODO: non-frame-growing views like `Text`, `ProgressIndicator` etc. need .frame(width:height:alignment:) to be properly positioned with their frame; such views' dimennsions cannot be split up across separate `.frame(width:)`, `.frame(height:)` calls.
    // Do you need an additional `pos: adjustPosition` modifier specifically for something like `Text` ?
    let alignment: Alignment
    
    let usesParentPercentForWidth: Bool
    let usesParentPercentForHeight: Bool
    
    let usesFillForWidth: Bool
    let usesFillForHeight: Bool
    
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
    
   // If we are using `fill`, our `width` will actually be our
    var finalMaxWidth: CGFloat? {
        if usesFillForWidth {
            return width
        } else if usesParentPercentForWidth {
            return maxWidth
        } else {
            return nil
        }
    }
    
    var finalMaxHeight: CGFloat? {
        if usesFillForHeight {
            return height
        } else if usesParentPercentForHeight {
            return maxHeight
        } else {
            return nil
        }
    }
    
    func body(content: Content) -> some View {
        
        // TODO: remove once this view is cleaned up; but very helpful for debugging atm
        //        logInView("LayerSizeModifier: BODY")
        //        logInView("LayerSizeModifier: alignment: \(alignment)")
        //
        //        logInView("LayerSizeModifier: usesParentPercentForWidth: \(usesParentPercentForWidth)")
        //        logInView("LayerSizeModifier: usesParentPercentForHeight: \(usesParentPercentForHeight)")
        //
        //        logInView("LayerSizeModifier: usesFillForWidth: \(usesFillForWidth)")
        //        logInView("LayerSizeModifier: usesFillForHeight: \(usesFillForHeight)")
        //
        //        logInView("LayerSizeModifier: width: \(width)")
        //        logInView("LayerSizeModifier: height: \(height)")
        //
        //        logInView("LayerSizeModifier: minWidth: \(minWidth)")
        //        logInView("LayerSizeModifier: maxWidth: \(maxWidth)")
        //        logInView("LayerSizeModifier: minHeight: \(minHeight)")
        //        logInView("LayerSizeModifier: maxHeight: \(maxHeight)")
        //
        //        logInView("LayerSizeModifier: finalMaxHeight: \(finalMaxHeight)")
        //        logInView("LayerSizeModifier: finalMaxWidth: \(finalMaxWidth)")
        
               
        // TODO: the below conditionals can be simplified, but are currently evolving; will be cleaned up after final iterations on conditional input logic
        
        // TODO: we can break a `.frame(width:height,alignment:)` modifier into into separate `.frame(width:alignment:)`, `.frame(height:alignment:)` modifiers and `alignment` will still work.
        
        
        if isPinnedViewRendering && (viewModel.isPinned.getBool ?? false) {
            // logInView("LayerSizeModifier: will use pinned size for layer \(viewModel.layer), pinnedSize: \(viewModel.pinnedSize)")
              // If this is the "PinnedView" for View A,
              // then View A's "GhostView" will already have read the appropriate size etc. for View A.
              // So we can just use the layer view model's pinnedSize
              content.frame(width: viewModel.pinnedSize?.width,
                            height: viewModel.pinnedSize?.height,
                            alignment: alignment)
          }
        
        // Width is pt, but height is auto (so can use min/max height)
        else if let width = width, !height.isDefined {
            // logInView("LayerSizeModifier: defined width but not height")
            
            content
            // Note: parent-percentage supports min/max along a dimension
                .frame(minWidth: usesParentPercentForWidth ? minWidth : nil)
            
            // If we are using width = fill, then passed-in width will actually be parent-length,
            // and we should supply `.frame(width = nil)` but `.frame(maxWidth = passed-in-width)`
                .frame(maxWidth: finalMaxWidth, alignment: alignment)
                .frame(width: usesFillForWidth ? nil : width,
                       alignment: alignment)
                
                .frame(minHeight: minHeight,
                       maxHeight: maxHeight,
                       alignment: alignment)
        }
        
        // Height is pt, but width is auto (so can use min/max width)
        else if let height = height, !width.isDefined {
            // logInView("LayerSizeModifier: defined height but not width")
                
            content
                .frame(minHeight: usesParentPercentForHeight ? minHeight : nil, alignment: alignment)
                .frame(maxHeight: finalMaxHeight, alignment: alignment)
            
                .frame(height: usesFillForHeight ? nil : height,
                       alignment: alignment)
            
                .frame(minWidth: minWidth,
                       maxWidth: finalMaxWidth,
                       alignment: alignment)
        }
        
        // Both height and width are pt (so no min/max size at all)
        else if let width = width, let height = height {
            // logInView("LayerSizeModifier: defined width and height")
            content
                .frame(minWidth: usesParentPercentForWidth ? minWidth : nil, alignment: alignment)
                .frame(maxWidth: finalMaxWidth, alignment: alignment)
            
                .frame(width: usesFillForWidth ? nil : width,
                       alignment: alignment)
            
                .frame(minHeight: usesParentPercentForHeight ? minHeight : nil, alignment: alignment)
                .frame(maxHeight: finalMaxHeight, alignment: alignment)
            
                .frame(height: usesFillForHeight ? nil : height,
                       alignment: alignment)
        }
        
        // Both height and width are auto, so use min/max height and width
        else if someMinMaxDefined {
            // logInView("LayerSizeModifier: defined min-max")
            content.frame(minWidth: minWidth,
                          maxWidth: finalMaxWidth,
                          minHeight: minHeight,
                          maxHeight: finalMaxHeight,
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
