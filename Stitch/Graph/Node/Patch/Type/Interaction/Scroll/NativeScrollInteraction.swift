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
                    defaultValues: [.bool(Self.defaultScrollXEnabled)],
                    label: "Scroll X Enabled"
                ),
                .init(
                    defaultValues: [.bool(Self.defaultScrollYEnabled)],
                    label: "Scroll Y Enabled"
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

    static let defaultScrollXEnabled: Bool = false
    static let defaultScrollYEnabled: Bool = true
    
    static let defaultIndicatorsHidden: Bool = true
    
    static let defaultOutputs: PortValuesList =  [[.position(.zero)]]
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
        
    return node.loopedEval(graphState: state) { values, interactiveLayer, loopIndex in
        nativeScrollInteractionEvalOp(
            values: values,
            interactiveLayer: interactiveLayer,
            // TODO: DEC 3: grab parentSize from readSize of `assignedLayerNodeViewModel.layerGroupdId` ?
            parentSize: interactiveLayer.parentSize,
            currentGraphTime: state.graphStepState.graphTime)
    }.toImpureEvalResult()
}

@MainActor
func nativeScrollInteractionEvalOp(values: PortValues,
                                   interactiveLayer: InteractiveLayer,
                                   parentSize: CGSize,
                                   currentGraphTime: TimeInterval) -> ImpureEvalOpResult {
    
    // Update interactiveLayer according to inputs
    let xScrollEnabled = values[safe: NativeScrollNodeInputLocations.xScrollEnabled]?.getBool ?? NativeScrollInteractionNode.defaultScrollXEnabled
    let yScrollEnabled = values[safe: NativeScrollNodeInputLocations.yScrollEnabled]?.getBool ?? NativeScrollInteractionNode.defaultScrollYEnabled
    interactiveLayer.nativeScrollState.xScrollEnabled = xScrollEnabled
    interactiveLayer.nativeScrollState.yScrollEnabled = yScrollEnabled
    
    let contentSize = values[safe: NativeScrollNodeInputLocations.contentSize]?.getSize ?? .zero
    interactiveLayer.nativeScrollState.contentSize = contentSize.asCGSize(parentSize)
    
    let jumpStyleX = values[safe: NativeScrollNodeInputLocations.jumpStyleX]?.getScrollJumpStyle ?? .scrollJumpStyleDefault
    let jumpToX = values[safe: NativeScrollNodeInputLocations.jumpToX]?.getPulse ?? .zero
    let jumpPositionX = values[safe: NativeScrollNodeInputLocations.jumpPositionX]?.getNumber ?? .zero
    interactiveLayer.nativeScrollState.jumpStyleX = jumpStyleX
    interactiveLayer.nativeScrollState.jumpToX = jumpToX == currentGraphTime
    interactiveLayer.nativeScrollState.jumpPositionX = jumpPositionX
    
    let jumpStyleY = values[safe: NativeScrollNodeInputLocations.jumpStyleY]?.getScrollJumpStyle ?? .scrollJumpStyleDefault
    let jumpToY = values[safe: NativeScrollNodeInputLocations.jumpToY]?.getPulse ?? .zero
    let jumpPositionY = values[safe: NativeScrollNodeInputLocations.jumpPositionY]?.getNumber ?? .zero
    interactiveLayer.nativeScrollState.jumpStyleY = jumpStyleY
    interactiveLayer.nativeScrollState.jumpToY = jumpToY == currentGraphTime
    interactiveLayer.nativeScrollState.jumpPositionY = jumpPositionY
    
    let offsetFromScrollView = interactiveLayer.nativeScrollState.rawScrollViewOffset
        
    return .init(outputs: [
        .position(offsetFromScrollView)
    ])
}


struct NativeScrollNodeInputLocations {
    // The specific assigned layer (LayerNodeId)
    static let assignedLayer = 0

    static let xScrollEnabled = 1
    static let yScrollEnabled = 2

    static let contentSize = 3

    static let jumpStyleX = 4
    static let jumpToX = 5
    static let jumpPositionX = 6

    static let jumpStyleY = 7
    static let jumpToY = 8
    static let jumpPositionY = 9
}
