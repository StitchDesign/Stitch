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
                    .onChange(of: frameData, initial: !isPinnedViewRendering) { _, newFrameData in
                        // log("LayerSizeReader: \(viewModel.layer), newFrameData: \(newFrameData)")
                        let newSize = newFrameData.size.handleNaN()
                        if viewModel.readSize != newSize {
                            viewModel.readFrame.size = newSize
                        }
                        
                        // TODO: handle NaN ?
                        let newOrigin = newFrameData.origin
                        if viewModel.readFrame.origin != newOrigin {
                            viewModel.readFrame.origin = newOrigin
                        }
                    }
            }
        }
    }
}

// Apparently GeometryReader's frame.size height and width can be NaN in certain circumstances;
// e.g. when reading the size of a LayerGroup created around a child whose scale = 0
extension CGSize {
    func handleNaN() -> Self {
        var size = self
        if size.width.isNaN {
            size.width = .zero
        }
        if size.height.isNaN {
            size.height = .zero
        }
        return size
    }
}
