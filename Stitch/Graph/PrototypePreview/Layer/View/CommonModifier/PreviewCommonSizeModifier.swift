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
    
    func body(content: Content) -> some View {
        if FeatureFlags.USE_LAYER_INSPECTOR {
            switch sizingScenario {
            case .auto:
                logInView("case .auto")
                content
                    .modifier(LayerSizeModifier(
                        alignment: frameAlignment,
                        usesParentPercentForWidth: usesParentPercentForWidth,
                        usesParentPercentForHeight: usesParentPercentForHeight,
                        width: width.asFrameDimension(parentSize.width),
                        height: height.asFrameDimension(parentSize.height),
                        minWidth: minWidth?.asFrameDimension(parentSize.width),
                        maxWidth: maxWidth?.asFrameDimension(parentSize.width),
                        minHeight: minHeight?.asFrameDimension(parentSize.height),
                        maxHeight: maxHeight?.asFrameDimension(parentSize.height)
                    ))
                    .modifier(LayerSizeReader(viewModel: viewModel))
                
            case .constrainHeight:
                logInView("case .constrainHeight")
                content
                // apply `.aspectRatio` separately from `.frame(width:)` and `.frame(height:)`
                    .modifier(PreviewAspectRatioModifier(data: aspectRatio))
                    .modifier(LayerSizeModifier(
                        alignment: frameAlignment,
                        usesParentPercentForWidth: usesParentPercentForWidth,
                        usesParentPercentForHeight: usesParentPercentForHeight,
                        width: width.asFrameDimension(parentSize.width),
                        height: nil,
                        minWidth: minWidth?.asFrameDimension(parentSize.width),
                        maxWidth: maxWidth?.asFrameDimension(parentSize.width),
                        minHeight: nil,
                        maxHeight: nil
                    ))
                    .modifier(LayerSizeReader(viewModel: viewModel))
                
            case .constrainWidth:
                logInView("case .constrainWidth")
                content
                // apply `.aspectRatio` separately from `.frame(width:)` and `.frame(height:)`
                    .modifier(PreviewAspectRatioModifier(data: aspectRatio))
                    .modifier(LayerSizeModifier(
                        alignment: frameAlignment,
                        usesParentPercentForWidth: usesParentPercentForWidth,
                        usesParentPercentForHeight: usesParentPercentForHeight,
                        width: nil,
                        height: height.asFrameDimension(parentSize.height),
                        minWidth: nil,
                        maxWidth: nil,
                        minHeight: minHeight?.asFrameDimension(parentSize.height),
                        maxHeight: maxHeight?.asFrameDimension(parentSize.height)
                    ))
                    .modifier(LayerSizeReader(viewModel: viewModel))
            }
        } else {
            content
                .frame(width: width.asFrameDimension(parentSize.width),
                       height: height.asFrameDimension(parentSize.height),
                       alignment: frameAlignment)
                .modifier(LayerSizeReader(viewModel: viewModel))
        }
    }
}
