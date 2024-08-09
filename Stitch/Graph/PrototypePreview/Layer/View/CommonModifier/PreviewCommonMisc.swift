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
    
    var pinReceiver: PinReceiverData? {
        getPinReceiverData(for: viewModel, from: graph)
    }
    
    static let defaultRotationAnchor = 0.5
    
    var rotationAnchorX: CGFloat {
        
        // If this is the PinnedViewA, then potentially return a non-default rotation anchor
        if viewModel.isPinned.getBool ?? false,
           isGeneratedAtTopLevel,
           let pinReceiver = pinReceiver {
            
            return getRotationAnchor(lengthA: viewModel.pinnedSize?.width ?? .zero,
                                     lengthB: pinReceiver.size.width,
                                     pointA: viewModel.pinnedCenter?.x ?? .zero,
                                     pointB: pinReceiver.center.x)
        }
        
        // Else, just return default rotation anchor of center
        else {
            return Self.defaultRotationAnchor
        }
    }
    
    var isPinned: Bool {
        viewModel.isPinned.getBool ?? false
    }
    
    var isPinnedView: Bool {
        isPinned && isGeneratedAtTopLevel
    }
    
    var isGhostView: Bool {
        isPinned && !isGeneratedAtTopLevel
    }
    
    // PinnedViewA uses rotation value of its pin-receiver View B
    var finalRotationX: CGFloat {
        if isPinnedView,
           let pinReceiver = pinReceiver {
            return pinReceiver.rotationX
        } else {
            return rotationX
        }
    }
    
    var finalRotationY: CGFloat {
        if isPinnedView,
           let pinReceiver = pinReceiver {
            return pinReceiver.rotationY
        } else {
            return rotationY
        }
    }
    
    var finalRotationZ: CGFloat {
        if isPinnedView,
           let pinReceiver = pinReceiver {
            return pinReceiver.rotationZ
        } else {
            return rotationZ
        }
    }
    
    var rotationAnchorY: CGFloat {
        
        // If this is the PinnedViewA, then potentially return a non-default rotation anchor
        if isPinnedView,
           let pinReceiver = pinReceiver {
            return getRotationAnchor(lengthA: viewModel.pinnedSize?.height ?? .zero,
                                     lengthB: pinReceiver.size.height,
                                     pointA: viewModel.pinnedCenter?.y ?? .zero,
                                     pointB: pinReceiver.center.y)
        }
        
        // Else, just return default rotation anchor of center
        else {
            return Self.defaultRotationAnchor
        }
    }
    
    func rotationModifier(degrees: CGFloat) -> LayerRotationModifier {
        LayerRotationModifier(degrees: degrees,
                              rotationX: finalRotationX,
                              rotationY: finalRotationY,
                              rotationZ: finalRotationZ,
                              rotationAnchorX: self.rotationAnchorX,
                              rotationAnchorY: self.rotationAnchorY,
                              isGhostView: isGhostView)
    }
    
    func body(content: Content) -> some View {

        content
        
        // x rotation
            .modifier(rotationModifier(degrees: finalRotationX))
        
        // y rotation
            .modifier(rotationModifier(degrees: finalRotationY))
        
        // z rotation
            .modifier(rotationModifier(degrees: finalRotationZ))
    }
}

struct LayerRotationModifier: ViewModifier {
    
    // Only want to "ignore the layout" when reading the size of a pinned view,
    // i.e. the ghost view
    
    let degrees: CGFloat
    
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    
    let rotationAnchorX: CGFloat
    let rotationAnchorY: CGFloat
    
    let isGhostView: Bool
    
    func body(content: Content) -> some View {
        if isGhostView {
            content
                .modifier(_Rotation3DEffect(angle: Angle(degrees: degrees),
                                            axis: (x: rotationX,
                                                   y: rotationY,
                                                   z: rotationZ),
                                            anchor: .init(x: rotationAnchorX,
                                                          y: rotationAnchorY))
                    // TODO: why does `.ignoredByLayout` negatively affect the Monthly Stays demo?
                    .ignoredByLayout())
        } else {
            content
                .modifier(_Rotation3DEffect(angle: Angle(degrees: degrees),
                                            axis: (x: rotationX,
                                                   y: rotationY,
                                                   z: rotationZ),
                                            anchor: .init(x: rotationAnchorX,
                                                          y: rotationAnchorY)))
        }
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

