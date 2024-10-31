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

struct AssignedLayerUpdated: GraphEvent {
    let changedLayerNode: LayerNodeId
    
    @MainActor
    func handle(state: GraphState) {
        for id in state.layerListeningPatchNodes(assignedTo: changedLayerNode) {
            state.calculate(id) // TODO: batch calculate?
        }
    }
}

extension GraphState {
    // Some patch nodes (e.g. LayerInfo, ConvertPosition) effectively 'listen' to their assigned layer and must be eval'd whenever certain inputs change.
    // TODO: cache these?
    @MainActor
    func layerListeningPatchNodes(assignedTo id: LayerNodeId) -> IdSet {
        self.patchNodes.reduce(into: .init(), { partialResult, kv in
            let node = kv.value
            if node.patch?.listensToAssignedLayer ?? false,
               node.getInteractionId() == id {
                partialResult.insert(node.id)
            }
        })
    }
}

extension Patch {
    var listensToAssignedLayer: Bool {
        switch self {
        case .layerInfo, .convertPosition:
            return true
        default:
            return false
        }
    }
}

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
                    label: LayerInputPort.position.label(),
                    type: .position
                ),
                .init(
                    label: LayerInputPort.size.label(),
                    type: .size
                ),
                .init(
                    label: LayerInputPort.scale.label(),
                    type: .number
                ),
                .init(
                    label: "Anchor",
                    type: .anchoring
                ),
                .init(
                    label: LayerInputPort.opacity.label(),
                    type: .number
                ),
                .init(
                    label: LayerInputPort.zIndex.label(),
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
          let assignedLayerNode = state.getNodeViewModel(assignedLayerId.id),
          let assignedLayerNodeViewModel: LayerNodeViewModel = assignedLayerNode.layerNode else {
        log("layerInfoEval: no assignedLayerId, assignedLayerNode and/or assignedLayerNodeViewModel")
        return .init(outputsValues: LayerInfoNodeEvalHelpers.defaultOutputs)
    }
    
    let layerEnabled = assignedLayerNodeViewModel.hasSidebarVisibility
    let layerGroupParent = assignedLayerNodeViewModel.layerGroupId?.asLayerNodeId
    let layerViewModels = assignedLayerNodeViewModel.previewLayerViewModels
        
    // you want to return mm
    let evalOp: Operation8 = { values, loopIndex -> PortValueTuple8 in
        
        guard let layerViewModel = layerViewModels[safeIndex: loopIndex] else {
            log("layerInfoEval: no layerViewModel at loopIndex \(loopIndex)")
            return LayerInfoNodeEvalHelpers.defaultOutputsAtSingleIndex
        }
        
        log("layerInfoEval: layerViewModel.readSize: \(layerViewModel.readSize)")
        log("layerInfoEval: layerViewModel.anchoring.getAnchoring: \(layerViewModel.anchoring.getAnchoring)")
                        
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
