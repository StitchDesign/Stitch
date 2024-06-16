//
//  LayerGroupInteractableViewModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/22/24.
//

import SwiftUI

struct LayerGroupInteractableViewModifier: ViewModifier {
    let hasLayerInteraction: Bool
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        if hasLayerInteraction {
            content.contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
        }
    }
}
