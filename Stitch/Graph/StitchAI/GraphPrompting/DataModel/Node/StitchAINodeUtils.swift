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
