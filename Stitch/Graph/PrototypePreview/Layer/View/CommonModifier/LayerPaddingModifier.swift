//
//  LayerPaddingModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/23/24.
//

import SwiftUI

struct LayerPaddingModifier: ViewModifier {
    
    // Could be for `padding` layer input (i.e. pre-.frame)
    // or `margin` layer input (i.e. post-.frame).
    let padding: StitchPadding
    
    func body(content: Content) -> some View {
        content
            .padding(.init(top: padding.top,
                           leading: padding.left,
                           bottom: padding.bottom,
                           trailing: padding.right))
    }
}
