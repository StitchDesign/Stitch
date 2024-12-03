//
//  NativeScrollInteraction.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/3/24.
//

import SwiftUI

struct NativeScrollInteractionNode: PatchNodeDefinition {
    static let patch = Patch.nativeScrollInteraction
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [interactionIdDefault],
                    label: "Layer"
                ),
                .init(
                    defaultValues: [scrollModeDefault],
                    label: "Scroll X"
                ),
                .init(
                    defaultValues: [scrollModeDefault],
                    label: "Scroll Y"
                ),
                .init(
                    defaultValues: [.size(.zero)],
                    label: "Content Size"
                ),
                .init(
                    defaultValues: [.scrollJumpStyle(.scrollJumpStyleDefault)],
                    label: "Jump Style X"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Jump to X"
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Jump Position X"
                ),
                .init(
                    defaultValues: [.scrollJumpStyle(.scrollJumpStyleDefault)],
                    label: "Jump Style Y"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Jump to Y"
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Jump Position Y"
                ),
                .init(
                    defaultValues: [.bool(true)],
                    label: "Hide Indicators"
                )
            ],
            outputs: [
                .init(
                    label: LayerInputPort.position.label(),
                    type: .position
                )
            ]
        )
    }

    // NOT NEEDED ?
//    static func createEphemeralObserver() -> NodeEphemeralObservable? {
//        ScrollInteractionState()
//    }
    
    static let defaultOutputs: PortValuesList =  [[.number(.zero)]]
}


/*
 Inputs are extended to be as long as the longest loop on the *assigned layer*
 
 Eval modifies underlying layer view models.
 
 ?? When ScrollView.onScrollGeometry fires, we update the LayerViewModel's InteractiveLayer, then call the nativeScrollInteractionEval.
 */
@MainActor
func nativeScrollInteractionEval(node: PatchNode,
                                 // should be impure?
                                 state: GraphDelegate) -> EvalResult {
//                                 state: GraphDelegate) {
    
    guard !node.outputs.isEmpty else {
        log("nativeScrollInteractionEval: initializing outputs")
        return .init(outputsValues: NativeScrollInteractionNode.defaultOutputs)
    }
    
    guard let assignedLayerId: LayerNodeId = node.inputs.first?.first?.getInteractionId,
          let assignedLayerNode = state.getNodeViewModel(assignedLayerId.id),
          let assignedLayerNodeViewModel: LayerNodeViewModel = assignedLayerNode.layerNode else {
        log("nativeScrollInteractionEval: no assignedLayerId, assignedLayerNode and/or assignedLayerNodeViewModel for \(node.id)")
        return .init(outputsValues: NativeScrollInteractionNode.defaultOutputs)
    }
    
    // TODO: handle inputs -- extend inputs to be as long as layerViewModels list, and update each layerViewModel accordingly
    // first extend the inputs,
    // then index into them for the layer view model's given loop-index
    
    let layerViewModels = assignedLayerNodeViewModel.previewLayerViewModels
    
    var outputLoop = PortValues()
    
    layerViewModels.forEach { layerViewModel in
        let offsetFromScrollView = layerViewModel.interactiveLayer.nativeScrollState.rawScrollViewOffset
        
        outputLoop.append(.position(offsetFromScrollView))
    }
    
    return .init(outputsValues: [outputLoop])
    
}
