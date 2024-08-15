//
//  PreviewCommonSizeModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/3/24.
//

import SwiftUI
import StitchSchemaKit
 
extension LayerDimension {
    func asFrameDimension(_ parentLength: CGFloat) -> CGFloat? {
           switch self {
               // fill or hug = no set value along this dimension
           case .fill, .hug,
               // auto on shapes = fill
               // auto on text, textfield = hug
               // auto on media = see either image or video display views
                   .auto:
               return nil

           case .number(let x):
               return x
               
           case .parentPercent(let x):
               return parentLength * (x/100)
           }
       }
}

// Receives a variety of properties (width, minWidth, constrainedWidth etc.)
// and turns them into appropriate SwiftUI .frame and .aspectRatio API calls.
struct PreviewCommonSizeModifier: ViewModifier {
    
    @Bindable var viewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    
    let aspectRatio: AspectRatioData
    let size: LayerSize
    
    var width: LayerDimension { size.width }
    let minWidth: LayerDimension?
    let maxWidth: LayerDimension?
    
    var height: LayerDimension { size.height }
    let minHeight: LayerDimension?
    let maxHeight: LayerDimension?
    
    let parentSize: CGSize

    let sizingScenario: SizingScenario
        
    /*
     Only for:
     - Text and TextField layers, which have their own alignment (based on text-alignment and text-vertical-alignment);
     - Layer Groups, which alone their children
     
     Other layers should not use `.frame(alignment:)` since that interfaces with natural SwiftUI spacing of
     */
    
    // `.frame(alignment:)` only matters if there is a size gap between the layer and its frame; can happen for Text, TextField, ProgressIndicator and other native views which do not resize just by .frame
    let frameAlignment: Alignment

    var usesParentPercentForWidth: Bool {
        width.isParentPercentage
    }
    
    var usesParentPercentForHeight: Bool {
        height.isParentPercentage
    }
    
    var finalMinWidth: CGFloat? {
        minWidth?.asFrameDimension(parentSize.width)
    }
    
    var finalMaxWidth: CGFloat? {
        maxWidth?.asFrameDimension(parentSize.width)
    }
    
    var finalMinHeight: CGFloat? {
        minHeight?.asFrameDimension(parentSize.height)
    }
    
    var finalMaxHeight: CGFloat? {
        maxHeight?.asFrameDimension(parentSize.height)
    }
    
    var finalWidth: CGFloat? {
        if usesParentPercentForWidth && (finalMinWidth.isDefined || finalMaxWidth.isDefined) {
            return nil
        } else {
            return width.asFrameDimension(parentSize.width)
        }
    }
    
    var finalHeight: CGFloat? {
        if usesParentPercentForHeight && (finalMinHeight.isDefined || finalMaxHeight.isDefined) {
            return nil
        } else {
            return height.asFrameDimension(parentSize.height)
        }
    }
    
    
    func body(content: Content) -> some View {
        switch sizingScenario {
        case .auto:
            // logInView("case .auto")
            content
                .modifier(LayerSizeModifier(
                    viewModel: viewModel,
                    isPinnedViewRendering: isPinnedViewRendering,
                    alignment: frameAlignment,
                    usesParentPercentForWidth: usesParentPercentForWidth,
                    usesParentPercentForHeight: usesParentPercentForHeight,
                    width: finalWidth,
                    height: finalHeight,
                    minWidth: finalMinWidth,
                    maxWidth: finalMaxWidth,
                    minHeight: finalMinHeight,
                    maxHeight: finalMaxHeight
                ))
                .modifier(LayerSizeReader(viewModel: viewModel))
            
            // Note: the pinned view ("View A"), the ghost view AND the pin-receiver ("View B") need to read their preview-window-relative size and/or center
            // Does it matter whether this is applied before or after the other GR in LayerSizeReader?
                .modifier(PreviewWindowCoordinateSpaceReader(
                    viewModel: viewModel,
                    isPinnedViewRendering: isPinnedViewRendering))
            
        case .constrainHeight:
            // logInView("case .constrainHeight")
            content
            // apply `.aspectRatio` separately from `.frame(width:)` and `.frame(height:)`
                .modifier(PreviewAspectRatioModifier(data: aspectRatio))
                .modifier(LayerSizeModifier(
                    viewModel: viewModel,
                    isPinnedViewRendering: isPinnedViewRendering,
                    alignment: frameAlignment,
                    usesParentPercentForWidth: usesParentPercentForWidth,
                    usesParentPercentForHeight: usesParentPercentForHeight,
                    width: finalWidth,
                    height: nil,
                    minWidth: finalMinWidth,
                    maxWidth: finalMaxWidth,
                    minHeight: nil,
                    maxHeight: nil
                ))
                .modifier(LayerSizeReader(viewModel: viewModel))
                .modifier(PreviewWindowCoordinateSpaceReader(
                    viewModel: viewModel,
                    isPinnedViewRendering: isPinnedViewRendering))
                        
        case .constrainWidth:
            // logInView("case .constrainWidth")
            content
            // apply `.aspectRatio` separately from `.frame(width:)` and `.frame(height:)`
                .modifier(PreviewAspectRatioModifier(data: aspectRatio))
                .modifier(LayerSizeModifier(
                    viewModel: viewModel,
                    isPinnedViewRendering: isPinnedViewRendering,
                    alignment: frameAlignment,
                    usesParentPercentForWidth: usesParentPercentForWidth,
                    usesParentPercentForHeight: usesParentPercentForHeight,
                    width: nil,
                    height: finalHeight,
                    minWidth: nil,
                    maxWidth: nil,
                    minHeight: finalMinHeight,
                    maxHeight: finalMaxHeight
                ))
                .modifier(LayerSizeReader(viewModel: viewModel))
                .modifier(PreviewWindowCoordinateSpaceReader(
                    viewModel: viewModel,
                    isPinnedViewRendering: isPinnedViewRendering))
        }
    }
}
