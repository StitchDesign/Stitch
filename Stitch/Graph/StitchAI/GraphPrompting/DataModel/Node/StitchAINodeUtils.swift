//
//  StitchAINodeUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/13/25.
//

import SwiftUI
import StitchSchemaKit

extension NodeKind {
    static func getAiNodeDescriptions() -> [StitchAINodeKindDescription] {
        Patch.allAiDescriptions + Layer.allAiDescriptions
    }
}

protocol NodeKindDescribable: CaseIterable {
    func defaultDisplayTitle() -> String
    
    var aiNodeDescription: String { get }
    
    static var titleDisplay: String { get }
}

extension NodeKindDescribable {
    var aiDisplayTitle: String {
        self.defaultDisplayTitle().toCamelCase() + " || \(Self.titleDisplay)"
    }
    
    static var allAiDescriptions: [StitchAINodeKindDescription] {
        Self.allCases.map {
            .init($0)
        }
    }
}

struct StitchAINodeKindDescription: Encodable {
    var nodeKind: String
    var description: String
}

extension StitchAINodeKindDescription {
    init<T>(_ nodeKindType: T) where T: NodeKindDescribable {
        self.nodeKind = nodeKindType.aiDisplayTitle
        self.description = nodeKindType.aiNodeDescription
    }
}

struct StitchAINodeSectionDescription: Encodable {
    var header: String
    var nodes: [StitchAINodeIODescription]
}

extension StitchAINodeSectionDescription {
    @MainActor
    init(_ section: NodeSection) {
        let nodesInSection: [StitchAINodeIODescription] = section
            .getNodesForSection()
            .compactMap { nodeKind -> StitchAINodeIODescription? in
                // Use node definitions, if available
                if let graphNode = nodeKind.graphNode {
                    return .init(graphNode)
                }
                
                // Backup plan: create default node, extract data from there
                guard let defaultNode = nodeKind.createDefaultNode(id: .init(),
                                                             activeIndex: .init(.zero),
                                                                   graphDelegate: nil) else {
                    fatalErrorIfDebug()
                    return nil
                }
                
                let inputs: [StitchAIPortValueDescription] = defaultNode.inputsObservers.map { inputObserver in
                    StitchAIPortValueDescription(label: inputObserver.label(),
                                                 value: inputObserver.activeValue)
                }
                
                let outputs: [StitchAIPortValueDescription] = defaultNode.outputsObservers.map { outputObserver in
                    StitchAIPortValueDescription(label: outputObserver.label(),
                                                 value: outputObserver.activeValue)
                }
                
                return .init(nodeKind: nodeKind.asLLMStepNodeName,
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
    init(_ NodeInfo: any NodeDefinition.Type) {
        self.nodeKind = NodeInfo.graphKind.kind.asLLMStepNodeName
        let rowDefinitions = NodeInfo.rowDefinitions(for: NodeInfo.defaultUserVisibleType)
        
        self.inputs = rowDefinitions.inputs.map {
            .init(label: $0.label,
                  value: $0.defaultValues.first!)
        }
        
        self.outputs = rowDefinitions.outputs.map {
            .init(label: $0.label,
                  value: $0.value)
        }
    }
}

struct StitchAIPortValueDescription {
    var label: String
    var value: PortValue
}

extension StitchAIPortValueDescription: Encodable {
    enum CodingKeys: String, CodingKey {
        case label
        case valueType
        case value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let nodeType = self.value.toNodeType
        
        try container.encodeIfPresent(self.label != "" ? self.label : nil,
                                      forKey: .label)
        try container.encode(nodeType.asLLMStepNodeType,
                             forKey: .valueType)
        try container.encode(self.value.anyCodable,
                             forKey: .value)
    }
}
