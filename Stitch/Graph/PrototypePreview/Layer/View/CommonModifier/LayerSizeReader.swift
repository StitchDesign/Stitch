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
    
    var isGhostLayer: Bool {
        !isPinnedViewRendering
    }
    
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                let frameData = proxy.frame(in: .named(PreviewContent.prototypeCoordinateSpace))
                
                Color.clear
                    .onChange(of: frameData.size, initial: true) { _, newSize in
                        // log("LayerSizeReader: \(viewModel.layer), new size: \(newSize)")
                        if viewModel.readSize != newSize {
                            viewModel.readSize = newSize
                        }
                    }
                    .onChange(of: frameData.origin, initial: true) { _, newPosition in
                        // log("LayerSizeReader: \(viewModel.layer), new pos: \(newPosition)")
                        if isGhostLayer,
                           viewModel.readPosition != newPosition {
                            viewModel.readPosition = newPosition
                        }
                    }
            }
        }
    }
}
