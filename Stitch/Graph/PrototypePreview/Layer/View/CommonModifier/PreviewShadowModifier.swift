//
//  PreviewShadowModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/23/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct PreviewShadowModifier: ViewModifier {
    
    let shadowColor: Color
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: StitchPosition
    
    func body(content: Content) -> some View {
        content
            .shadow(color: shadowColor.opacity(shadowOpacity),
                    radius: shadowRadius,
                    x: shadowOffset.x,
                    y: shadowOffset.y)
    }
}
