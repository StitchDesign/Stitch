//
//  StitchAINodeUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/13/25.
//

import SwiftUI
import StitchSchemaKit

extension NodeKind {
//    static let aiNodeDescriptions: String = """
//\(Patch.allCases.map(\.aiDisplayTitle))\n
//\(Layer.allCases.map(\.aiDisplayTitle))\n
//"""
    
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
        let nodesInSection: [any NodeDefinition.Type] = section
            .getNodesForSection()
            .compactMap(\.graphNode)

        self.header = section.description
        self.nodes = nodesInSection.map(StitchAINodeIODescription.init)
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
            .init($0.defaultValues.first!)
        }
        
        self.outputs = rowDefinitions.outputs.map {
            .init($0.value)
        }
    }
}

struct StitchAIPortValueDescription {
    var value: PortValue
}

extension StitchAIPortValueDescription {
    init(_ portValue: PortValue) {
        self.value = portValue
    }
}

extension StitchAIPortValueDescription: Encodable {
    enum CodingKeys: String, CodingKey {
        case nodeType
        case value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let nodeType = self.value.toNodeType
        
        try container.encode(nodeType.asLLMStepNodeType,
                             forKey: .nodeType)
        try container.encode(self.value.anyCodable,
                             forKey: .value)
    }
}
