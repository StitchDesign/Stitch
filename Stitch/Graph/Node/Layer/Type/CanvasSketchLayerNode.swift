//
//  CanvasSketchLayerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/2/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension LayerSize {
    static let CANVAS_LAYER_DEFAULT_SIZE: Self = .init(width: 200, height: 200)
}

// TODO: maybe?: add `Reset`, `Undo` and `Redo` pulse inputs
struct CanvasSketchLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.canvasSketch

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(layerInputs: Self.inputDefinitions,
              outputs: [.init(label: "Image",
                              type: .media)],
              layer: Self.layer)
    }
    
    static let inputDefinitions: LayerInputTypeSet = .init([
        .canvasLineColor,
        .canvasLineWidth,
        .position,
        .rotationX,
        .rotationY,
        .rotationZ,
        .size,
        .opacity,
        .scale,
        .anchoring,
        .zIndex,
        .blur, // .blur vs .blurRadius ?
        .masks,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ])
        .union(.strokeInputs)
        .union(.layerEffects)
        .union(.aspectRatio)
        .union(.sizing).union(.pinning).union(.layerPaddingAndMargin).union(.offsetInGroup)

        static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList,
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool) -> some View {
        CanvasSketchView(document: document,
                         graph: graph,
                         layerViewModel: viewModel,
                         isPinnedViewRendering: isPinnedViewRendering,
                         interactiveLayer: viewModel.interactiveLayer,
                         lineColor: viewModel.lineColor.getColor ?? CanvasSketchLayerNodeHelpers.defaultLineColor,
                         lineWidth: viewModel.lineWidth.getNumber ?? CanvasSketchLayerNodeHelpers.defaultLineWidth,
                         position: viewModel.position.getPosition ?? .zero,
                         rotationX: viewModel.rotationX.asCGFloat,
                         rotationY: viewModel.rotationY.asCGFloat,
                         rotationZ: viewModel.rotationZ.asCGFloat,
                         size: viewModel.size.getSize ?? .zero,
                         opacity: viewModel.opacity.getNumber ?? .zero,
                         scale: viewModel.scale.getNumber ?? .zero,
                         anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
                         // TODO: fix blur and blend mode; wrong index?:
                         // https://github.com/vpl-codesign/stitch/issues/5348
                         blurRadius: viewModel.blurRadius.getNumber ?? .zero,
                         blendMode: viewModel.blendMode.getBlendMode ?? .normal,
                         brightness: viewModel.brightness.getNumber ?? .defaultBrightnessForLayerEffect,
                         colorInvert: viewModel.colorInvert.getBool ?? .defaultColorInvertForLayerEffect,
                         contrast: viewModel.contrast.getNumber ?? .defaultContrastForLayerEffect,
                         hueRotation: viewModel.hueRotation.getNumber ?? .defaultHueRotationForLayerEffect,
                         saturation: viewModel.saturation.getNumber ?? .defaultSaturationForLayerEffect,
                         shadowColor: viewModel.shadowColor.getColor ?? .defaultShadowColor,
                         shadowOpacity: viewModel.shadowOpacity.getNumber ?? .defaultShadowOpacity,
                         shadowRadius: viewModel.shadowRadius.getNumber ?? .defaultShadowOpacity,
                         shadowOffset: viewModel.shadowOffset.getPosition ?? .defaultShadowOffset,
                         lines: viewModel.lines,
                         parentSize: parentSize,
                         parentDisablesPosition: parentDisablesPosition)
    }
}

@MainActor
func canvasSketchEval(node: PatchNode) -> EvalResult {

    // log("canvasSketchEval called")

    node.loopedEval(MediaEvalOpObserver.self) { values, asyncObserver, loopIndex in
        // TODO: presumably?: if the lineColor and lineWidth inputs at this index changed, we should update the existing DrawingViewLines at this index as well
        
        guard let canvasLayerViewModel = node.layerNode?.previewLayerViewModels[safe: loopIndex] else {
            // log("canvasSketchEval: could not find canvasLayerViewModel for node \(node.id) at loop index \(loopIndex)")
            return node.defaultOutputs
        }
        
        let sizeAtIndex = canvasLayerViewModel.size.getSize?.asCGSize(canvasLayerViewModel.parentSizeFromDrag) ?? .LAYER_DEFAULT_SIZE
        
        return asyncObserver.asyncMediaEvalOp(loopIndex: loopIndex,
                                              values: values,
                                              node: node) { [weak canvasLayerViewModel] in
            guard let canvasLayerViewModel = canvasLayerViewModel else {
                return node.defaultOutputs
            }
            
            switch await createUIImageFromCanvasView(canvasLayerViewModel.lines,
                                                     sizeAtIndex) {
                
            case .success(let image):
                // log("canvasSketchEval: success")
                return [.asyncMedia(AsyncMediaValue(id: .init(),
                                                    dataType: .computed,
                                                    mediaObject: .image(image)))]
                
            case .failure(let error):
                // log("canvasSketchEval: failure")
                // TODO: do we always want to show the error?
                return node.defaultOutputs
            }
        }
    }
}

@MainActor
func createUIImageFromCanvasView(_ lines: DrawingViewLines,
                                 // TODO: should this size be scaled? how should
                                 _ layerSizeAtIndex: CGSize) async -> StitchFileResult<UIImage> {

    // log("createUIImageFromCanvasView: lines.count: \(lines.count)")

    // TODO: pass down real size
    let d = CanvasDrawingView(lines: lines)
        //        .frame(width: 300, height: 300)
        .frame(width: layerSizeAtIndex.width,
               height: layerSizeAtIndex.height)

    let renderer = ImageRenderer(content: d)

    // make sure and use the correct display scale for this device
    // renderer.scale = displayScale // // NOT NEEDED?

    if let uiImage = renderer.uiImage {
        // log("createUIImageFromCanvasView: got ui image from renderer")
        uiImage.accessibilityIdentifier = "Canvas"
        return .success(uiImage)
    } else {
        return .failure(.canvasSketchImageRenderingFailed)
    }

}
