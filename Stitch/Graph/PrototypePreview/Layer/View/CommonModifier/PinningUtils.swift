//
//  PinningUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/23/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI


let PREVIEW_WINDOW_COORDINATE_SPACE = "previewWindow"

struct PreviewWindowCoordinateSpaceReader: ViewModifier {
    
    @Bindable var viewModel: LayerViewModel

//    var isGeneratedAtTopLevel: Bool
    let isGeneratedAtTopLevel: Bool
    
    var isPinned: Bool {
        viewModel.isPinned
    }
    
    // ALSO: if this is View A and it is not being generated at the top level,
    // then we should hide the view
    var isGhostView: Bool {
        isPinned && !isGeneratedAtTopLevel
    }
    
    var key: PreviewCoordinate {
        viewModel.id
    }
    
    func body(content: Content) -> some View {
        content
            .opacity(isGhostView ? 0.1 : 1) // added
            .background {
                GeometryReader { geometry in
                    Color.clear.onChange(of: geometry.frame(in: .named(PREVIEW_WINDOW_COORDINATE_SPACE)),
                                         initial: true) { oldValue, newValue in
                        
                        log("PreviewWindowCoordinateSpaceReader: viewModel.layer: \(viewModel.layer)")
                        
                        log("PreviewWindowCoordinateSpaceReader: key: \(key), size: \(newValue.size), origin: \(newValue.origin), mid: \(newValue.mid)")
                        
                        //viewModel.previewWindowRect = newValue
                        
                        if isPinned {
                            // If this view is for a pinned layer view model,
                            // and is generated at top level,
                            // then we only update the "pinned center" (for rotation)
                            if isGeneratedAtTopLevel {
                                log("PreviewWindowCoordinateSpaceReader: pinned and at top level")
                                viewModel.pinnedCenter = newValue.mid
                            }
                            
                            // Else, if we're not at the top level,
                            // then we read the "pinned size"
                            else {
                                log("PreviewWindowCoordinateSpaceReader: pinned but not at top level")
                                viewModel.pinnedSize = newValue.size
                            }
                        }
                        
                        // If we're not a view for a pinned layer view model,
                        // we could be a view for a pin-receiving layer view model, or not be related to pinning at all.
                        // In either case, we always read the pin-receiveing relevant data.
                        else {
                            log("PreviewWindowCoordinateSpaceReader: either pin-receiving or not at all pin-related")
                            viewModel.pinReceiverSize = newValue.size
                            viewModel.pinReceiverOrigin = newValue.origin
                            viewModel.pinReceiverCenter = newValue.mid
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

// TODO: there must be a more elegant formula here
func getRotationAnchor(lengthA: CGFloat,
                       lengthB: CGFloat,
                       pointA: CGFloat,
                       pointB: CGFloat) -> CGFloat {
    
    // ASSUMES View B's rotation anchor is center i.e. `(0.5, 0.5)`
    let defaultAnchor = 0.5
    
    guard lengthA != lengthB else {
        // Default to center
        print("getRotationAnchor: length: defaultAnchor")
        return defaultAnchor
    }
    
    guard pointA != pointB else {
        // Default to center
        print("getRotationAnchor: point: defaultAnchor")
        return defaultAnchor
    }
    
    // e.g. if View B = 200 and View A = 800,
    // (i.e. pinned View A is larger than the View B which it is pinned to.)
    // then anchor diff (0.5)(1/4) i.e. 1/8 = 0.125
    let anchorDiff = defaultAnchor * (lengthB / lengthA)
    
    let aLarger = lengthA > lengthB
    let aBelowOrRight = pointA > pointB
    
    if aLarger {
        return aBelowOrRight ? anchorDiff : (1 - anchorDiff)
    } else {
        return aBelowOrRight ? (1 - anchorDiff) : anchorDiff
    }
}
