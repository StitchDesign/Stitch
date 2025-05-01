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
    let isPinnedViewRendering: Bool
    
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    
    @MainActor var pinReceiver: PinReceiverData? {
        graph.getPinReceiverData(for: viewModel)
    }
    
    static let defaultRotationAnchor = 0.5
    
    @MainActor var rotationAnchorX: CGFloat {
        
        // If this is the PinnedViewA, then potentially return a non-default rotation anchor
        if viewModel.isPinned.getBool ?? false,
           isPinnedViewRendering,
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
        isPinned && isPinnedViewRendering
    }
    
    @MainActor
    var receivesPin: Bool {
        graph.pinMap.get(viewModel.previewCoordinate.layerNodeId).isDefined
    }
    
    @MainActor
    var shouldBeIgnoredByLayoutBecauseOfPinning: Bool {
        isPinned || receivesPin
    }
    
    // PinnedViewA uses rotation value of its pin-receiver View B
    @MainActor
    var finalRotationX: CGFloat {
        if isPinnedView,
           let pinReceiver = pinReceiver {
            return pinReceiver.rotationX
        } else {
            return rotationX
        }
    }
    
    @MainActor
    var finalRotationY: CGFloat {
        if isPinnedView,
           let pinReceiver = pinReceiver {
            return pinReceiver.rotationY
        } else {
            return rotationY
        }
    }
    
    @MainActor
    var finalRotationZ: CGFloat {
        if isPinnedView,
           let pinReceiver = pinReceiver {
            return pinReceiver.rotationZ
        } else {
            return rotationZ
        }
    }
    
    @MainActor
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
    
    @MainActor
    func rotationModifier(degrees: CGFloat,
                          isForXAxis: Bool = false,
                          isForYAxis: Bool = false,
                          isForZAxis: Bool = false) -> LayerRotationModifier {
        LayerRotationModifier(
            degrees: degrees,
            isForXAxis: isForXAxis,
            isForYAxis: isForYAxis,
            isForZAxis: isForZAxis,
            rotationAnchorX: self.rotationAnchorX,
            rotationAnchorY: self.rotationAnchorY,
            
            /*
             Note: Rotations for pinning are ALWAYS ignored by layout.
             
             Rotations in SwiftUI undesirably change the non-.local size of a layer, thus messing up a layer's `readSize`.
             Details: https://harshil.net/blog/swiftui-rotationeffect-is-kinda-funky
             
             To avoid this, we can have the rotation "ignored by layout".
             However, rotations ignored by layout move the layer but not e.g. its hit areas.
             
             Since z-rotations are commonly used with circular-style interactions,
             we respect (i.e. do NOT ignore) layout for z-rotations.
             */
            shouldBeIgnoredByLayout: shouldBeIgnoredByLayoutBecauseOfPinning || !isForZAxis)
    }
    
    func body(content: Content) -> some View {

        content
        
        // x rotation
            .modifier(rotationModifier(degrees: finalRotationX,
                                       isForXAxis: true))
        
        // y rotation
            .modifier(rotationModifier(degrees: finalRotationY,
                                       isForYAxis: true))
        
        // z rotation
            .modifier(rotationModifier(degrees: finalRotationZ,
                                       isForZAxis: true))
    }
}

struct LayerRotationModifier: ViewModifier {
    
    // Only want to "ignore the layout" when reading the size of a pinned view,
    // i.e. the ghost view
    
    let degrees: CGFloat
    
    var isForXAxis: Bool = false
    var isForYAxis: Bool = false
    var isForZAxis: Bool = false
    
    let rotationAnchorX: CGFloat
    let rotationAnchorY: CGFloat
    
    let shouldBeIgnoredByLayout: Bool
    
    func body(content: Content) -> some View {
        if shouldBeIgnoredByLayout {
            content
                .modifier(_Rotation3DEffect(angle: Angle(degrees: degrees),
                                            axis: (x: isForXAxis ? 1 : 0,
                                                   y: isForYAxis ? 1 : 0,
                                                   z: isForZAxis ? 1 : 0),
                                            anchor: .init(x: rotationAnchorX,
                                                          y: rotationAnchorY))
                    // TODO: why does `.ignoredByLayout` negatively affect the Monthly Stays demo?
                    .ignoredByLayout())
        } else {
            content
                .modifier(_Rotation3DEffect(angle: Angle(degrees: degrees),
                                            axis: (x: isForXAxis ? 1 : 0,
                                                   y: isForYAxis ? 1 : 0,
                                                   z: isForZAxis ? 1 : 0),
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
