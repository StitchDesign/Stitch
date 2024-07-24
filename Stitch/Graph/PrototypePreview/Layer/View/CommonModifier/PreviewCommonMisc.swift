//
//  PreviewCommonMisc.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// To avoid a bug where GeometryReader treats a rotated view as increased in size,
// we use _Rotation3DEffect.ignoredByLayout instead of .rotation3DEffect:
// Discussion here: https://harshil.net/blog/swiftui-rotationeffect-is-kinda-funky
struct PreviewLayerRotationModifier: ViewModifier {
    
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    
    func body(content: Content) -> some View {
        
        content
        
        // x rotation
            .modifier(_Rotation3DEffect(angle: Angle(degrees: rotationX),
                                        axis: (x: rotationX, y: rotationY, z: rotationZ),
                                        anchor: .center)
                .ignoredByLayout())
        
        // y rotation
            .modifier(_Rotation3DEffect(angle: Angle(degrees: rotationY),
                                        axis: (x: rotationX, y: rotationY, z: rotationZ),
                                        anchor: .center)
                .ignoredByLayout())
        
        // z rotation
            .modifier(_Rotation3DEffect(angle: Angle(degrees: rotationZ),
                                        axis: (x: rotationX, y: rotationY, z: rotationZ),
                                        anchor: .center)
                .ignoredByLayout())
    }
}

struct PreviewLayerEffectsModifier: ViewModifier {
    
    let blurRadius: CGFloat
    let blendMode: StitchBlendMode
    let brightness: Double
    let colorInvert: Bool
    let contrast: Double
    let hueRotation: Double
    let saturation: Double
    
    func body(content: Content) -> some View {
        content
        // order of .blur, .blendMode vs other modiifers doesn't matter?
        .blur(radius: blurRadius)
        .blendMode(blendMode.toBlendMode)
    
        // "filter effect" modifiers must come *after* blend-mode
        .brightness(brightness)
        .contrast(contrast)
        .hueRotation(Angle(degrees: hueRotation))
        .modifier(ColorInvertModifier(colorInvert: colorInvert))
        .saturation(saturation)
    }
}
