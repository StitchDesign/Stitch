//
//  LayerSizeReader.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/21/24.
//

import SwiftUI

struct LayerSizeReader: ViewModifier {
    @Bindable var viewModel: LayerViewModel
    
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.frame(in: .local).size, initial: true) { _, newSize in
                        // log("LayerSizeReader: \(viewModel.layer), new size: \(newSize)")
                        if viewModel.readSize != newSize {
                            viewModel.readSize = newSize
                        }
                    }
            }
        }
    }
}
