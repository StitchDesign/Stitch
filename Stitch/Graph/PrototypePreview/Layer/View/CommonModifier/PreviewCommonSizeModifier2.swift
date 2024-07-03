//
//  PreviewCommonSizeModifier2.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/3/24.
//

import SwiftUI
import StitchSchemaKit

struct PreviewCommonSizeModifier2: ViewModifier {
    
    @Bindable var viewModel: LayerViewModel
    
    let aspectRatio: AspectRatioData?
    
    // If a dimension is constrained, then we use .unspecified for that dimension.
    let constraint: ConstrainedDimension?
    
    // Can actually be optional, if
    let width: LayerDimension?
    let minWidth: NumericalLayerDimension?
    let maxWidth: NumericalLayerDimension?
    
    let height: LayerDimension?
    let minHeight: NumericalLayerDimension?
    let maxHeight: NumericalLayerDimension?
    
    let parentSize: CGSize
    
    /*
     Only for:
     - Text and TextField layers, which have their own alignment (based on text-alignment and text-vertical-alignment);
     - Layer Groups, which alone their children
     
     Other layers should not use `.frame(alignment:)` since that interfaces with natural SwiftUI spacing of
     */
    let frameAlignment: Alignment?
    
    // How do you construct the LayerDimensionScenario for a length,
    // given constraint, static, min, max properties.
    var widthScenario: LayerDimensionScenario {
        .fromLayerDimension(width,
                            parentLength: parentSize.width,
                            constrained: constraint == .width,
                            minLength: minWidth,
                            maxLength: maxWidth)
    }
    
    var heightScenario: LayerDimensionScenario {
        .fromLayerDimension(height,
                            parentLength: parentSize.height,
                            constrained: constraint == .height,
                            minLength: minHeight,
                            maxLength: maxHeight)
    }
    
    func body(content: Content) -> some View {
        content
            .modifier(PreviewLayerDimensionModifier(dimension: .width,
                                                    scenario: widthScenario))
            .modifier(PreviewLayerDimensionModifier(dimension: .height,
                                                    scenario: heightScenario))
        
        // apply `.aspectRatio` separately from `.frame(width:)` and `.frame(height:)`
            .modifier(PreviewAspectRatioModifier(data: aspectRatio))
        
        // place the LayerSizeReader after the .aspectRatio modifier ?
            .modifier(LayerSizeReader(viewModel: viewModel))
    }
    
}
