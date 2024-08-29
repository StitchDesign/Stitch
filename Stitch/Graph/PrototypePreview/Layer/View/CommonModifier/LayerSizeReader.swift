//
//  LayerSizeReader.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/21/24.
//

import SwiftUI

struct LayerSizeReader: ViewModifier {
    @Bindable var viewModel: LayerViewModel
    
    // Represents the origin view of a pinned layer, needed to relay positional data
    // for calculating the offset of its pinned layer equivalent
    let isPinnedViewRendering: Bool
    
    /// Important to only report data from ghost view
    
    func getFrame(geometry: GeometryProxy) -> CGRect {
        !isPinnedViewRendering ? geometry.frame(in: .named(PreviewContent.prototypeCoordinateSpace)) : .zero
    }
    
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                let frameData = self.getFrame(geometry: proxy)
                
                Color.clear
                    .onChange(of: frameData.size, initial: !isPinnedViewRendering) { _, newSize in
                        // log("LayerSizeReader: \(viewModel.layer), new size: \(newSize)")
                        if viewModel.readSize != newSize {
                            viewModel.readSize = newSize
                        }
                    }
                    .onChange(of: frameData.mid, initial: !isPinnedViewRendering) { _, newPosition in
                        // log("LayerSizeReader: \(viewModel.layer), new pos: \(newPosition)")
                        if viewModel.readMidPosition != newPosition {
                            viewModel.readMidPosition = newPosition
                        }
                    }
            }
        }
    }
}
