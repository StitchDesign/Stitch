//
//  PreviewCommonSizeModifier.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct PreviewCommonSizeModifier: ViewModifier {
    
    @Bindable var viewModel: LayerViewModel
    
    let size: LayerSize
    
    // Assumes parentSize has already been scaled etc.
    let parentSize: CGSize
    
    /*
     Only for:
     - Text and TextField layers, which have their own alignment (based on text-alignment and text-vertical-alignment);
     - Layer Groups, which alone their children
     
     Other layers should not use `.frame(alignment:)` since that interfaces with natural SwiftUI spacing of
     */
    // actually you can use alignment all the time, it just needs to be .topLeft ?
    let frameAlignment: Alignment?
    
    // true just if: this layer group uses
    var useParentSizeForAnchoring: Bool = false
    
    var width: CGFloat? {
        size.width
            .asFrameDimension(parentSize.width)
            .map {
                max($0, 0)
            }
    }
    
    var height: CGFloat? {
        size.height
            .asFrameDimension(parentSize.height)
            .map {
                max($0, 0)
            }
    }
    
    func body(content: Content) -> some View {
        if let frameAlignment = frameAlignment {
            content
                .frame(width: width,
                       height: height,
                       alignment: frameAlignment)
                .modifier(LayerSizeReader(viewModel: viewModel))
        } else {
            content
            // Note: e.g. `width: nil` is equivalent to not providing width at all, thus allowing SwiftUI to decide view's width.
                .frame(width: width, height: height)
                .modifier(LayerSizeReader(viewModel: viewModel))
        }
    }
}
