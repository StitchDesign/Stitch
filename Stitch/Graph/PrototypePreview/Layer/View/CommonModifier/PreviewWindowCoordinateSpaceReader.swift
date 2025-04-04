//
//  PreviewWindowCoordinateSpaceReader.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/28/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

struct PreviewWindowCoordinateSpaceReader: ViewModifier {
    
    @Bindable var viewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    
    let pinMap: RootPinMap
    
    var isPinned: Bool {
        viewModel.isPinned.getBool ?? false
    }
    
    var key: PreviewCoordinate {
        viewModel.id
    }
    
    /// Important to only report pin data from ghost view.
    func getFrame(geometry: GeometryProxy) -> CGRect {
        if isPinnedViewRendering {
            return .zero
        } else {
            return geometry.frame(in: .named(PreviewContent.prototypeCoordinateSpace))
        }
    }
    
    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geometry in
                    // Note: this is the size of the view within the whole preview window coordinate space;
                    // compare vs. LayerSizeReader which is the size of the view within the .local coordinate space.
                    Color.clear.onChange(of: self.getFrame(geometry: geometry),
                                         initial: !isPinnedViewRendering) { oldValue, newValue in
   
                        //viewModel.previewWindowRect = newValue
                        
                        // If this layer *receives* a pin, populate its pin-receiver data fields:
                        if pinMap.get(viewModel.id.layerNodeId).isDefined,
                           // TODO: how or why can newValue
                           (!newValue.width.isNaN && !newValue.height.isNaN) {
                            // log("PreviewWindowCoordinateSpaceReader: had pinMap entry for viewModel.id.layerNodeId \(viewModel.id.layerNodeId), newValue.origin: \(newValue.origin)")
                                viewModel.pinReceiverSize = newValue.size
                                viewModel.pinReceiverOrigin = newValue.origin
                                viewModel.pinReceiverCenter = newValue.mid
                            }
                        
                        if isPinned {
                            // If this view is for a pinned layer view model,
                            // and is generated at top level,
                            // then we only update the "pinned center" (for rotation)
                            if isPinnedViewRendering {
                                // log("PreviewWindowCoordinateSpaceReader: pinned and at top level")
                                viewModel.pinnedCenter = newValue.mid
                            }
                            
                            // Else, if we're not at the top level,
                            // then we read the "pinned size"
                            else {
                                if newValue.width.isNaN || newValue.height.isNaN {
                                    return
                                }
                                
                                viewModel.pinnedSize = newValue.size
                            }
                        }
                    } // .onChange
                } // GeometryReader
            } // content.background
    }
}

extension CGRect {
    var mid: CGPoint {
        .init(x: self.midX, y: self.midY)
    }
}
