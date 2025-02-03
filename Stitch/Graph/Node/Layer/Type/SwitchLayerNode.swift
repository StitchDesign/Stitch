//
//  SwitchLayerNode.swift
//  Stitch
//
//  Created by Nicholas Arner on 3/28/24.
//

import StitchSchemaKit
import SwiftUI


struct SwitchLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.switchLayer

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(layerInputs: self.inputDefinitions,
              outputs: [
                .init(label: "Enabled",
                      type: .bool)
              ],
              layer: Self.layer)
    }
    
    static let inputDefinitions: LayerInputPortSet = .init([
        .isSwitchToggled,
        .position,
        .rotationX,
        .rotationY,
        .rotationZ,
        .opacity,
        .anchoring,
        .zIndex,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.pinning).union(.layerPaddingAndMargin).union(.offsetInGroup)
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList,
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: LayerRealityCameraContent?) -> some View {
        PreviewSwitchLayer(
            document: document,
            graph: graph,
            viewModel: viewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            id: viewModel.id, 
            isEnabled: viewModel.enabled.getBool ?? false,
            togglePulse: viewModel.isSwitchToggled.getPulse ?? .zero,
            position: viewModel.position.getPosition ?? .zero,
            rotationX: viewModel.rotationX.getNumber ?? .zero,
            rotationY: viewModel.rotationY.getNumber ?? .zero,
            rotationZ: viewModel.rotationZ.getNumber ?? .zero,
            opacity: viewModel.opacity.getNumber ?? .zero,
            anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
            blurRadius: viewModel.blurRadius.getNumber ?? .zero,
            blendMode: viewModel.blendMode.getBlendMode ?? .defaultBlendMode,
            brightness: viewModel.brightness.getNumber ?? .defaultBrightnessForLayerEffect,
            colorInvert: viewModel.colorInvert.getBool ?? .defaultColorInvertForLayerEffect,
            contrast: viewModel.contrast.getNumber ?? .defaultContrastForLayerEffect,
            hueRotation: viewModel.hueRotation.getNumber ?? .defaultHueRotationForLayerEffect,
            saturation: viewModel.saturation.getNumber ?? .defaultSaturationForLayerEffect,
            parentSize: parentSize,
            parentDisablesPosition: false,
            parentIsScrollableGrid: parentIsScrollableGrid)
    }
}

struct SwitchLayerToggled: GraphEvent {
    let id: PreviewCoordinate
    
    func handle(state: GraphState) {
        state.calculate(id.layerNodeId.id)
    }
}

struct PreviewSwitchLayer: View {

    // TODO: read the REAL, potentially dynamic size of SwiftUI Toggle Switch? Varies by iPad vs Mac?
    static let ASSUMED_SWIFTUI_TOGGLE_SWITCH_SIZE = CGSize(width: 40, height: 40)
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var viewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    let id: PreviewCoordinate
    let isEnabled: Bool
    let togglePulse: TimeInterval
    let position: CGPoint
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    let opacity: Double
    let anchoring: Anchoring
    let blurRadius: CGFloat
    let blendMode: StitchBlendMode
    let brightness: Double
    let colorInvert: Bool
    let contrast: Double
    let hueRotation: Double
    let saturation: Double
    
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    let parentIsScrollableGrid: Bool

    var body: some View {
        let view = Toggle("", isOn: $viewModel.isUIToggled)
            .toggleStyle(.switch)
            .labelsHidden()

        return view
            .modifier(PreviewCommonModifier(
                document: document,
                graph: graph,
                layerViewModel: viewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                interactiveLayer: interactiveLayer,
                position: position,
                rotationX: rotationX,
                rotationY: rotationY,
                rotationZ: rotationZ,
                //            size: Self.ASSUMED_SWIFTUI_TOGGLE_SWITCH_SIZE,
                size: .init(Self.ASSUMED_SWIFTUI_TOGGLE_SWITCH_SIZE),
                minimumDragDistance: SWITCH_NODE_MINIMUM_DRAG_DISTANCE,
                scale: 1, // Always 1, since "no real size"
                anchoring: anchoring,
                blurRadius: blurRadius,
                blendMode: blendMode,
                brightness: brightness,
                colorInvert: colorInvert,
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
                parentIsScrollableGrid: parentIsScrollableGrid
            ))
        .onChange(of: self.viewModel.isUIToggled) {
            dispatch(SwitchLayerToggled(id: id))
        }
    }
}

let SWITCH_NODE_MINIMUM_DRAG_DISTANCE = 5.0

let DEFAULT_SWITCH_SIZE = CGSizeMake(40, 40).toLayerSize

@MainActor
func switchLayerEval(node: NodeViewModel,
                     graphStep: GraphStepState) -> EvalResult {

    guard let layerNodeViewModel = node.layerNode else {
        fatalErrorIfDebug()
        return .init(outputsValues: [[.bool(false)]])
    }

    let switchLayerViewModels = layerNodeViewModel.previewLayerViewModels

    let evalOp: OpWithIndex<PortValue> = { values, loopIndex in
        
        // Track toggle state with current output
        
        guard let layerViewModel = switchLayerViewModels[safe: loopIndex] else {
            return .bool(false)
        }

        let enabled = layerViewModel.isUIToggled
        let pulseInput = values.first?.getPulse ?? .zero
        let pulsed = pulseInput.shouldPulse(graphStep.graphTime)
        
        // If we had a pulse in the "toggle" input, then take the current output ("enabled") and flip it.
        if pulsed {
            // Must update both the output AND the view model at this index:
            let outputNowToggled = enabled.toggled()
            
            // update ephemeral observer
            layerViewModel.isUIToggled = outputNowToggled
            
            // update output
            switchLayerViewModels[safe: loopIndex]?.enabled = .bool(outputNowToggled)
            return .bool(outputNowToggled)
        }
        
        // Else this is just a simple case of responding to a UI event, i.e. user toggled the switch from within the preview window.
        else {
            return .bool(enabled)
        }
    }

    let newOutput = loopedEval(node: node, evalOp: evalOp)

    return .init(outputsValues: [newOutput])
}

extension Bool {
    func toggled() -> Self {
        self ? false : true
    }
}
