//
//  StitchAINodeUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/13/25.
//

import SwiftUI
import StitchSchemaKit

/// Redundant copy for newest version, should Stitch AI and SSK versions diverge.
extension CurrentStep.NodeKind {
    static func getAiNodeDescriptions() -> [StitchAINodeKindDescription] {
        // Filter out the scroll interaction node
        let allDescriptions = CurrentStep.Patch.allAiDescriptions + CurrentStep.Layer.allAiDescriptions
        return allDescriptions.filter { description in
            !description.nodeKind.contains("scrollInteraction")
        }
    }
}

struct StitchAINodeKindDescription {
    let nodeKind: String
    let description: String
    let types: Set<CurrentStep.NodeType>?
}

extension StitchAINodeKindDescription: Encodable {
    enum CodingKeys: String, CodingKey {
        case nodeKind = "node_kind"
        case description
        case types
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodeKind, forKey: .nodeKind)
        try container.encode(description, forKey: .description)
        
        if let types = self.types {
            let typeStrings = types.map(\.asLLMStepNodeType)
            try container.encode(Array(typeStrings).sorted(), forKey: .types)
        }
    }
}

struct StitchAINodeSectionDescription: Encodable {
    var header: String
    var nodes: [StitchAINodeIODescription]
}

extension StitchAINodeSectionDescription {
    @MainActor
    init(_ section: NodeSection,
         graph: GraphState) throws {
        let nodesInSection: [StitchAINodeIODescription] = try section
            .getNodesForSection()
            .compactMap { patchOrLayer -> StitchAINodeIODescription? in
                guard let migratedPatchOrLayer = try? patchOrLayer.convert(to: PatchOrLayer.self) else {
                    fatalErrorIfDebug("StitchAINodeSectionDescription: unable to convert patchOrLayer for: \(patchOrLayer)")
                    return nil
                }
                
                // Use node definitions, if available
                if let graphNode = migratedPatchOrLayer.graphNode {
                    return try .init(graphNode)
                }
                
                // Backup plan: create default node, extract data from there
                guard let defaultNode = migratedPatchOrLayer
                    .createDefaultNode(id: .init(),
                                       activeIndex: .init(.zero),
                                       graphDelegate: graph) else {
                    fatalErrorIfDebug()
                    return nil
                }
                
                let inputs: [StitchAIPortValueDescription] = try defaultNode.inputsObservers.compactMap { inputObserver in
                    let runtimeValue = inputObserver.getActiveValue(activeIndex: .init(.zero))
                    
                    // Backwards compat check for runtime's PortValue
                    // Silent failures allow for new port value types to get ignored, which should be ok for layers
                    guard let migratedValue = try? runtimeValue.convert(to: CurrentStep.PortValue.self) else {
                        switch patchOrLayer {
                        case .patch(let patch):
                            fatalErrorIfDebug("Issues reading values for patch \(patch) on value \(runtimeValue)")
                            throw StitchAIManagerError.portValueDescriptionNotSupported(patchOrLayer.asLLMStepNodeName)
                        
                        case .layer:
                            // Less of a big deal for layers to not support inputs since ordering isn't important
                            return nil
                        }
                    }
                    
                    return StitchAIPortValueDescription(
                        label: inputObserver.label(node: defaultNode,
                                                   coordinate: .input(inputObserver.id),
                                                   graph: graph),
                        value: migratedValue)
                }
                
                // Calculate node to get outputs values
                if let evalResult = defaultNode.evaluate() {
                    defaultNode.updateOutputsObservers(newValuesList: evalResult.outputsValues, graph: graph)
                }
                
                let outputs: [StitchAIPortValueDescription] = try defaultNode.outputsObservers.map { outputObserver in
                    let runtimeValue = outputObserver.getActiveValue(activeIndex: .init(.zero))
                    
                    // Backwards compat check for runtime's PortValue
                    let migratedValue = try runtimeValue.convert(to: CurrentStep.PortValue.self)
                    
                    return StitchAIPortValueDescription(
                        label: outputObserver.label(node: defaultNode,
                                                    coordinate: .output(outputObserver.id),
                                                    graph: graph),
                        value: migratedValue)
                }
                
                assertInDebug(inputs.first { $0.value == .none } == nil)
                assertInDebug(outputs.first { $0.value == .none } == nil)
                
                return .init(nodeKind: patchOrLayer.asLLMStepNodeName,
                             inputs: inputs,
                             outputs: outputs)
            }
        
        self.header = section.description
        self.nodes = nodesInSection
    }
}

struct StitchAINodeIODescription: Encodable {
    var nodeKind: String
    var inputs: [StitchAIPortValueDescription]
    var outputs: [StitchAIPortValueDescription]
}

extension StitchAINodeIODescription {
    @MainActor
    init(_ NodeInfo: any NodeDefinition.Type) throws {
        let migratedNodeKind = try NodeInfo.graphKind.kind.convert(to: CurrentStep.PatchOrLayer.self)
        self.nodeKind = migratedNodeKind.asLLMStepNodeName
        let rowDefinitions = NodeInfo.rowDefinitions(for: NodeInfo.defaultUserVisibleType)
        
        do {
            self.inputs = try rowDefinitions.inputs.compactMap {
                // Migrates PortValue data to supported AI version
                guard let migratedInput = try? $0.defaultValues.first!.convert(to: CurrentStep.PortValue.self) else {
                    // Silent failure for layer inputs which don't have ordering constraints of patches
                    switch migratedNodeKind {
                    case .layer:
                        return nil
                    case .patch:
                        throw StitchAIManagerError.portValueDescriptionNotSupported(migratedNodeKind.asLLMStepNodeName)
                    }
                }
                
                return .init(label: $0.label,
                             value: migratedInput)
            }
            
            self.outputs = try rowDefinitions.outputs.map {
                let migratedOutput = try $0.value.convert(to: CurrentStep.PortValue.self)
                
                return .init(label: $0.label,
                             value: migratedOutput)
            }
        } catch {
            log("Error converting node types at StitchAINodeIODescription for \(self.nodeKind): \(error.localizedDescription)")
            throw StitchAIManagerError.portValueDescriptionNotSupported(migratedNodeKind.asLLMStepNodeName)
        }
    }
}

struct StitchAIPortValueDescription {
    var label: String
    var value: CurrentStep.PortValue
}

extension StitchAIPortValueDescription: Encodable {
    enum CodingKeys: String, CodingKey {
        case label
        case valueType
        case value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let nodeType = self.value.nodeType
        
        try container.encodeIfPresent(self.label != "" ? self.label : nil,
                                      forKey: .label)
        try container.encode(nodeType.asLLMStepNodeType,
                             forKey: .valueType)
        try container.encode(self.value.anyCodable,
                             forKey: .value)
    }
}

extension AIGraphCreationContentJSON {
    static func exampleData() -> Self {
        let id0 = UUID()
        let id1 = UUID()
        
        let addNode = StepActionAddNode(nodeId: id0, nodeName: .patch(.add))
        let textNode = StepActionAddNode(nodeId: id1, nodeName: .layer(.text))
        
        let setInput1 = StepActionSetInput(nodeId: id0,
                                          port: .portIndex(0),
                                          value: .number(3),
                                          valueType: .number)
        let setInput2 = StepActionSetInput(nodeId: id0,
                                          port: .portIndex(1),
                                          value: .number(5),
                                          valueType: .number)
        let changeType = StepActionChangeValueType(nodeId: id0,
                                                  valueType: .string)
        
        let makeConnection = StepActionConnectionAdded(
            port: .keyPath(.init(layerInput: .text,
                                 portType: .packed)),
            toNodeId: id1,
            fromPort: 0,
            fromNodeId: id0)
        
        let steps: [Step] = [
            addNode.toStep,
            textNode.toStep,
            setInput1.toStep,
            setInput2.toStep,
            changeType.toStep,
            makeConnection.toStep
        ]
        
        return .init(steps: steps)
    }
}
