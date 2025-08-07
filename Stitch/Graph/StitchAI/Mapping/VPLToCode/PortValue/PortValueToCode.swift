//
//  PortValueToCode.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/7/25.
//

import SwiftUI

extension Array where Element == NodeConnectionType {
    func createSwiftUICodeArgs(varIdNameMap: [UUID: String],
                               isLayer: Bool) throws -> [String] {
        try self.map { inputData in
            try inputData.createSwiftUICodeArg(varIdNameMap: varIdNameMap,
                                               isLayer: isLayer)
        }
    }
    
    func createSwiftUICodeArgs(patchNodeEntityMap: [UUID: PatchNodeEntity]) throws -> [String] {
        try self.map { inputData in
            try inputData.createSwiftUICodeArg(patchNodeEntityMap: patchNodeEntityMap)
        }
    }
}

extension NodeConnectionType {
    /// Called for patches, used for creating SwiftUI code from a Stitch graph.
    func createSwiftUICodeArg(patchNodeEntityMap: [UUID: PatchNodeEntity]) throws -> String {
        switch self {
        case .values(let values):
            return try values.createSwiftUICodeArg()
            
        case .upstreamConnection(let upstream):
            guard let upstreamPatchNode = patchNodeEntityMap.get(upstream.nodeId),
                  let portIndex = upstream.portId else {
                throw SwiftUISyntaxError.upstreamVarNameNotFound(upstream)
            }
            
            let upstreamVarName = upstreamPatchNode.patch.rawValue.createUniqueVarName(nodeId: upstream.nodeId)
            
            // Port indices used just for patches
            return "\(upstreamVarName)[\(portIndex)]"
        }
    }
    
    func createSwiftUICodeArg(varIdNameMap: [UUID: String],
                              isLayer: Bool) throws -> String {
        switch self {
        case .values(let values):
            return try values.createSwiftUICodeArg()
            
        case .upstreamConnection(let upstream):
            // Variable name should already exist given topological order, otherwise its a cycle case which we should ignore
            guard let upstreamVarName = varIdNameMap.get(upstream.nodeId),
                  let portIndex = upstream.portId else {
                throw SwiftUISyntaxError.upstreamVarNameNotFound(upstream)
            }
            
            // Port indices used just for patches
            if isLayer {
                return "\(upstreamVarName)[\(portIndex)]"
            }
            
            return upstreamVarName
        }
    }
}

extension Array where Element == PortValue {
    func createSwiftUICodeArg() throws -> String {
        guard let firstValue = self.first else {
            fatalError()
        }
        
        let valueDesc = PrintablePortValueDescription(firstValue)
        let string = try valueDesc.jsonWithoutQuotedKeys()
        
        // gets rid of brackets
        let trimmedStr = string.dropFirst().dropLast()
        return "[PortValueDescription(\(trimmedStr))]"
    }
}

extension LayerInputEntity {
    func getSwiftUICodeForValues(varIdNameMap: [UUID: String]) throws -> String {
        let portValueArgsString: String
        
        // Check packed/unpacked mode
        switch self.mode {
        case .packed:
            let packedData = self.packedData.inputPort
            portValueArgsString = try packedData.createSwiftUICodeArg(varIdNameMap: varIdNameMap,
                                                                      isLayer: true)
            
        case .unpacked:
            let unpackedData = self.unpackedData
            let portValueArgs = try unpackedData.map {
                try $0.inputPort.createSwiftUICodeArg(varIdNameMap: varIdNameMap,
                                                      isLayer: true)
            }
            portValueArgsString = portValueArgs.joined(separator: ", ")
        }

        return portValueArgsString
    }
}

/// Renders an argument as PortValueDescription format
func renderArgAsPortValueDescription(_ arg: SyntaxViewModifierArgumentType, valueType: String) -> String {
    let value = extractValueForPortValueDescription(arg)
    return "PortValueDescription(value: \(value), value_type: \"\(valueType)\")"
}

/// Extracts the raw value from a SyntaxViewModifierArgumentType for PortValueDescription
func extractValueForPortValueDescription(_ arg: SyntaxViewModifierArgumentType) -> String {
    switch arg {
    case .simple(let data):
        // For simple values, use the raw value with appropriate quoting
        switch data.syntaxKind.literalData {
        case .string:
            // Check if this is a hex color string and preserve it
            if data.value.starts(with: "#") && (data.value.count == 7 || data.value.count == 9) {
                // This is likely a hex color string (#RRGGBB or #RRGGBBAA)
                return "\"\(data.value)\""
            }
            return "\"\(data.value)\""
        case .float, .integer:
            return data.value
        default:
            // For other cases, treat as string
            return "\"\(data.value)\""
        }
    case .memberAccess(let m):
        // Handle member access like .green, .blue etc.
        if let base = m.base, base == "Color" {
            // Convert Color.green to hex format
            return "\"#\(colorToHex(m.property))\""
        } else if m.base == nil && m.property.count > 0 {
            // Handle direct member access like .green
            return "\"#\(colorToHex(m.property))\""
        }
        return "\".\(m.property)\""
    case .complex(let c):
        switch SyntaxValueName(rawValue: c.typeName) {
        case .color:
            // Check if this is a hex color (single string argument)
            if c.arguments.count == 1,
               let firstArg = c.arguments.first,
               firstArg.label == nil,
               case .simple(let simpleData) = firstArg.value,
               simpleData.syntaxKind.literalData == .string,
               simpleData.value.starts(with: "#") {
                // Return the hex string directly for PortValueDescription
                return "\"\(simpleData.value)\""
            }
            
        case .portValueDescription:
            guard let firstArg = c.arguments.first else {
                fatalErrorIfDebug()
                return ""
            }
            
            return renderArgWithoutPortValueDescription(firstArg.value)
            
        default:
            break
        }
        
        if c.typeName == "CGSize" {
            // Extract width and height for size type
            let dict = (try? c.arguments.createValuesDict()) ?? [:]
            return "{\(dict.map { "\"\($0.key)\": \"\($0.value)\"" }.joined(separator: ", "))}"
        }
        return "\"\(c.typeName)(...)\""
        
    case .array(let elements):
        // Arrays should be wrapped as individual PortValueDescriptions
        let renderedElements = elements.map { extractValueForPortValueDescription($0) }
        return "[\(renderedElements.joined(separator: ", "))]"
    case .tuple(let fields):
        // Tuples become dictionary-like structures
        let dict = fields.compactMap { field -> String? in
            guard let label = field.label else { return nil }
            let value = extractValueForPortValueDescription(field.value)
            return "\"\(label)\": \(value)"
        }.joined(separator: ", ")
        return "{\(dict)}"
    case .stateAccess(_):
        // State access should not use PortValueDescription according to system prompt
        return "/* state access - should not be wrapped */"
    }
}

func renderArg(_ arg: SyntaxViewModifierArgumentType, usePortValueDescription: Bool = true, valueType: String = "") -> String {
    // Check for special cases that should never use PortValueDescription
    if case .stateAccess(_) = arg {
        // State variables should never be wrapped according to system prompt
        return renderArgWithoutPortValueDescription(arg)
    }
    
    if usePortValueDescription && !valueType.isEmpty {
        // Always wrap PortValueDescription in arrays for consistency
        return "[\(renderArgAsPortValueDescription(arg, valueType: valueType))]"
    }
    
    return renderArgWithoutPortValueDescription(arg)
}

func renderArgWithoutPortValueDescription(_ arg: SyntaxViewModifierArgumentType) -> String {
    switch arg {
    case .simple(let data):
        return renderSimple(data)
    case .memberAccess(let m):
        return m.base.map { "\($0).\(m.property)" } ?? ".\(m.property)"
    case .array(let elements):
        return "[" + elements.map(renderArgWithoutPortValueDescription).joined(separator: ", ") + "]"
    case .tuple(let fields):
        let inner = fields.map { f in
            let label = f.label ?? "_"
            return "\(label): \(renderArgWithoutPortValueDescription(f.value))"
        }.joined(separator: ", ")
        return "(\(inner))"
    case .complex(let c):
        switch SyntaxValueName(rawValue: c.typeName) {
        case .color:
            // Special handling for Color types
            // Check if this is a hex color (single string argument)
            if c.arguments.count == 1,
               let firstArg = c.arguments.first,
               firstArg.label == nil,
               case .simple(let simpleData) = firstArg.value,
               simpleData.syntaxKind.literalData == .string,
               simpleData.value.starts(with: "#") {
                // Convert hex string to RGBA Color format
                if let color = ColorConversionUtils.hexToColor(simpleData.value) {
                    let rgba = color.asRGBA
                    return "Color(red: \(rgba.red), green: \(rgba.green), blue: \(rgba.blue), opacity: \(rgba.alpha))"
                }
            }
            
        case .portValueDescription:
            guard let firstArg = c.arguments.first else {
                fatalErrorIfDebug()
                return ""
            }
            
            return renderArgWithoutPortValueDescription(firstArg.value)
            
        default:
            break
        }
        
        // Handle angle functions (.degrees, .radians)
        if c.typeName == "" && c.arguments.count == 1,
           let firstArg = c.arguments.first,
           let label = firstArg.label,
           (label == "degrees" || label == "radians") {
            let valueString = renderArgWithoutPortValueDescription(firstArg.value)
            return ".\(label)(\(valueString))"
        }
        
        // Best-effort for other complex types
        let inner = (try? c.arguments.createValuesDict()).map { dict in
            dict.map { "\($0.key): \(renderAnyEncodable($0.value))" }
                .sorted().joined(separator: ", ")
        } ?? ""
        return "\(c.typeName)(\(inner))"
    case .stateAccess(let stateName):
        // Render state variables directly by name
        return stateName
    }
}

func renderSimple(_ s: SyntaxViewSimpleData) -> String {
    switch s.syntaxKind.literalData {
    case .string:
        return "\"\(s.value)\""
    case .float:
        return s.value
    case .boolean:
        return s.value.lowercased()
    default:
        return s.value
    }
}

func named(_ label: String, _ arg: SyntaxViewModifierArgumentType?) -> String? {
    guard let a = arg else { return nil }
    return "\(label): \(renderArg(a))"
}

func renderAnyEncodable(_ any: AnyEncodable) -> String {
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(any), let s = String(data: data, encoding: .utf8) {
        return s
    }
    return "_"
}
