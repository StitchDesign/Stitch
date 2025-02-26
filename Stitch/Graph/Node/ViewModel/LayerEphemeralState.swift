//
//  LayerEphemeralState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/26/25.
//

import Foundation
import SwiftUI

@Observable
final class LayerEphemeralState {
    
    // Canvas Sketch properties
    @MainActor
    var lines: DrawingViewLines = .init()
    
    @MainActor
    var parentSizeFromDrag: CGSize = .zero
    
    // Text Field property
    @MainActor 
    var textFieldInput: String = ""
    
    // Switch Toggle property
    @MainActor
    var isUIToggled: Bool = false
    
    @MainActor
    init(lines: DrawingViewLines = .init(),
         parentSizeFromDrag: CGSize = .zero,
         textFieldInput: String = .empty,
         isUIToggled: Bool = false) {
        self.lines = lines
        self.parentSizeFromDrag = parentSizeFromDrag
        self.textFieldInput = textFieldInput
        self.isUIToggled = isUIToggled
    }
}
