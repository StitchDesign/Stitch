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
    
    @Bindable var graph: GraphState
    @Bindable var viewModel: LayerViewModel
    let isGeneratedAtTopLevel: Bool
    
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
        
    var pinReceiver: LayerViewModel? {
        getPinReceiverLayerViewModel(for: viewModel, from: graph)
    }
    
    static let defaultRotationAnchor = 0.5
    
    var rotationAnchorX: CGFloat {
        
        // If this is the PinnedViewA, then potentially return a non-default rotation anchor
        if viewModel.isPinned,
           isGeneratedAtTopLevel,
           let pinReceiver = pinReceiver {
            
            return getRotationAnchor(lengthA: viewModel.pinnedSize?.width ?? .zero,
                                     lengthB: pinReceiver.pinReceiverSize?.width ?? .zero,
                                     pointA: viewModel.pinnedCenter?.x ?? .zero,
                                     pointB: pinReceiver.pinReceiverCenter?.x ?? .zero)
        }
        
        // Else, just return default rotation anchor of center
        else {
            return Self.defaultRotationAnchor
        }
    }
    
    var isPinnedView: Bool {
        viewModel.isPinned && isGeneratedAtTopLevel
    }
    
    // PinnedViewA uses rotation value of its pin-receiver View B
    var finalRotationX: CGFloat {
        if isPinnedView,
           let pinReceiver = pinReceiver {
            return pinReceiver.rotationX.getNumber ?? .zero
        } else {
            return rotationX
        }
    }
    
    var finalRotationY: CGFloat {
        if isPinnedView,
           let pinReceiver = pinReceiver {
            return pinReceiver.rotationY.getNumber ?? .zero
        } else {
            return rotationY
        }
    }
    
    var finalRotationZ: CGFloat {
        if isPinnedView,
           let pinReceiver = pinReceiver {
            return pinReceiver.rotationZ.getNumber ?? .zero
        } else {
            return rotationZ
        }
    }
    
    var rotationAnchorY: CGFloat {
        
        // If this is the PinnedViewA, then potentially return a non-default rotation anchor
        if isPinnedView,
           let pinReceiver = pinReceiver {
            
            return getRotationAnchor(lengthA: viewModel.pinnedSize?.height ?? .zero,
                                     lengthB: pinReceiver.pinReceiverSize?.height ?? .zero,
                                     pointA: viewModel.pinnedCenter?.y ?? .zero,
                                     pointB: pinReceiver.pinReceiverCenter?.y ?? .zero)
        }
        
        // Else, just return default rotation anchor of center
        else {
            return Self.defaultRotationAnchor
        }
    }
    
    func body(content: Content) -> some View {
        
        content
        
        // x rotation
            .modifier(_Rotation3DEffect(angle: Angle(degrees: finalRotationX),
                                        axis: (x: finalRotationX, 
                                               y: finalRotationY,
                                               z: finalRotationZ),
                                        anchor: .init(x: self.rotationAnchorX,
                                                      y: self.rotationAnchorY))
                .ignoredByLayout())
        
        // y rotation
            .modifier(_Rotation3DEffect(angle: Angle(degrees: finalRotationY),
                                        axis: (x: finalRotationX, 
                                               y: finalRotationY, 
                                               z: finalRotationZ),
                                        anchor: .init(x: self.rotationAnchorX,
                                                      y: self.rotationAnchorY))
                .ignoredByLayout())
        
        // z rotation
            .modifier(_Rotation3DEffect(angle: Angle(degrees: finalRotationZ),
                                        axis: (x: finalRotationX, 
                                               y: finalRotationY, 
                                               z: finalRotationZ),
                                        anchor: .init(x: self.rotationAnchorX,
                                                      y: self.rotationAnchorY))
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
