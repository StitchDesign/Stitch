//
//  ImageNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/22/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct VisualMediaLayerView: View {
    // State for media needed if we need to async load an import
    @State private var mediaObject: StitchMediaObject?
    
    @Bindable var graph: GraphState
    @Bindable var viewModel: LayerViewModel
    
    let isPinnedViewRendering: Bool
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    
    var mediaValue: AsyncMediaValue? {
        self.mediaPortValue._asyncMedia
    }
    
    var layerInputType: LayerInputPort {
        switch viewModel.layer {
        case .image:
            return .image
        case .video:
            return .video
        default:
            fatalErrorIfDebug()
            return .image
        }
    }
    
    @MainActor var mediaRowObserver: InputNodeRowObserver? {
        guard let layerNode = graph.getNodeViewModel(viewModel.id.layerNodeId.asNodeId)?.layerNode else {
            return nil
        }
        
        switch layerNode.layer {
        case .image:
            return layerNode.imagePort._packedData.rowObserver
        case .video:
            return layerNode.videoPort._packedData.rowObserver
        default:
            fatalErrorIfDebug()
            return nil
        }
    }
    
    var mediaPortValue: PortValue {
        get {
            switch viewModel.layer {
            case .video:
                return viewModel.video
            case .image:
                return viewModel.image
            default:
                fatalErrorIfDebug()
                return viewModel.image
            }
        }
        
        set(newValue) {
            switch viewModel.layer {
            case .video:
                viewModel.video = newValue
            case .image:
                viewModel.image = newValue
            default:
                fatalErrorIfDebug()
            }
        }
    }

    var body: some View {
        Group {
            switch mediaObject {
            case .image(let image):
                ImageLayerView(graph: graph,
                               viewModel: viewModel,
                               image: image, 
                               isPinnedViewRendering: isPinnedViewRendering,
                               parentSize: parentSize,
                               parentDisablesPosition: parentDisablesPosition)
            case .video(let video):
                VideoLayerView(graph: graph,
                               viewModel: viewModel,
                               video: video,
                               isPinnedViewRendering: isPinnedViewRendering,
                               parentSize: parentSize,
                               parentDisablesPosition: parentDisablesPosition)
            default:
                // MARK: can't be EmptyView for the onChange below doesn't get called!
                Color.clear
            }
        }
        .modifier(MediaLayerViewModifier(mediaValue: mediaValue,
                                         mediaObject: $mediaObject,
                                         graph: graph,
                                         mediaRowObserver: mediaRowObserver))
    }
}

struct ImageLayerView: View {
    @Bindable var graph: GraphState
    @Bindable var viewModel: LayerViewModel
    let image: UIImage
    
    let isPinnedViewRendering: Bool
    let parentSize: CGSize
    let parentDisablesPosition: Bool

    var body: some View {
        PreviewImageLayer(
            graph: graph,
            layerViewModel: viewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            image: image,
            position: viewModel.position.getPosition ?? .zero,
            rotationX: viewModel.rotationX.asCGFloat,
            rotationY: viewModel.rotationY.asCGFloat,
            rotationZ: viewModel.rotationZ.asCGFloat,
            size: viewModel.size.getSize ?? DEFAULT_PREVIEW_IMAGE_SIZE,
            opacity: viewModel.opacity.getNumber ?? defaultOpacityNumber,
            fitStyle: viewModel.fitStyle.getFitStyle ?? defaultMediaFitStyle,
            scale: viewModel.scale.getNumber ?? defaultScaleNumber,
            anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
            blurRadius: viewModel.blurRadius.getNumber ?? .zero,
            blendMode: viewModel.blendMode.getBlendMode ?? .defaultBlendMode,
            brightness: viewModel.brightness.getNumber ?? .defaultBrightnessForLayerEffect,
            colorInvert: viewModel.colorInvert.getBool ?? .defaultColorInvertForLayerEffect,
            contrast: viewModel.contrast.getNumber ?? .defaultContrastForLayerEffect,
            hueRotation: viewModel.hueRotation.getNumber ?? .defaultHueRotationForLayerEffect,
            saturation: viewModel.saturation.getNumber ?? .defaultSaturationForLayerEffect,
            pivot: viewModel.pivot.getAnchoring ?? .defaultPivot,
            shadowColor: viewModel.shadowColor.getColor ?? .defaultShadowColor,
            shadowOpacity: viewModel.shadowOpacity.getNumber ?? .defaultShadowOpacity,
            shadowRadius: viewModel.shadowRadius.getNumber ?? .defaultShadowOpacity,
            shadowOffset: viewModel.shadowOffset.getPosition ?? .defaultShadowOffset,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            isClipped: viewModel.isClipped.getBool ?? false)
    }
}

struct VideoLayerView: View {
    @Bindable var graph: GraphState
    @Bindable var viewModel: LayerViewModel
    @State var video: StitchVideoImportPlayer
    
    let isPinnedViewRendering: Bool
    let parentSize: CGSize
    let parentDisablesPosition: Bool

    var body: some View {
        PreviewVideoLayer(
            graph: graph,
            layerViewModel: viewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            videoPlayer: video,
            position: viewModel.position.getPosition ?? .zero,
            rotationX: viewModel.rotationX.asCGFloat,
            rotationY: viewModel.rotationY.asCGFloat,
            rotationZ: viewModel.rotationZ.asCGFloat,
            size: viewModel.size.getSize ?? DEFAULT_PREVIEW_IMAGE_SIZE,
            opacity: viewModel.opacity.getNumber ?? 0.8,
            videoFitStyle: viewModel.fitStyle.getFitStyle ?? defaultMediaFitStyle,
            scale: viewModel.scale.getNumber ?? defaultScaleNumber,
            anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
            blurRadius: viewModel.blurRadius.getNumber ?? .zero,
            blendMode: viewModel.blendMode.getBlendMode ?? .defaultBlendMode,
            brightness: viewModel.brightness.getNumber ?? .defaultBrightnessForLayerEffect,
            colorInvert: viewModel.colorInvert.getBool ?? .defaultColorInvertForLayerEffect,
            contrast: viewModel.contrast.getNumber ?? .defaultContrastForLayerEffect,
            hueRotation: viewModel.hueRotation.getNumber ?? .defaultHueRotationForLayerEffect,
            saturation: viewModel.saturation.getNumber ?? .defaultSaturationForLayerEffect,
            pivot: viewModel.pivot.getAnchoring ?? .defaultPivot,
            shadowColor: viewModel.shadowColor.getColor ?? .defaultShadowColor,
            shadowOpacity: viewModel.shadowOpacity.getNumber ?? .defaultShadowOpacity,
            shadowRadius: viewModel.shadowRadius.getNumber ?? .defaultShadowOpacity,
            shadowOffset: viewModel.shadowOffset.getPosition ?? .defaultShadowOffset,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            isClipped: viewModel.isClipped.getBool ?? false)
    }
}
