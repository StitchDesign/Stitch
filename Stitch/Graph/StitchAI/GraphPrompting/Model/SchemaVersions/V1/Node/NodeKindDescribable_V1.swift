//
//  NodeKindDescribable_V1.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/25.
//

enum NodeKindDescribable_V1 {
    protocol NodeKindDescribable: CaseIterable {
        func defaultDisplayTitle() -> String
        
        var aiNodeDescription: String { get }
        
        var types: Set<CurrentStep.NodeType>? { get }
        
        static var titleDisplay: String { get }
    }
}

extension Step_V1.PatchOrLayer {
    // Note: Swift `init?` is tricky for returning nil vs initializing self; we have to both initialize self *and* return, else we continue past if/else branches etc.;
    // let's prefer functions with clearer return values
    static func fromLLMNodeName(_ nodeName: String) throws -> Self {
        // E.G. from "squareRoot || Patch", grab just the camelCase "squareRoot"
        if let nodeKindName = nodeName.components(separatedBy: "||").first?.trimmingCharacters(in: .whitespaces) {
            
            // Tricky: can't use `Patch(rawValue:)` constructor since newer patches use a non-camelCase rawValue
            if let patch = Step_V1.Patch.allCases.first(where: {
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
            
            else if let layer = Step_V1.Layer.allCases.first(where: {
                $0.defaultDisplayTitle().toCamelCase() == nodeKindName
            }) {
                return .layer(layer)
            }
        }
        
        throw StitchAIParsingError.nodeNameParsing(nodeName)
    }
}

extension NodeKindDescribable_V1.NodeKindDescribable {
    var aiDisplayTitle: String {
        Self.toCamelCase(self.defaultDisplayTitle()) + " || \(Self.titleDisplay)"
    }

    static var allAiDescriptions: [StitchAINodeKindDescription] {
        Self.allCases.map {
            .init(nodeKind: $0.aiDisplayTitle,
                  description: $0.aiNodeDescription,
                  types: $0.types
            )
        }
    }
    
    private static func toCamelCase(_ sentence: String) -> String {
        let words = sentence.components(separatedBy: " ")
        let camelCaseString = words.enumerated().map { index, word in
            index == 0 ? word.lowercased() : word.capitalized
        }.joined()
        return camelCaseString
    }
}

extension Step_V1.Patch: NodeKindDescribable_V1.NodeKindDescribable {
    var types: Set<CurrentStep.NodeType>? {
        guard let migratedPatch = try? self.convert(to: Patch.self) else {
            fatalErrorIfDebug("No patch for this type: \(self)")
            return nil
        }
        
        // Check runtime support
        let types = migratedPatch.availableNodeTypes
        
        // Downgrade back
        let downgradedTypes: [CurrentStep.NodeType] = types.compactMap {
            guard let convertedType = try? $0.convert(to: CurrentStep.NodeType.self) else {
                log("No support at this version for type for: \(self)")
                return nil
            }
            
            return convertedType
        }
        
        guard !downgradedTypes.isEmpty else {
            return nil
        }
        
        return Set(downgradedTypes)
    }
}
extension Step_V1.Layer: NodeKindDescribable_V1.NodeKindDescribable {
    // layers don't do node types
    var types: Set<CurrentStep.NodeType>? { nil }
}

extension Step_V1.PatchOrLayer {
    var asLLMStepNodeName: String {
        switch self {
        case .patch(let x):
            // e.g. Patch.squareRoot -> "Square Root" -> "squareRoot || Patch"
            return x.aiDisplayTitle
        case .layer(let x):
            return x.aiDisplayTitle
        }
    }
}
