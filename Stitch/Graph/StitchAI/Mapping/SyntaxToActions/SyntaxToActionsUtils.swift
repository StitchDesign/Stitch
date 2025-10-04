//
//  SyntaxToActionsUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import StitchSchemaKit
import CryptoKit


// TODO: remove, replace with `PortIOType` or something like that; but basic logic remains the same
enum StitchValueOrEdge: Equatable {
    // a manually-set, always-scalar value
    case value(CurrentStep.PortValue)
    
    // an incoming edge
    case edge(NodeId, Int) // `from node id + from port`
    
    func asSwiftUILiteralOrVariable() throws -> String {
        switch self {
        case .value(let x):
            return try x.asSwiftUILiteral()
        case .edge(let x, let y):
            // TODO: JUNE 24: probably will use edge.origin's NodeId and Int to ... what? look up a proper variable name? ... Can see how Elliot does it?
            return "from x to y"
        }
    }
    
    var asSwiftSyntaxKind: SyntaxArgumentKind {
        switch self {
        
        case .value(let x):
            return x.asSwiftSyntaxKind
            
        case .edge(let x, let y):
            // TODO: JUNE 24: do we always want to treat an incoming edge as a variable ? ... a variable is just an evaluated expression ?
            return SyntaxArgumentKind.variable(.identifier) // `x`
        }
    }
    
    var getValue: CurrentStep.PortValue? {
        switch self {
        case .value(let x): return x
        default: return nil
        }
    }
    
    var getIncomingEdge: (NodeId, Int)? {
        switch self {
        case .edge(let x, let y): return (x, y)
        default: return nil
        }
    }
}

extension CurrentStep.PortValue {
    
    // TODO: JUNE 24: should return a Codable ? ... How do you map between Swift/SwiftUI types and Stitch's PortValue types ? ... see note in `LayerInputPort.toSwiftUI`
    func asSwiftUILiteral() throws -> String {
        let migratedValue = try self.migrate()
        
        // TODO: JUNE 25: where did our `PortValue.usesMultipleFields` method go? ... Could use a check
        let isMultifield = migratedValue.createFieldValuesList(
            nodeIO: .input,
            layerInputPort: nil,
            isLayerInspector: false).count > 1
        
        if isMultifield {
            return "IMPLEMENT ME: \(migratedValue.display)"
        } else {
            return migratedValue.display
        }
    }
    
    var asSwiftSyntaxKind: SyntaxArgumentKind {
        // TODO: JUNE 24: Do you need all these different individual syntax-literal types? ... if so, then should map on
        .literal(.string)
    }
}

func deterministicUUID(from name: String) -> UUID {
    let data = Data(name.precomposedStringWithCanonicalMapping.utf8)
    let digest = SHA256.hash(data: data)
    var bytes = Data(digest.prefix(16))
    // Mark as "random" style with RFC variant (helps tooling)
    bytes[6] = (bytes[6] & 0x0F) | 0x40  // pretend version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80
    return bytes.withUnsafeBytes { buf in
        let b = buf.bindMemory(to: UInt8.self)
        return UUID(uuid: (b[0],b[1],b[2],b[3], b[4],b[5], b[6],b[7], b[8],b[9], b[10],b[11],b[12],b[13],b[14],b[15]))
    }
}

extension NodeType {
    func reorganizePortValueArgs(valuesMap: [(String, [PatchSyntaxResultType])]) -> [PatchSyntaxResultType] {
        let defaultOrder = valuesMap.flatMap { $0.1 }
        
        // Ignore if any keys are empty
        guard !valuesMap.getKeys().contains("") else { return defaultOrder }
        
        switch self {
        case .position:
            guard let xValue = valuesMap.get("x"),
                  let yValue = valuesMap.get("y") else {
                break
            }
            
            return xValue + yValue
            
        case .size:
            guard let widthValue = valuesMap.get("width"),
                  let heightValue = valuesMap.get("height") else {
                break
            }
            
            return widthValue + heightValue
            
        case .padding:
            guard let top = valuesMap.get("top"),
                  let right = valuesMap.get("right"),
                  let bottom = valuesMap.get("bottom"),
                  let left = valuesMap.get("left") else {
                break
            }
             
            return top + right + bottom + left
            
        default:
            fatalError("Please fill in types we aren't supporting here!")
            break
        }
        
        // Backup just returns list in order
        return defaultOrder
    }
}

extension Array where Element == SyntaxViewArgumentData {
    func reorderUnpackedValues(varName: String?,
                               viewEvent: SyntaxViewEvent?,
                               nodesDict: [UUID: NodeEntity],
                               nodeType: NodeType? = nil,
                               isStreaming: Bool) throws -> [PatchSyntaxResultType] {
        // Recursively determine PortValue of each arg for key label
        let orderedDict = [(String, [PatchSyntaxResultType])]()
        let portValuesMap = try self.reduce(into: orderedDict) { result, arg in
            let results = try SyntaxViewName.derivePortValues(
                from: arg.value,
                varName: varName,
                viewEvent: viewEvent,
                nodesDict: nodesDict,
                nodeType: nodeType,
                isStreaming: isStreaming)
            
            result.append(((arg.label?.stripQuotes() ?? ""), results))
        }
        
        guard let nodeType = nodeType else {
            return portValuesMap.flatMap { $0.1 }
        }
        
        // Regoranize arguments to ensure packing works correctly
        return nodeType.reorganizePortValueArgs(valuesMap: portValuesMap)
    }
}
