//
//  PatchOrLayer.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/25.
//

import Foundation

// i.e. NodeKind, excluding Group Nodes and Components
enum PatchOrLayer: Equatable, Codable, Hashable {
    case patch(Patch), layer(Layer)
    
    var asNodeKind: NodeKind {
        switch self {
        case .patch(let patch):
            return .patch(patch)
        case .layer(let layer):
            return .layer(layer)
        }
    }
    
    static func from(nodeKind: NodeKind) -> Self? {
        switch nodeKind {
        case .patch(let x):
            return .patch(x)
        case .layer(let x):
            return .layer(x)
        case .group:
            fatalErrorIfDebug()
            return nil
        }
    }
}

extension PatchOrLayer {
    // Note: Swift `init?` is tricky for returning nil vs initializing self; we have to both initialize self *and* return, else we continue past if/else branches etc.;
    // let's prefer functions with clearer return values
    static func fromLLMNodeName(_ nodeName: String) throws -> Self {
        // E.G. from "squareRoot || Patch", grab just the camelCase "squareRoot"
        if let nodeKindName = nodeName.components(separatedBy: "||").first?.trimmingCharacters(in: .whitespaces) {
                        
            // Tricky: can't use `Patch(rawValue:)` constructor since newer patches use a non-camelCase rawValue
            if let patch = Patch.allCases.first(where: {
                // e.g. Patch.squareRoot -> "Square Root" -> "squareRoot"
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
            
            else if let layer = Layer.allCases.first(where: {
                $0.defaultDisplayTitle().toCamelCase() == nodeKindName
            }) {
                return .layer(layer)
            }
        }
        
        throw StitchAIManagerError.nodeNameParsing(nodeName)
    }
}
