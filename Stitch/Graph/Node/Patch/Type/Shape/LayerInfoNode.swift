//
//  LayerInfoNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/7/22.
//

/*
 input: layer dropdown

 outputs:
 - enabled (ie hidden)
 - position
 - size
 - scale
 - anchor
 - parent (nil if layer not in a group)
 */
import Foundation
import StitchSchemaKit

struct LayerInfoPatchNode: PatchNodeDefinition {
    static let patch = Patch.layerInfo
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [interactionIdDefault],
                    label: "Layer"
                )
            ],
            outputs: [
                .init(
                    label: "Enabled",
                    type: .bool
                ),
                .init(
                    label: LayerInputType.position.label(),
                    type: .position
                ),
                .init(
                    label: LayerInputType.size.label(),
                    type: .size
                ),
                .init(
                    label: LayerInputType.scale.label(),
                    type: .number
                ),
                .init(
                    label: "Anchor",
                    type: .anchoring
                ),
                .init(
                    label: LayerInputType.opacity.label(),
                    type: .number
                ),
                .init(
                    label: LayerInputType.zIndex.label(),
                    type: .number
                ),
                .init(
                    label: "Parent",
                    value: .assignedLayer(nil)
                )
            ]
        )
    }
}


struct AssignedLayerUpdated: GraphEvent {
    let changedLayerNode: LayerNodeId
    
    func handle(state: GraphState) {
        for id in state.layerInfoPatchNodes(assignedTo: changedLayerNode) {
            state.calculate(id)
        }
        
    }
}

extension GraphState {
    @MainActor
    func layerInfoPatchNodes(assignedTo id: LayerNodeId) -> IdSet {
        self.patchNodes.reduce(into: .init(), { partialResult, kv in
            let node = kv.value
            if node.patch == .layerInfo,
               node.getInteractionId() == id {
                partialResult.insert(node.id)
            }
        })
    }
}


extension Array {
    
    /**
     Attempt to convert a tuple into an Array.
     
     - Parameter tuple: The tuple to try and convert. All members must be of the same type.
     - Returns: An array of the tuple's values, or `nil` if any tuple members do not match the `Element` type of this array.
     */
    static func fromTuple<Tuple> (_ tuple: Tuple) -> [Element]? {
        let val = Array<Element>.fromTupleOptional(tuple)
        return val.allSatisfy({ $0 != nil }) ? val.map { $0! } : nil
    }
    
    /**
     Convert a tuple into an array.
     
     - Parameter tuple: The tuple to try and convert.
     - Returns: An array of the tuple's values, with `nil` for any values that could not be cast to the `Element` type of this array.
     */
    static func fromTupleOptional<Tuple> (_ tuple: Tuple) -> [Element?] {
        return Mirror(reflecting: tuple)
            .children
            .filter { child in
                (child.label ?? "x").allSatisfy { char in ".1234567890".contains(char) }
            }.map { $0.value as? Element }
    }
}

struct LayerInfoNodeEvalHelpers {
        
    static let defaultOutputsAtSingleIndex: PortValueTuple8 = (
        .bool(false),
        .position(.zero),
        .size(.zero),
        .number(.zero),
        .anchoring(.topLeft),
        .number(.multiplicationIdentity),
        .number(.additionIdentity),
        .assignedLayer(nil)
    )
    
    static let defaultOutputs: PortValuesList = (Array.fromTuple(Self.defaultOutputsAtSingleIndex) ?? []).map { [$0] }
}

@MainActor
func layerInfoEval(node: PatchNode,
                    state: GraphDelegate) -> EvalResult {
    
    guard let assignedLayerId: LayerNodeId = node.inputs.first?.first?.getInteractionId,
          let assignedLayerNode: LayerNodeViewModel = state.getNodeViewModel(assignedLayerId.id)?.layerNode else {
        return .init(outputsValues: LayerInfoNodeEvalHelpers.defaultOutputs)
    }
    
    let layerEnabled = assignedLayerNode.hasSidebarVisibility
    let layerGroupParent = assignedLayerNode.layerGroupId?.asLayerNodeId
    let layerViewModels = assignedLayerNode.previewLayerViewModels
        
    // you want to return mm
    let evalOp: Operation8 = { values, loopIndex -> PortValueTuple8 in
        
        guard let layerViewModel = layerViewModels[safeIndex: loopIndex] else {
            return LayerInfoNodeEvalHelpers.defaultOutputsAtSingleIndex
        }
                        
        return (
            // Enabled (visibility hidden via sidebar or not)
            .bool(layerEnabled),
            
            // Position
            .position(layerViewModel.position.getPosition ?? .zero),
            
            // Size: read from GeometryReader
            .size(.init(layerViewModel.readSize)),
            
            // Scale
            .number(layerViewModel.scale.getNumber ?? .defaultScale),
            
            // Anchor
            .anchoring(layerViewModel.anchoring.getAnchoring ?? .defaultAnchoring),
            
            // Opacity
            .number(layerViewModel.opacity.getNumber ?? 1),
            
            // zIndex
            .number(layerViewModel.zIndex.getNumber ?? 0),
            
            // Assigned parent (layer group)
            .assignedLayer(layerGroupParent)
        )
    }
    
    let newOutputs = outputEvalHelper8(inputs: node.inputs,
                                       outputs: [],
                                       operation: evalOp)
    return .init(outputsValues: newOutputs)
}
