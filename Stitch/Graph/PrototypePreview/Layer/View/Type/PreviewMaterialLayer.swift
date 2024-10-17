//
//  PreviewMaterialLayer.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/16/24.
//

import SwiftUI

extension UIBlurEffect.Style {
    init(_ thickness: MaterialThickness,
         _ deviceAppearance: DeviceAppearance) {
        
        switch deviceAppearance {
        case .system:
            switch thickness {
            case .ultraThin:
                self = .systemUltraThinMaterial
            case .thin:
                self = .systemThinMaterial
            case .regular:
                self = .systemMaterial
            case .thick:
                self = .systemThickMaterial
            case .chrome:
                self = .systemChromeMaterial
            } // switch thick
            
        case .dark:
            switch thickness {
            case .ultraThin:
                self = .systemUltraThinMaterialDark
            case .thin:
                self = .systemThinMaterialDark
            case .regular:
                self = .systemMaterialDark
            case .thick:
                self = .systemThickMaterialDark
            case .chrome:
                self = .systemChromeMaterialDark
            }
            
        case .light:
            switch thickness {
            case .ultraThin:
                self = .systemUltraThinMaterialLight
            case .thin:
                self = .systemThinMaterialLight
            case .regular:
                self = .systemMaterialLight
            case .thick:
                self = .systemThickMaterialLight
            case .chrome:
                self = .systemChromeMaterialLight
            }
            
        } // switch DeviceAppearance
    }
}


extension Material {
    init(_ thickness: MaterialThickness) {
        switch thickness {
        case .ultraThin:
            self = .ultraThin
        case .thin:
            self = .thin
        case .regular:
            self = .regular
        case .thick:
            self = .thick
        case .chrome:
            self = .bar
        } // switch thick
    } // switch DeviceAppearance
}

extension ColorScheme {
    init(_ deviceAppearance: DeviceAppearance) {
        switch deviceAppearance {
        case .light:
            self = .light
        case .dark:
            self = .dark
        case .system:
            // TODO: check real system setting?
            self = .light
        }
    }
}

struct PreviewMaterialLayer: View {
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    let viewModel: LayerViewModel
    let parentSize: CGSize
    let isPinnedViewRendering: Bool
    let parentDisablesPosition: Bool
         
    var materialThickness: MaterialThickness {
        viewModel.materialThickness.getMaterialThickness ?? .defaultMaterialThickness
    }
    
    var deviceAppearance: DeviceAppearance {
        viewModel.deviceAppearance.getDeviceAppearance ?? .defaultDeviceAppearance
    }
    
    var uiBlurStyle: UIBlurEffect.Style {
        .init(materialThickness, deviceAppearance)
    }
    
    var body: some View {
        
        Group {
            // UIKit material view does not play well with project thumbnail creation
            if document.isGeneratingProjectThumbnail {
                //                Color.clear
                Color.black.opacity(0.5) // pseudo-effect, just for project thumbnail
            } else {
                VisualEffectView(effect: UIBlurEffect(style: uiBlurStyle))
                
                // Force whole-view re-render when `UIBlurEffect.Style` changes;
                // avoids issue where `VisualEffectView`'s `UIVisualEffectView` updates inconsistently.
                // Perf-wise, this should be okay since material thickness and device appearance are values unlikely to rapidly change in a prototype?
                    .id(uiBlurStyle)
                
                //                // Alternative: native SwiftUI.Material effect, but not as transparent? Seems the same?:
                //                ZStack {
                //                    Color.clear
                //                }
                //                .background(Material(materialThickness))
                //                // Restricts the colorScheme change to just this material view
                //                .environment(\.colorScheme, ColorScheme(deviceAppearance))
                
            }
        }
        
        
        
            .opacity(viewModel.opacity.getNumber ?? defaultOpacityNumber)
            .modifier(PreviewCommonModifier(
                document: document,
                graph: graph,
                layerViewModel: viewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                interactiveLayer: viewModel.interactiveLayer,
                position: viewModel.position.getPosition ?? .zero,
                rotationX: viewModel.rotationX.asCGFloat,
                rotationY: viewModel.rotationY.asCGFloat,
                rotationZ: viewModel.rotationZ.asCGFloat,
                size: viewModel.size.getSize ?? .zero,
                scale: viewModel.scale.getNumber ?? .defaultScale,
                anchoring: .defaultAnchoring,
                blurRadius: viewModel.blurRadius.getNumber ?? .zero,
                blendMode: viewModel.blendMode.getBlendMode ?? .defaultBlendMode,
                brightness: viewModel.brightness.getNumber ?? .defaultBrightnessForLayerEffect,
                colorInvert:  viewModel.colorInvert.getBool ?? .defaultColorInvertForLayerEffect,
                contrast: viewModel.contrast.getNumber ?? .defaultContrastForLayerEffect,
                hueRotation: viewModel.hueRotation.getNumber ?? .defaultHueRotationForLayerEffect,
                saturation: viewModel.saturation.getNumber ?? .defaultSaturationForLayerEffect,
                pivot: .defaultPivot,
                shadowColor: .defaultShadowColor,
                shadowOpacity: .defaultShadowOpacity,
                shadowRadius: .defaultShadowRadius,
                shadowOffset: .defaultShadowOffset,
                parentSize: parentSize,
                parentDisablesPosition: parentDisablesPosition))
    }
}
