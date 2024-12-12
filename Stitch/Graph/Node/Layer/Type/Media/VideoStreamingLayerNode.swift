//
//  VideoStreamingLayerNode.swift
//  Stitch
//
//  Created by Nicholas Arner on 4/24/24.
//

import AVFoundation
import Foundation
import SwiftUI
import StitchSchemaKit

let DEFAULT_PREVIEW_STREAMING_VIDEO_SIZE = CGSize(width: 300, height: 300).toLayerSize
let DEFAULT_VIDEO_VOLUME = Double(0.5)

extension LayerSize {
    static let DEFAULT_VIDEO_STREAMING_SIZE: Self = .init(width: 300, height: 400)
}

struct VideoStreamingLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.videoStreaming
    
    static let inputDefinitions: LayerInputPortSet = .init([
        .enabled,
        .videoURL,
        .volume,
        .position,
        .rotationX,
        .rotationY,
        .rotationZ,
        .size,
        .opacity,
        .scale,
        .anchoring,
        .zIndex
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.aspectRatio)
        .union(.sizing).union(.pinning).union(.layerPaddingAndMargin).union(.offsetInGroup)
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, 
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool) -> some View {
        PreviewVideoStreamLayer(
            document: document,
            graph: graph,
            layerViewModel: viewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            enabled: viewModel.enabled.getBool ?? true,
            currentVideoURLString: Binding<String>(
                get: { viewModel.videoURL.getString?.string ?? "" },
                set: { viewModel.videoURL = .string(.init($0)) }
            ),
            volume: viewModel.volume.getNumber ?? DEFAULT_VIDEO_VOLUME,
            position: viewModel.position.getPosition ?? .zero,
            rotationX: viewModel.rotationX.asCGFloat,
            rotationY: viewModel.rotationY.asCGFloat,
            rotationZ: viewModel.rotationZ.asCGFloat,
            size: viewModel.size.getSize ?? DEFAULT_PREVIEW_STREAMING_VIDEO_SIZE,
            opacity: viewModel.opacity.getNumber ?? defaultOpacityNumber,
            scale: viewModel.scale.getNumber ?? 1,
            anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
            blurRadius: viewModel.blurRadius.getNumber ?? .zero,
            blendMode: viewModel.blendMode.getBlendMode ?? .defaultBlendMode,
            brightness: viewModel.brightness.getNumber ?? .defaultBrightnessForLayerEffect,
            contrast: viewModel.contrast.getNumber ?? .defaultContrastForLayerEffect,
            hueRotation: viewModel.hueRotation.getNumber ?? .defaultHueRotationForLayerEffect,
            saturation: viewModel.saturation.getNumber ?? .defaultSaturationForLayerEffect,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            parentIsScrollableGrid: parentIsScrollableGrid)
    }
}

struct PreviewVideoStreamLayer: View {
    let document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    let layerViewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    let enabled: Bool
    @Binding var currentVideoURLString: String 
    let volume: Double
    let position: StitchPosition
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    let size: LayerSize
    let opacity: Double
    let scale: Double
    let anchoring: Anchoring
    let blurRadius: CGFloat
    let blendMode: StitchBlendMode
    let brightness: Double
    let contrast: Double
    let hueRotation: Double
    let saturation: Double
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    let parentIsScrollableGrid: Bool

    var body: some View {
        VideoStreamPlayerView(urlString: $currentVideoURLString, volume: volume, enabled: enabled)
            .opacity(enabled ? opacity : 0.0)
            .modifier(PreviewCommonModifier(
                document: document,
                graph: graph,
                layerViewModel: layerViewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                interactiveLayer: interactiveLayer,
                position: position,
                rotationX: rotationX,
                rotationY: rotationY,
                rotationZ: rotationZ,
                size: size,
                scale: scale,
                anchoring: anchoring,
                blurRadius: blurRadius,
                blendMode: blendMode,
                brightness: brightness,
                colorInvert: false,
                contrast: contrast,
                hueRotation: hueRotation,
                saturation: saturation,
                pivot: .defaultPivot,
                shadowColor: .defaultShadowColor,
                shadowOpacity: .defaultShadowOpacity,
                shadowRadius: .defaultShadowRadius,
                shadowOffset: .defaultShadowOffset,
                parentSize: parentSize,
                parentDisablesPosition: parentDisablesPosition,
                parentIsScrollableGrid: parentIsScrollableGrid))
    }
}



struct VideoStreamPlayerView: UIViewRepresentable {
    @Binding var urlString: String
    var volume: Double
    var enabled: Bool

    func makeUIView(context: Context) -> UIView {
        return VideoStreamPlayerUIView(frame: .zero, urlString: urlString, volume: volume)
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let playerView = uiView as? VideoStreamPlayerUIView else { return }

        if playerView.currentURLString != urlString {
              if let newURL = URL(string: urlString) {
                  playerView.updateURL(newURL)
              }
          }
        playerView.updateVolume(volume: Float(volume))

        if enabled {
            playerView.play()
        } else {
            playerView.pause()
        }
    }
}

class VideoStreamPlayerUIView: UIView {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    var currentURLString: String?

    init(frame: CGRect, urlString: String, volume: Double) {
        super.init(frame: frame)
        self.currentURLString = urlString
        guard let url = URL(string: self.currentURLString ?? "") else {
            return
        }
        
        setupPlayer(url: url, volume: Float(volume))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateURL(_ url: URL) {
        // Update the current URL string
        currentURLString = url.absoluteString
        setupPlayer(url: url, volume: player?.volume ?? 0.5)
    }
    
    func updateVolume(volume: Float) {
        player?.volume = volume
    }
    
    private func setupPlayer(url: URL, volume: Float) {
        player?.pause()
        player?.replaceCurrentItem(with: AVPlayerItem(url: url))

        if player == nil {
            player = AVPlayer(url: url)
            playerLayer = AVPlayerLayer(player: player)
            playerLayer?.videoGravity = .resizeAspectFill
            layer.addSublayer(playerLayer!)
        } else {
            playerLayer?.player = player
        }

        playerLayer?.frame = bounds
        player?.volume = volume
        player?.play()
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = self.bounds
    }
}
