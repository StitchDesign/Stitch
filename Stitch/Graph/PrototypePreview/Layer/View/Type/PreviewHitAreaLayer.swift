//
//  PreviewHitAreaLayer.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/13/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct PreviewHitAreaLayer: View {
    
    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel
    let isGeneratedAtTopLevel: Bool
    let interactiveLayer: InteractiveLayer
    let position: StitchPosition
    let size: LayerSize
    let enabled: Bool
    let anchoring: Anchoring
    let setupMode: Bool
    
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    
    var color: Color {
        setupMode ? .red.opacity(0.5) : Color.white.opacity(0.0001)
    }
    
    var body: some View {
        
        if !enabled {
            EmptyView()
        } else {
            color.modifier(PreviewCommonModifier(
                graph: graph,
                layerViewModel: layerViewModel,
                isGeneratedAtTopLevel: isGeneratedAtTopLevel,
                interactiveLayer: interactiveLayer,
                position: position,
                rotationX: .zero,
                rotationY: .zero,
                rotationZ: .zero,
//                size: size.asCGSize(parentSize),
                size: size,
                scale: 1,
                anchoring: anchoring,
                
                // blur, blend, etc.: Not applicable
                blurRadius: .zero,
                blendMode: .normal,
                
                // use defaults for filter-effects
                brightness: .defaultBrightnessForLayerEffect,
                colorInvert: .defaultColorInvertForLayerEffect,
                contrast: .defaultContrastForLayerEffect,
                hueRotation: .defaultHueRotationForLayerEffect,
                saturation: .defaultSaturationForLayerEffect,
                pivot: .defaultPivot,
                shadowColor: .defaultShadowColor,
                shadowOpacity: .defaultShadowOpacity,
                shadowRadius: .defaultShadowRadius,
                shadowOffset: .defaultShadowOffset,
                parentSize: parentSize,
                parentDisablesPosition: parentDisablesPosition))
        }
    }
}
