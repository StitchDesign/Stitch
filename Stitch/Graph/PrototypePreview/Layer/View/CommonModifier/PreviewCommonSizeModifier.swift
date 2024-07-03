//
//  PreviewCommonSizeModifier2.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/3/24.
//

import SwiftUI
import StitchSchemaKit

extension LayerDimension {
    func asFrameDimension(_ parentLength: CGFloat,
                          constrained: Bool = false) -> CGFloat? {

           if constrained {
               return nil // i.e. unspecified, just like .fill, .hug, .auto
           }
           
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
    
    // TODO: actually pass these properties down
    var aspectRatio: AspectRatioData? = nil
    
    // If a dimension is constrained, then we use .unspecified for that dimension.
    var constraint: LengthDimension? = nil
    
    // TODO: remove once properties are actually passed down
    var size: LayerSize
    
        // Can actually be optional, if
    var width: LayerDimension? {
        size.width
    }
    
    // TODO: actually pass these properties down
    var minWidth: NumericalLayerDimension? = nil
    var maxWidth: NumericalLayerDimension? = nil
    
    var height: LayerDimension? {
        size.height
    }
    
    var minHeight: NumericalLayerDimension? = nil
    var maxHeight: NumericalLayerDimension? = nil
    
    let parentSize: CGSize
    
    /*
     Only for:
     - Text and TextField layers, which have their own alignment (based on text-alignment and text-vertical-alignment);
     - Layer Groups, which alone their children
     
     Other layers should not use `.frame(alignment:)` since that interfaces with natural SwiftUI spacing of
     */
    
    // `.frame(alignment:)` only matters if there is a size gap between the layer and its frame; can happen for Text, TextField, ProgressIndicator and other native views which do not resize just by .frame
    let frameAlignment: Alignment

    func body(content: Content) -> some View {
        content

            .modifier(LayerSizeModifier(
                
                alignment: frameAlignment,
                
                width: width?.asFrameDimension(parentSize.width,
                                               constrained: constraint == .width),
                
                height: height?.asFrameDimension(parentSize.height,
                                                 constrained: constraint == .height),
                
                minWidth: minWidth?.asFrameDimension(parentSize.width),
                maxWidth: maxWidth?.asFrameDimension(parentSize.width),
                
                minHeight: minHeight?.asFrameDimension(parentSize.height),
                maxHeight: maxHeight?.asFrameDimension(parentSize.height)
            ))
        
        // apply `.aspectRatio` separately from `.frame(width:)` and `.frame(height:)`
            .modifier(PreviewAspectRatioModifier(data: aspectRatio))
        
        // place the LayerSizeReader after the .aspectRatio modifier ?
            .modifier(LayerSizeReader(viewModel: viewModel))
    }
    
}
