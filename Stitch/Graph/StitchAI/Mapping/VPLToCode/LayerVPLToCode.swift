//
//  VPLToCode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/28/25.
//

import SwiftUI
import StitchSchemaKit
import SwiftSyntax
import SwiftParser

// MARK: - LayerData → StrictSyntaxView Conversion
extension LayerNodeEntity {
    /// Produces a `ViewConstructor` for a single `LayerData` node.
    /// Only constructor-surface arguments are considered; **no view modifiers**.
    @MainActor
    func createSwiftUIViewBuilderCode(children: [LayerNodeEntity],
                                      layerEntityMap: [UUID: LayerNodeEntity],
                                      varIdNameMap: [UUID: String]) throws -> String? {
        switch self.layer {
            
            // ───────── Shapes (no-arg) ─────────
        case .oval:
            return SyntaxViewName.ellipse.createConstructorCode()
            
        case .rectangle:
            return SyntaxViewName.rectangle.createConstructorCode()
            
            // ───────── Text ─────────
        case .text:
            let args = try self.textPort
                .getSwiftUICodeForValues(varIdNameMap: varIdNameMap)
            return SyntaxViewName.text.createConstructorCode(args)
            
            // ───────── Group → H/V/Z stack or ScrollView ─────────
        case .group:
            return try self
                .createNestedGroupSwiftUICode(children: children,
                                              layerEntityMap: layerEntityMap,
                                              varIdNameMap: varIdNameMap)
            
            
            // ───────── Reality primitives (no-arg) ─────────
        case .realityView:
            return SyntaxViewName.stitchRealityView.createConstructorCode()
        case .box:
            return SyntaxViewName.box.createConstructorCode()
        case .cone:
            return SyntaxViewName.cone.createConstructorCode()
        case .cylinder:
            return SyntaxViewName.cylinder.createConstructorCode()
        case .sphere:
            return SyntaxViewName.sphere.createConstructorCode()
            
            // ───────── SF Symbol / Image ─────────
        case .sfSymbol:
            if let symbolName = self.sfSymbolPort.packedData.inputPort.values?.first?.sfSymbol,
               symbolName != "" {
                let args = try self.sfSymbolPort
                    .getSwiftUICodeForValues(varIdNameMap: varIdNameMap)
                return SyntaxViewName.image.createConstructorCode(args)
            }
            return nil
            
            // ───────── Not yet handled ─────────
        case .linearGradient, .radialGradient, .angularGradient,
                .textField:
            return nil
            
        default:
            log("makeConstructFromLayerData: COULD NOT TURN LAYER \(self.layer) INTO A ViewConstructor")
            return nil
        }
    }
    
    @MainActor
    func createNestedGroupSwiftUICode(children: [LayerNodeEntity],
                                      layerEntityMap: [UUID: LayerNodeEntity],
                                      varIdNameMap: [UUID: String]) throws -> String? {
        assertInDebug(self.layer == .group)
        
        let childrenContents = try children
            .createSwiftUICode(layerEntityMap: layerEntityMap,
                               varIdNameMap: varIdNameMap)
        
        // Check if scroll is enabled
        let scrollXEnabled = self.scrollXEnabledPort.packedData.inputPort.values?.first?.getBool ?? false
        let scrollYEnabled = self.scrollYEnabledPort.packedData.inputPort.values?.first?.getBool ?? false
        let hasScrolling = scrollXEnabled || scrollYEnabled
        
        if hasScrolling {
            // Generate ScrollView with appropriate axes
            let axesArg: String
            if scrollXEnabled && scrollYEnabled {
                // Both axes enabled → ScrollView([.horizontal, .vertical])
                axesArg = "axes: [.horizontal, .vertical], "

            } else if scrollXEnabled {
                // Only horizontal → ScrollView(.horizontal)
                axesArg = "axes: [.horizontal], "
            } else {
                // Only vertical (default) → ScrollView() - no axes parameter needed as vertical is default
                axesArg = ""
            }
            
            return """
                ScrollView(\(axesArg)showsIndicators: nil) {
                    \(childrenContents)
                }
                """
                
        } else {
            let orient = self.orientationPort.packedData.inputPort.values?.first?.getOrientation ?? .none
            let spacingArgs = try self.spacingPort.getSwiftUICodeForValues(varIdNameMap: varIdNameMap)
            
            let anchoring = self.layerGroupAlignmentPort.packedData.inputPort.values?.first?.getAnchoring ?? .defaultAnchoring
            
            // No scrolling → regular stack based on orientation
            // Extract alignment from layerGroupAlignment for regular stacks too
            let stackAlignmentArg = createAlignmentArg(anchoring: anchoring,
                                                       orientation: orient)
            
            switch orient {
            case .horizontal:
                return """
                    HStack(alignment: .\(stackAlignmentArg), spacing: \(spacingArgs)) {
                        \(childrenContents)
                    }
                    """

            case .vertical:
                return """
                    VStack(alignment: .\(stackAlignmentArg), spacing: \(spacingArgs)) {
                        \(childrenContents)
                    }
                    """
            case .none:
                return """
                    ZStack(alignment: .\(stackAlignmentArg)) {
                        \(childrenContents)
                    }
                    """
            case .grid:
                // TODO: .grid orientation becomes SwiftUI LazyVGrid
                return nil
            }
        }
    }
        
    /// Converts layer data from graph to SwiftUI code
    @MainActor
    func createSwiftUICode(layerEntityMap: [UUID: LayerNodeEntity],
                           varIdNameMap: [UUID: String]) throws -> String? {
        // TODO: handle nesting edge case here
        let childrenLayerEntities = layerEntityMap.values.filter {
            $0.layerGroupId == self.id
        }
        
        if self.layer == .group {
            let groupSwiftUICode = try self
                .createNestedGroupSwiftUICode(children: childrenLayerEntities,
                                              layerEntityMap: layerEntityMap,
                                              varIdNameMap: varIdNameMap)
            
            return groupSwiftUICode
        }
        
        // Create the constructor
        guard let constructor = try self
            .createSwiftUIViewBuilderCode(children: childrenLayerEntities,
                                          layerEntityMap: layerEntityMap,
                                          varIdNameMap: varIdNameMap) else {
            return nil
        }
        
        // Create modifiers from custom_layer_input_values
        let modifiersString = try self.getSwiftUIViewModifierStrings(varIdNameMap: varIdNameMap)
        
        var swiftUICode = """
            \(constructor)
                .layerId(\(self.id))
                \(modifiersString.joined(separator: "\n\t\t"))
            """
        
        if !childrenLayerEntities.isEmpty {
            // Convert children recursively
            let swiftUICodeForChildren = try childrenLayerEntities.compactMap {
                try $0.createSwiftUICode(layerEntityMap: layerEntityMap,
                                         varIdNameMap: varIdNameMap)
            }
            
            swiftUICode += "\n\(swiftUICodeForChildren)"
        }
        
        return swiftUICode
    }
}

extension Array where Element == LayerNodeEntity {
    @MainActor
    func createSwiftUICode(layerEntityMap: [UUID: LayerNodeEntity],
                           varIdNameMap: [UUID: String]) throws -> String {
        let strings = try self.compactMap {
            try $0.createSwiftUICode(layerEntityMap: layerEntityMap,
                                     varIdNameMap: varIdNameMap)
        }
        
        return strings.joined(separator: "\n")
    }
}

/// Creates alignment argument from LayerData inputs based on stack orientation
func createAlignmentArg(anchoring: Anchoring,
                        orientation: StitchOrientation) -> String {
    
    // Convert Stitch Anchoring to SwiftUI alignment based on stack orientation
    
    switch orientation {
    case .horizontal:
        // HStack uses VerticalAlignment
        switch anchoring {
        case .topCenter, .topLeft, .topRight:
            return "top"
        case .centerCenter, .centerLeft, .centerRight:
            return "center"
        case .bottomCenter, .bottomLeft, .bottomRight:
            return "bottom"
            
        // Note: technically, Stitch Anchoring is a (0,0), which is many more values than SwiftUI Alignment
        default:
            return "center"
        }
        
    case .vertical:
        // VStack uses HorizontalAlignment
        switch anchoring {
        case .centerLeft, .topLeft, .bottomLeft:
            return "leading"
        case .centerCenter, .topCenter, .bottomCenter:
            return "center"
        case .centerRight, .topRight, .bottomRight:
            return "trailing"
        default:
            return "center"
        }
        
    case .none:
        // ZStack uses Alignment (both horizontal and vertical)
        switch anchoring {
        case .topLeft:
            return "topLeading"
        case .topCenter:
            return "top"
        case .topRight:
            return "topTrailing"
        case .centerLeft:
            return "leading"
        case .centerCenter:
            return "center"
        case .centerRight:
            return "trailing"
        case .bottomLeft:
            return "bottomLeading"
        case .bottomCenter:
            return "bottom"
        case .bottomRight:
            return "bottomTrailing"
        default:
            return "center"
        }
        
    case .grid:
        // Grid uses HorizontalAlignment like VStack
        switch anchoring {
        case .centerLeft, .topLeft, .bottomLeft:
            return "leading"
        case .centerCenter, .topCenter, .bottomCenter:
            return "center"
        case .centerRight, .topRight, .bottomRight:
            return "trailing"
        default:
            return "center"
        }
    }
}

extension LayerNodeEntity {
    /// Creates StrictViewModifier array from LayerData custom input values
    @MainActor
    func getSwiftUIViewModifierStrings(varIdNameMap: [UUID: String]) throws -> [String] {
        let ports = self.layer.inputDefinitions
        
        return try ports.compactMap { port -> String? in
            guard let viewModifier = port.viewModifierString(from: self.layer) else {
                log("getSwiftUIViewModifierStrings: no view modifier for \(port) in \(self.layer)")
                return nil
            }
            let inputData = self[keyPath: port.schemaPortKeyPath]

            let defaultData = port.getDefaultValueForAI(for: self.layer)
            let firstValue = inputData.packedData.inputPort.values?.first
            
            guard defaultData != firstValue else {
                // Skip if default data is equal--no view modifier needed in this event
                return nil
            }
            
            let portValueArgs = try inputData.getSwiftUICodeForValues(varIdNameMap: varIdNameMap)
            return ".\(viewModifier.rawValue)(\(portValueArgs))"
        }
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
// MARK: - Argument rendering helpers

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

/// Converts color names to hex values for PortValueDescription
func colorToHex(_ colorName: String) -> String {
    switch colorName.lowercased() {
    case "red":
        return "FF0000FF"
    case "green":
        return "00FF00FF"
    case "blue":
        return "0000FFFF"
    case "white":
        return "FFFFFFFF"
    case "black":
        return "000000FF"
    case "yellow":
        return "FFFF00FF"
    case "orange":
        return "FFA500FF"
    case "purple":
        return "800080FF"
    case "pink":
        return "FFC0CBFF"
    case "gray", "grey":
        return "808080FF"
    case "clear":
        return "00000000"
    default:
        return "808080FF" // Default to gray
    }
}

/// Maps a view modifier context to the appropriate PortValueDescription value_type
func getPortValueDescriptionType(for modifierName: String, argumentIndex: Int = 0) -> String {
    switch modifierName {
    case "fill", "foregroundColor":
        return "color"
    case "frame":
        return "size"
    case "opacity", "brightness", "contrast", "saturation", "scaleEffect", "zIndex":
        return "number"
    case "cornerRadius", "blur":
        return "number"
    case "position", "offset":
        return "position"
    case "padding":
        return "padding"
    case "font":
        return "textFont"
    case "fontWeight":
        return "textFont" 
    case "fontDesign":
        return "textFont"
    case "layerId":
        return "string"
    default:
        // Default fallback
        return "string"
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

// MARK: - ViewModifierConstructor (intermediate) mapping & rendering

/// Creates a typed view-modifier constructor from a layer input value, when supported.
extension LayerInputPort {
    func viewModifierString(from layer: Layer) -> SyntaxViewModifierName? {
        switch self {
        case .opacity:
            return .opacity
        case .scale:
            return .scaleEffect
        case .blur, .blurRadius:
            return .blur
        case .zIndex:
            return .zIndex
        case .cornerRadius:
            return .cornerRadius
        case .size:
            return .frame
        case .color:
            // Choose modifier based on layer type
            switch layer {
            case .rectangle, .oval, .shape:
                // Shape layers use .fill()
                return .fill
            default:
                // Default to .foregroundColor() for other layer types
                return .foregroundColor
            }
        case .brightness:
            return .brightness
        case .contrast:
            return .contrast
        case .saturation:
            return .saturation
        case .hueRotation:
//            let arg = SyntaxViewModifierArgumentType.complex(
//                SyntaxViewModifierComplexType(
//                    typeName: "",
//                    arguments: [
//                        .init(label: "degrees", value: .simple(SyntaxViewSimpleData(value: String(number), syntaxKind: .literal(.float))))
//                    ]
//                )
//            )
            return .hueRotation
        case .colorInvert:
            return .colorInvert
        case .position:
            return .position
        case .offsetInGroup:
            return .offset
        case .padding:
            return .padding
        case .isClipped:
            return .clipped
        case .textFont:
//            return decomposeFontToModifiers(stitchFont)
            return .font
            
        case .fontSize:
            // FontSize should not create a separate font modifier when textFont exists
            // The textFont case handles both font family/weight and size together
            return nil
        case .rotationX:
            // For now, treat rotationX as unsupported
            return nil
        case .rotationY:
            // For now, treat rotationY as unsupported
            return nil
        case .rotationZ:
//            let arg = SyntaxViewModifierArgumentType.complex(
//                SyntaxViewModifierComplexType(
//                    typeName: "",
//                    arguments: [
//                        .init(label: "degrees", value: .simple(SyntaxViewSimpleData(value: String(number), syntaxKind: .literal(.float))))
//                    ]
//                )
//            )
            return .rotationEffect

        default:
            return nil
        }
    }
}

/// Decomposes a StitchFont into the best SwiftUI modifier representation
/// Uses Approach 3 (Hybrid): intelligent decomposition for better SwiftUI code
///
/// Precedence Rules:
/// 1. .font() takes precedence when we can map to standard SwiftUI system fonts
/// 2. Fallback to .system(size:, weight:, design:) for complex combinations
/// 3. Individual .fontDesign() and .fontWeight() modifiers are handled separately during parsing
func decomposeFontToModifiers(_ stitchFont: StitchFont) -> StrictViewModifier? {
    // Strategy: Create the most appropriate SwiftUI font modifier based on the StitchFont
    // We'll prioritize .font() for system fonts with common sizes
    
    let fontChoice = stitchFont.fontChoice
    let fontWeight = stitchFont.fontWeight
    
    // Try to map to a standard SwiftUI system font first
    if let systemFont = mapStitchFontToSwiftUISystemFont(fontChoice, fontWeight) {
        let fontArg = SyntaxViewModifierArgumentType.memberAccess(
            SyntaxViewMemberAccess(base: nil, property: String(systemFont.dropFirst())) // Remove leading dot
        )
        return .font(FontViewModifier(font: fontArg))
    }
    
    // Fallback: Create .fontDesign() and .fontWeight() modifiers separately
    // This provides more granular control and is more idiomatic for complex fonts
    
    // For now, create a composite font modifier
    // Future enhancement: return multiple modifiers
    let designString = mapStitchFontChoiceToSwiftUIDesign(fontChoice)
    let weightString = mapStitchFontWeightToSwiftUIWeight(fontWeight)
    
    // Create a combined font specification directly as syntax
    let combinedFont = ".system(size: 17, weight: \(weightString), design: \(designString))"
    let fontArg = SyntaxViewModifierArgumentType.simple(
        SyntaxViewSimpleData(value: combinedFont, syntaxKind: .literal(.memberAccess))
    )
    
    return .font(FontViewModifier(font: fontArg))
}

// MARK: - StitchFont to SwiftUI Mapping Functions

func mapStitchFontToSwiftUISystemFont(_ fontChoice: StitchFontChoice, _ fontWeight: StitchFontWeight) -> String? {
    // Map common combinations to standard SwiftUI system fonts
    switch (fontChoice, fontWeight) {
    case (.sf, .SF_regular):
        return ".body"
    case (.sf, .SF_bold):
        return ".headline"  // headline is bold by default
    case (.sf, .SF_light):
        return ".subheadline"
    default:
        return nil  // Use fallback approach
    }
}

func mapStitchFontChoiceToSwiftUIDesign(_ fontChoice: StitchFontChoice) -> String {
    switch fontChoice {
    case .sf:
        return ".default"
    case .sfMono:
        return ".monospaced"
    case .sfRounded:
        return ".rounded"
    case .newYorkSerif:
        return ".serif"
    }
}

func mapStitchFontWeightToSwiftUIWeight(_ weight: StitchFontWeight) -> String {
    // Extract the actual weight from the prefixed enum case
    let weightString = String(describing: weight)
    if let underscoreIndex = weightString.lastIndex(of: "_") {
        let actualWeight = String(weightString[weightString.index(after: underscoreIndex)...])
        return ".\(actualWeight)"
    }
    return ".regular"  // fallback
}
