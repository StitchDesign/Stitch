//
//  NodeKindDescribable_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/25.
//


extension Step_V0.PatchOrLayer {
    // Note: Swift `init?` is tricky for returning nil vs initializing self; we have to both initialize self *and* return, else we continue past if/else branches etc.;
    // let's prefer functions with clearer return values
    static func fromLLMNodeName(_ nodeName: String) throws -> Self {
        // E.G. from "squareRoot || Patch", grab just the camelCase "squareRoot"
        if let nodeKindName = nodeName.components(separatedBy: "||").first?.trimmingCharacters(in: .whitespaces) {
                        
            // Tricky: can't use `Patch(rawValue:)` constructor since newer patches use a non-camelCase rawValue
            if let patch = Step_V0.Patch.allCases.first(where: {
                // e.g. Patch.squareRoot 1-> "Square Root" -> "squareRoot"
                let patchDisplay = $0.defaultDisplayTitle().toCamelCase()
                return patchDisplay == nodeKindName
            }) {
                return .patch(patch)
            }

            //Handle cases where we have numbers...
            if nodeKindName == "base64StringToImage" {
                return .patch(.base64StringToImage)
            }
            
            if nodeKindName == "imageToBase64String" {
                return .patch(.imageToBase64String)
            }
            
            if nodeKindName == "arcTan2" {
                return .patch(.arcTan2)
            }
            
            else if let layer = Step_V0.Layer.allCases.first(where: {
                $0.defaultDisplayTitle().toCamelCase() == nodeKindName
            }) {
                return .layer(layer)
            }
        }
        
        throw StitchAIParsingError.nodeNameParsing(nodeName)
    }
    
    var description: String {
        switch self {
        case .patch(let patch):
            return patch.defaultDisplayTitle()
        case .layer(let layer):
            return layer.defaultDisplayTitle()
        }
    }
}

extension Step_V0.NodeIOPortType {
    // TODO: `LLMStepAction`'s `port` parameter does not yet properly distinguish between input vs output?
    // Note: the older LLMAction port-string-parsing logic was more complicated?
    init(stringValue: String) throws {
        let port = stringValue
  
        if let portId = Int(port) {
            // could be patch input/output OR layer output
            self = .portIndex(portId)
        } else if let portId = Double(port) {
            // could be patch input/output OR layer output
            self = .portIndex(Int(portId))
        } else if let layerInputPort: Step_V0.LayerInputPort = Step_V0.LayerInputPort.allCases.first(where: { $0.asLLMStepPort == port }) {
            let layerInputType = Step_V0.NodeIOPortTypeVersion
                .LayerInputType(layerInput: layerInputPort,
                                // TODO: support unpacked with StitchAI
                                portType: .packed)
            self = .keyPath(layerInputType)
        } else {
            throw StitchAIParsingError.portTypeDecodingError(port)
        }
    }
}



//enum NodeKindDescribable_V0 {
//    protocol NodeKindDescribable: CaseIterable {
//        func defaultDisplayTitle() -> String
//        
//        var aiNodeDescription: String { get }
//        
//        var types: Set<Step_V0.NodeType>? { get }
//        
//        static var titleDisplay: String { get }
//    }
//    
//    struct StitchAINodeKindDescription {
//        let nodeKind: String
//        let description: String
//        let types: Set<Step_V0.NodeType>?
//    }
//}
//
//extension NodeKindDescribable_V0.NodeKindDescribable {
//    var aiDisplayTitle: String {
//        Self.toCamelCase(self.defaultDisplayTitle()) + " || \(Self.titleDisplay)"
//    }
//    
//    static var allAiDescriptions: [NodeKindDescribable_V0.StitchAINodeKindDescription] {
//        Self.allCases.map {
//            .init(nodeKind: $0.aiDisplayTitle,
//                  description: $0.aiNodeDescription,
//                  types: $0.types
//            )
//        }
//    }
//    
//    private static func toCamelCase(_ sentence: String) -> String {
//        let words = sentence.components(separatedBy: " ")
//        let camelCaseString = words.enumerated().map { index, word in
//            index == 0 ? word.lowercased() : word.capitalized
//        }.joined()
//        return camelCaseString
//    }
//}
//
//extension NodeKindDescribable_V0.StitchAINodeKindDescription: Encodable {
//    enum CodingKeys: String, CodingKey {
//        case nodeKind = "node_kind"
//        case description
//        case types
//    }
//    
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(nodeKind, forKey: .nodeKind)
//        try container.encode(description, forKey: .description)
//        
//        if let types = self.types {
//            let typeStrings = types.map(\.asLLMStepNodeType)
//            try container.encode(Array(typeStrings).sorted(), forKey: .types)
//        }
//    }
//}
//
//extension Step_V0.NodeKind {
//    static func getAiNodeDescriptions() -> [NodeKindDescribable_V0.StitchAINodeKindDescription] {
//        // Filter out the scroll interaction node
//        let allDescriptions = Step_V0.Patch.allAiDescriptions + Step_V0.Layer.allAiDescriptions
//        return allDescriptions.filter { description in
//            !description.nodeKind.contains("scrollInteraction")
//        }
//    }
//}
//
//extension Step_V0.Patch: NodeKindDescribable_V0.NodeKindDescribable {
//    var types: Set<Step_V0.NodeType>? {
//        guard let migratedPatch = try? self.convert(to: Patch.self) else {
//            fatalErrorIfDebug("No patch for this type: \(self)")
//            return nil
//        }
//        
//        // Check runtime support
//        let types = self.availableNodeTypes
//        
//        // Downgrade back
//        let downgradedTypes: [CurrentStep.NodeType] = types.compactMap {
//            guard let convertedType = try? $0.convert(to: CurrentStep.NodeType.self) else {
//                log("No support at this version for type for: \(self)")
//                return nil
//            }
//            
//            return convertedType
//        }
//        
//        guard !downgradedTypes.isEmpty else {
//            return nil
//        }
//        
//        return Set(downgradedTypes)
//    }
//    
//}
//
//extension Step_V0.Layer: NodeKindDescribable_V0.NodeKindDescribable {
//    // layers don't do node types
//    var types: Set<Step_V0.NodeType>? { nil }
//}
