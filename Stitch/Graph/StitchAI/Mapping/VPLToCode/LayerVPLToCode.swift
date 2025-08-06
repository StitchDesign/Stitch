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


// MARK: - VPL → SwiftUI Constructor (LayerData-only)
// NOTE: This file intentionally avoids any ViewModifier handling for now.

/// Reads explicit values from `LayerData.custom_layer_input_values` and, when
/// missing, falls back to Stitch defaults (for type correctness only).
struct LayerDataConstructorInputs {
    let layer: AIGraphData_V0.Layer
    let explicit: [LayerInputPort : AIGraphData_V0.PortValue]
    
    public init(layerData: AIGraphData_V0.LayerData, idMap: inout [String: UUID]) {
        if case let .layer(kind) = layerData.node_name.value { self.layer = kind }
        else { self.layer = .group }
        
        var explicit: [LayerInputPort : AIGraphData_V0.PortValue] = [:]
        for customInputValue in layerData.custom_layer_input_values {
            let port = customInputValue.coordinate.layerInput
            if let v = decodePortValueFromCIV(customInputValue, idMap: &idMap) { explicit[port] = v }
        }
        self.explicit = explicit
    }
    
    public func value(_ port: LayerInputPort) -> AIGraphData_V0.PortValue {
        explicit[port] ?? port.getDefaultValue(for: layer)
    }
    
    // Typed conveniences (using your existing PortValue helpers)
    public func number(_ p: LayerInputPort) -> Double?               { value(p).getNumber }
    public func bool(_ p: LayerInputPort) -> Bool?                   { value(p).getBool }
    public func string(_ p: LayerInputPort) -> String?               { value(p).getString?.string }
    public func color(_ p: LayerInputPort) -> Color?                 { value(p).getColor }
    public func anchoring(_ p: LayerInputPort) -> Anchoring?         { value(p).getAnchoring }
    public func orientation(_ p: LayerInputPort) -> StitchOrientation? { value(p).getOrientation }
}

/// Decodes a single `CustomLayerInputValue` into a `PortValue` using your
/// existing AI decoding helpers.
func decodePortValueFromCIV(_ customInputValue: LayerPortDerivation,
                            idMap: inout [String: UUID]) -> AIGraphData_V0.PortValue? {
    guard let portValueDescription = customInputValue.inputData.value else {
        return nil
    }
    
    return try? AIGraphData_V0.PortValue.decodeFromAI(
        data: portValueDescription.value,
        valueType: portValueDescription.value_type.value,
        idMap: &idMap
    )
}

/// Produces a `ViewConstructor` for a single `LayerData` node.
/// Only constructor-surface arguments are considered; **no view modifiers**.
func makeConstructorFromLayerData(_ layerData: AIGraphData_V0.LayerData,
                                  idMap: inout [String: UUID]) -> StrictViewConstructor? {
    let inputs = LayerDataConstructorInputs(layerData: layerData, idMap: &idMap)
    
    switch inputs.layer {
        
        // ───────── Shapes (no-arg) ─────────
    case .oval:
        return .ellipse(NoArgViewConstructor(args: [], layer: .oval))
        
    case .rectangle:
        return .rectangle(RectangleViewConstructor())
        
        // ───────── Text ─────────
    case .text:
        if let s = inputs.string(.text) {
            // Represent the simple `Text("…")` case
            let arg: SyntaxViewModifierArgumentType = .simple(
                SyntaxViewSimpleData(value: s, syntaxKind: .literal(.string))
            )
            return .text(.string(arg))
        }
        return nil
        
        // ───────── TextField (placeholder + initial binding preview) ─────────
        //    case .textField:
        //        let title = inputs.string(.placeholderText) ?? ""
        //        let initial = inputs.string(.text) ?? ""
        //        let bindingExpr = ExprSyntax("/* binding */ .constant(\"\(raw: initial)\")")
        //        return .textField(.parameters(title: .literal(title), binding: bindingExpr))
        
        // ───────── Group → H/V/Z stack or ScrollView ─────────
    case .group:
        let orient = inputs.orientation(.orientation) ?? .vertical
        let spacingNum = inputs.number(.spacing)
        let spacingArg: SyntaxViewModifierArgumentType? = spacingNum.map {
            .simple(SyntaxViewSimpleData(value: String($0), syntaxKind: .literal(.float)))
        }
        let alignmentArg: SyntaxViewModifierArgumentType? = nil // keep minimal for now
        
        // Check if scroll is enabled
        let scrollXEnabled = inputs.bool(.scrollXEnabled) ?? false
        let scrollYEnabled = inputs.bool(.scrollYEnabled) ?? false
        let hasScrolling = scrollXEnabled || scrollYEnabled
        
        if hasScrolling {
            // Generate ScrollView with appropriate axes
            let axesArg: SyntaxViewModifierArgumentType?
            if scrollXEnabled && scrollYEnabled {
                // Both axes enabled → ScrollView([.horizontal, .vertical])
                axesArg = .array([
                    // TODO: should we use `base: "Axis.Set"` ?
                    .memberAccess(SyntaxViewMemberAccess(base: nil, property: "horizontal")),
                    .memberAccess(SyntaxViewMemberAccess(base: nil, property: "vertical"))
                ])
            } else if scrollXEnabled {
                // Only horizontal → ScrollView(.horizontal)
                axesArg = .memberAccess(SyntaxViewMemberAccess(base: nil, property: "horizontal"))
            } else {
                // Only vertical (default) → ScrollView() - no axes parameter needed as vertical is default
                axesArg = nil
            }
            
            return .scrollView(.parameters(axes: axesArg, showsIndicators: nil))
        } else {
            // No scrolling → regular stack based on orientation
            // Extract alignment from layerGroupAlignment for regular stacks too
            let stackAlignmentArg = createAlignmentArg(from: inputs, orientation: orient)
            
            switch orient {
            case .horizontal:
                return .hStack(.parameters(alignment: stackAlignmentArg, spacing: spacingArg))
            case .vertical:
                return .vStack(.parameters(alignment: stackAlignmentArg, spacing: spacingArg))
            case .none:
                return .zStack(.parameters(alignment: stackAlignmentArg))
            case .grid:
                // TODO: .grid orientation becomes SwiftUI LazyVGrid
                return nil
            }
        }
        
        // ───────── Reality primitives (no-arg) ─────────
    case .realityView:
        return .stitchRealityView(.plain)
    case .box:
        return .box(.plain)
    case .cone:
        return .cone(.plain)
    case .cylinder:
        return .cylinder(.plain)
    case .sphere:
        return .sphere(.plain)
        
        // ───────── SF Symbol / Image ─────────
    case .sfSymbol:
        if let symbolName = inputs.string(.sfSymbol) {
            let arg: SyntaxViewModifierArgumentType = .simple(
                SyntaxViewSimpleData(value: symbolName, syntaxKind: .literal(.string))
            )
            return .image(.sfSymbol(name: arg))
        }
        return nil
        
        // ───────── Not yet handled ─────────
    case .linearGradient, .radialGradient, .angularGradient,
            .textField:
        return nil
        
    default:
        log("makeConstructFromLayerData: COULD NOT TURN LAYER \(inputs.layer) INTO A ViewConstructor")
        return nil
    }
}

// MARK: - LayerData → StrictSyntaxView Conversion

/// Converts LayerData to StrictSyntaxView with constructor, modifiers, and children
func layerDataToStrictSyntaxView(_ layerData: AIGraphData_V0.LayerData,
                                 idMap: inout [String: UUID]) throws -> StrictSyntaxView? {
    // 1. Create the constructor
    guard let constructor = makeConstructorFromLayerData(layerData, idMap: &idMap) else {
        return nil
    }
    
    // 2. Create modifiers from custom_layer_input_values
    let modifiers = try createStrictViewModifiersFromLayerData(layerData, idMap: &idMap)
    
    // 3. Convert children recursively
    let children = try layerData.children?.compactMap { childLayerData in
        try layerDataToStrictSyntaxView(childLayerData, idMap: &idMap)
    } ?? []

    log("layerDataToStrictSyntaxView: layerData.node_id: \(layerData.node_id)")
    
    // 4. parse the
    guard let parsedNodeId = UUID(uuidString: layerData.node_id) else {
        return nil // TODO: how or when can this really fail?
    }
    
    let nodeId: UUID = parsedNodeId
    
    // Not needed?
    idMap[layerData.node_id] = nodeId
        
    log("layerDataToStrictSyntaxView: nodeId: \(nodeId)")
    
    // 5. Handle ScrollView + Stack nesting for scroll-enabled groups
    if case .scrollView = constructor {
        // Create the inner stack based on the group's orientation
        let innerStackConstructor = createInnerStackConstructor(layerData, idMap: &idMap)
        let innerStackNodeId = UUID()
        // Add LayerIdViewModifier to the inner stack as well
        let innerStackLayerIdModifier = StrictViewModifier.layerId(LayerIdViewModifier(
            layerId: .simple(SyntaxViewSimpleData(value: innerStackNodeId.uuidString, syntaxKind: .literal(.string)))
        ))
        let innerStackView = StrictSyntaxView(
            constructor: innerStackConstructor,
            modifiers: [innerStackLayerIdModifier], // Stack gets layerId modifier
            children: children, // Original children go into the stack
            id: innerStackNodeId
        )
        
        // ScrollView contains the stack as its only child
        // Add LayerIdViewModifier to every StrictSyntaxView
        let layerIdModifier = StrictViewModifier.layerId(
            LayerIdViewModifier(
                layerId: .simple(SyntaxViewSimpleData(value: nodeId.uuidString, syntaxKind: .literal(.string)))
        ))
        let allModifiers = modifiers + [layerIdModifier]
        
        return StrictSyntaxView(
            constructor: constructor,
            modifiers: allModifiers,
            children: [innerStackView], // ScrollView wraps the stack
            id: nodeId
        )
    }
    
    // Add LayerIdViewModifier to every StrictSyntaxView
    let layerIdModifier = StrictViewModifier.layerId(LayerIdViewModifier(
        layerId: .simple(SyntaxViewSimpleData(value: nodeId.uuidString, syntaxKind: .literal(.string)))
    ))
    let allModifiers = modifiers + [layerIdModifier]
    
    return StrictSyntaxView(
        constructor: constructor,
        modifiers: allModifiers,
        children: children,
        id: nodeId
    )
}

/// Creates the inner stack constructor for a ScrollView based on the group's orientation
func createInnerStackConstructor(_ layerData: AIGraphData_V0.LayerData, idMap: inout [String: UUID]) -> StrictViewConstructor {
    let inputs = LayerDataConstructorInputs(layerData: layerData, idMap: &idMap)
    let orient = inputs.orientation(.orientation) ?? .vertical
    let spacingNum = inputs.number(.spacing)
    let spacingArg: SyntaxViewModifierArgumentType? = spacingNum.map {
        .simple(SyntaxViewSimpleData(value: String($0), syntaxKind: .literal(.float)))
    }
    
    // Extract alignment from layerGroupAlignment
    let alignmentArg = createAlignmentArg(from: inputs, orientation: orient)
    
    switch orient {
    case .horizontal:
        return .hStack(.parameters(alignment: alignmentArg, spacing: spacingArg))
    case .vertical:
        return .vStack(.parameters(alignment: alignmentArg, spacing: spacingArg))
    case .none:
        return .zStack(.parameters(alignment: alignmentArg))
    case .grid:
        // Fallback to VStack for grid orientation
        return .vStack(.parameters(alignment: alignmentArg, spacing: spacingArg))
    }
}

/// Creates alignment argument from LayerData inputs based on stack orientation
func createAlignmentArg(from inputs: LayerDataConstructorInputs, orientation: StitchOrientation) -> SyntaxViewModifierArgumentType? {
    guard let anchoring = inputs.anchoring(.layerGroupAlignment) else {
        return nil // Use SwiftUI default alignment
    }
    
    // Convert Stitch Anchoring to SwiftUI alignment based on stack orientation
    let alignmentProperty: String?
    
    switch orientation {
    case .horizontal:
        // HStack uses VerticalAlignment
        switch anchoring {
        case .topCenter, .topLeft, .topRight:
            alignmentProperty = "top"
        case .centerCenter, .centerLeft, .centerRight:
            alignmentProperty = "center"
        case .bottomCenter, .bottomLeft, .bottomRight:
            alignmentProperty = "bottom"
            
        // Note: technically, Stitch Anchoring is a (0,0), which is many more values than SwiftUI Alignment
        default:
            alignmentProperty = "center"
        }
        
    case .vertical:
        // VStack uses HorizontalAlignment
        switch anchoring {
        case .centerLeft, .topLeft, .bottomLeft:
            alignmentProperty = "leading"
        case .centerCenter, .topCenter, .bottomCenter:
            alignmentProperty = "center"
        case .centerRight, .topRight, .bottomRight:
            alignmentProperty = "trailing"
        default:
            alignmentProperty = "center"
        }
        
    case .none:
        // ZStack uses Alignment (both horizontal and vertical)
        switch anchoring {
        case .topLeft:
            alignmentProperty = "topLeading"
        case .topCenter:
            alignmentProperty = "top"
        case .topRight:
            alignmentProperty = "topTrailing"
        case .centerLeft:
            alignmentProperty = "leading"
        case .centerCenter:
            alignmentProperty = "center"
        case .centerRight:
            alignmentProperty = "trailing"
        case .bottomLeft:
            alignmentProperty = "bottomLeading"
        case .bottomCenter:
            alignmentProperty = "bottom"
        case .bottomRight:
            alignmentProperty = "bottomTrailing"
        default:
            alignmentProperty = "center"
        }
        
    case .grid:
        // Grid uses HorizontalAlignment like VStack
        switch anchoring {
        case .centerLeft, .topLeft, .bottomLeft:
            alignmentProperty = "leading"
        case .centerCenter, .topCenter, .bottomCenter:
            alignmentProperty = "center"
        case .centerRight, .topRight, .bottomRight:
            alignmentProperty = "trailing"
        default:
            alignmentProperty = "center"
        }
    }
    
    guard let property = alignmentProperty else { return nil }
    
    return .memberAccess(SyntaxViewMemberAccess(base: nil, property: property))
}

/// Creates StrictViewModifier array from LayerData custom input values
func createStrictViewModifiersFromLayerData(_ layerData: AIGraphData_V0.LayerData,
                                            idMap: inout [String: UUID]) throws -> [StrictViewModifier] {
    var modifiers: [StrictViewModifier] = []
    
    // Extract layer type from layerData
    let layerType: AIGraphData_V0.Layer
    switch layerData.node_name.value {
    case .layer(let x):
        layerType = x
    case .patch(let x):
        throw SwiftUISyntaxError.unexpectedPatch(x)
        layerType = .group // BAD
    }
    
    // Group custom input values by layer input port to handle unpacked ports
    var groupedInputs: [LayerInputPort: [LayerPortDerivation]] = [:]
    
    for customInputValue in layerData.custom_layer_input_values {
        let port = customInputValue.coordinate.layerInput
        groupedInputs[port, default: []].append(customInputValue)
    }
    
    // Process each group of inputs for the same port
    for (port, inputs) in groupedInputs {
        if inputs.count == 1 && inputs.first?.coordinate.portType == .packed {
            // Single packed input - handle normally
            let customInputValue = inputs[0]
            if let portValue = decodePortValueFromCIV(customInputValue, idMap: &idMap) {
                // Concrete value case
                if let constructorModifier = try makeViewModifierConstructor(from: port, value: portValue, layerType: layerType) {
                    modifiers.append(constructorModifier)
                }
            } else if case .stateRef(let stateRefName) = customInputValue.inputData {
                // State reference case - create modifier with stateAccess argument
                if let constructorModifier = makeViewModifierConstructorFromStateRef(from: port, stateRef: stateRefName, layerType: layerType) {
                    modifiers.append(constructorModifier)
                }
            }
        } else {
            // Multiple unpacked inputs - handle specially for frame and offset modifiers
            if port == .size {
                if let frameModifier = createFrameViewModifierFromUnpackedInputs(inputs, idMap: &idMap) {
                    modifiers.append(frameModifier)
                }
            } else if port == .position {
                if let positionModifier = createPositionViewModifierFromUnpackedInputs(inputs, idMap: &idMap) {
                    modifiers.append(positionModifier)
                }
            } else if port == .offsetInGroup {
                if let offsetModifier = createOffsetViewModifierFromUnpackedInputs(inputs, idMap: &idMap) {
                    modifiers.append(offsetModifier)
                }
            } else {
                // For other ports with unpacked inputs, handle each separately for now
                for customInputValue in inputs {
                    if let portValue = decodePortValueFromCIV(customInputValue, idMap: &idMap) {
                        if let constructorModifier = try makeViewModifierConstructor(from: port, value: portValue, layerType: layerType) {
                            modifiers.append(constructorModifier)
                        }
                    } else if case .stateRef(let stateRefName) = customInputValue.inputData {
                        if let constructorModifier = makeViewModifierConstructorFromStateRef(from: port, stateRef: stateRefName, layerType: layerType) {
                            modifiers.append(constructorModifier)
                        }
                    }
                }
            }
        }
    }
    
    return modifiers
}

/// Creates a FrameViewModifier from unpacked size inputs (width and height)
func createFrameViewModifierFromUnpackedInputs(_ inputs: [LayerPortDerivation],
                                               idMap: inout [String: UUID]) -> StrictViewModifier? {
    guard !inputs.isEmpty else { return nil }
    
    var width: SyntaxViewModifierArgumentType?
    var height: SyntaxViewModifierArgumentType?
    
    for input in inputs {
        guard case .unpacked(let unpackedType) = input.coordinate.portType else { continue }
        
        let syntaxArg: SyntaxViewModifierArgumentType
        
        // Handle both concrete values and state references
        if let portValue = decodePortValueFromCIV(input, idMap: &idMap) {
            // Concrete value case
            if let number = portValue.getNumber {
                syntaxArg = .simple(SyntaxViewSimpleData(value: String(number), syntaxKind: .literal(.float)))
            } else {
                continue // Skip if we can't extract a number
            }
        } else if case .stateRef(let stateRefName) = input.inputData {
            // State reference case
            syntaxArg = .stateAccess(stateRefName)
        } else {
            continue // Skip if we can't handle this input
        }
        
        // Map unpacked port index to width/height
        switch unpackedType {
        case .port0: // Width
            width = syntaxArg
        case .port1: // Height  
            height = syntaxArg
        default:
            // Ignore other ports for now
            continue
        }
    }
    
    // Create FrameViewModifier if we have at least width or height
    if width != nil || height != nil {
        return .frame(FrameViewModifier(width: width, height: height))
    }
    
    return nil
}

/// Creates an OffsetViewModifier from unpacked offsetInGroup inputs (x and y)
func createOffsetViewModifierFromUnpackedInputs(_ inputs: [LayerPortDerivation],
                                               idMap: inout [String: UUID]) -> StrictViewModifier? {
    guard !inputs.isEmpty else { return nil }
    
    var x: SyntaxViewModifierArgumentType?
    var y: SyntaxViewModifierArgumentType?
    
    for input in inputs {
        guard case .unpacked(let unpackedType) = input.coordinate.portType else { continue }
        
        let syntaxArg: SyntaxViewModifierArgumentType
        
        // Handle both concrete values and state references
        if let portValue = decodePortValueFromCIV(input, idMap: &idMap) {
            // Concrete value case
            if let number = portValue.getNumber {
                syntaxArg = .simple(SyntaxViewSimpleData(value: String(number), syntaxKind: .literal(.float)))
            } else {
                continue // Skip if we can't extract a number
            }
        } else if case .stateRef(let stateRefName) = input.inputData {
            // State reference case
            syntaxArg = .stateAccess(stateRefName)
        } else {
            continue // Skip if we can't handle this input
        }
        
        // Map unpacked port index to x/y
        switch unpackedType {
        case .port0: // X
            x = syntaxArg
        case .port1: // Y  
            y = syntaxArg
        default:
            // Ignore other ports for now
            continue
        }
    }
    
    // Create OffsetViewModifier if we have both x and y
    if let x = x, let y = y {
        return .offset(OffsetViewModifier(x: x, y: y))
    }
    
    return nil
}

/// Creates a PositionViewModifier from unpacked position inputs (x and y)
func createPositionViewModifierFromUnpackedInputs(_ inputs: [LayerPortDerivation],
                                                  idMap: inout [String: UUID]) -> StrictViewModifier? {
    guard !inputs.isEmpty else { return nil }
    
    var x: SyntaxViewModifierArgumentType?
    var y: SyntaxViewModifierArgumentType?
    
    for input in inputs {
        guard case .unpacked(let unpackedType) = input.coordinate.portType else { continue }
        
        let syntaxArg: SyntaxViewModifierArgumentType
        
        // Handle both concrete values and state references
        if let portValue = decodePortValueFromCIV(input, idMap: &idMap) {
            // Concrete value case
            if let number = portValue.getNumber {
                syntaxArg = .simple(SyntaxViewSimpleData(value: String(number), syntaxKind: .literal(.float)))
            } else {
                continue // Skip if we can't extract a number
            }
        } else if case .stateRef(let stateRefName) = input.inputData {
            // State reference case
            syntaxArg = .stateAccess(stateRefName)
        } else {
            continue // Skip if we can't handle this input
        }
        
        // Map unpacked port index to x/y
        switch unpackedType {
        case .port0: // X
            x = syntaxArg
        case .port1: // Y  
            y = syntaxArg
        default:
            // Ignore other ports for now
            continue
        }
    }
    
    // Create PositionViewModifier if we have both x and y
    if let x = x, let y = y {
        return .position(PositionViewModifier.unpacked(x: x, y: y))
    }
    
    return nil
}

/// Creates a StrictViewModifier from a state reference (for variables like myVar)
func makeViewModifierConstructorFromStateRef(from port: LayerInputPort,
                                             stateRef: String,
                                             layerType: AIGraphData_V0.Layer) -> StrictViewModifier? {
    // Create a stateAccess argument type
    let stateAccessArg = SyntaxViewModifierArgumentType.stateAccess(stateRef)
    
    switch port {
    case .opacity:
        return .opacity(OpacityViewModifier(value: stateAccessArg))
    case .scale:
        return .scaleEffect(.uniform(scale: stateAccessArg, anchor: nil))
    case .blur, .blurRadius:
        return .blur(BlurViewModifier(radius: stateAccessArg))
    case .zIndex:
        return .zIndex(ZIndexViewModifier(value: stateAccessArg))
    case .cornerRadius:
        return .cornerRadius(CornerRadiusViewModifier(radius: stateAccessArg))
    case .color:
        return .fill(FillViewModifier(color: stateAccessArg))
    case .brightness:
        return .brightness(BrightnessViewModifier(value: stateAccessArg))
    case .contrast:
        return .contrast(ContrastViewModifier(value: stateAccessArg))
    case .saturation:
        return .saturation(SaturationViewModifier(value: stateAccessArg))
    case .hueRotation:
        return .hueRotation(HueRotationViewModifier(angle: stateAccessArg))
    case .position:
        // Position needs x and y, but we only have one state ref - use it for both
        return .position(PositionViewModifier.packed(stateAccessArg))
    case .offsetInGroup:
        // Offset needs x and y, but we only have one state ref - use it for both  
        return .offset(OffsetViewModifier(x: stateAccessArg, y: stateAccessArg))
    case .textFont:
        return .font(FontViewModifier(font: stateAccessArg))
    case .rotationX:
        // For now, treat rotationX as unsupported  
        return nil
    case .rotationY:
        // For now, treat rotationY as unsupported
        return nil
    case .rotationZ:
        return .rotationEffect(RotationEffectViewModifier(angle: stateAccessArg))
    default:
        // For unsupported ports, don't create a modifier
        return nil
    }
}

/// Converts a list of LayerData to StrictSyntaxView list
func layerDataListToStrictSyntaxViews(_ layerDataList: [AIGraphData_V0.LayerData], idMap: inout [String: UUID]) throws -> [StrictSyntaxView] {
    return try layerDataList.compactMap { layerData in
        try layerDataToStrictSyntaxView(layerData, idMap: &idMap)
    }
}

/// Converts GraphData to a list of StrictSyntaxView (root-level views)
func graphDataToStrictSyntaxViews(_ graphData: AIGraphData_V0.GraphData) throws -> [StrictSyntaxView] {
    var idMap: [String: UUID] = [:]
    return try layerDataListToStrictSyntaxViews(graphData.layer_data_list, idMap: &idMap)
}

// MARK: - StrictSyntaxView → SwiftUI Code Generation

extension StrictSyntaxView {
    /// Generates complete SwiftUI code string for this view including modifiers and children
    func toSwiftUICode(usePortValueDescription: Bool = true) -> String {
        let constructorString = constructor.swiftUICallString()
        
        // Handle children for container views
        let viewWithChildren = constructorString + generateChildrenCode(usePortValueDescription: usePortValueDescription)
        
        // Apply modifiers after the complete view (including children)
        let modifiersString = modifiers.map { modifier in
            renderStrictViewModifier(modifier, usePortValueDescription: usePortValueDescription)
        }.joined()
        
        return viewWithChildren + modifiersString
    }
    
    private func generateChildrenCode(usePortValueDescription: Bool = true) -> String {
        guard !children.isEmpty else { return "" }
        
        // Check if this is a container view that needs children
        switch constructor {
        case .hStack, .vStack, .zStack, .scrollView, .lazyHStack, .lazyVStack:
            // Reverse children for ZStack to match visual order (Stitch first child = SwiftUI last child)
            let orderedChildren: [StrictSyntaxView]
            if case .zStack = constructor {
                orderedChildren = Array(children.reversed())
            } else {
                orderedChildren = children
            }
            
            let childrenCode = orderedChildren.map { child in
                // Add proper indentation for each child
                child.toSwiftUICode(usePortValueDescription: usePortValueDescription).components(separatedBy: "\n")
                    .map { line in line.isEmpty ? "" : "    \(line)" }
                    .joined(separator: "\n")
            }.joined(separator: "\n")
            return " {\n\(childrenCode)\n}"
        default:
            // Non-container views - children are ignored or handled differently
            return ""
        }
    }
}

/// Renders a StrictViewModifier to SwiftUI modifier string
func renderStrictViewModifier(_ modifier: StrictViewModifier, usePortValueDescription: Bool = true) -> String {
    switch modifier {
    case .opacity(let m):
        return ".opacity(\(renderArg(m.value, usePortValueDescription: usePortValueDescription, valueType: "number")))"
    case .scaleEffect(let m):
        switch m {
        case .uniform(let scale, let anchor):
            let anchorPart = anchor.map { ", anchor: \(renderArg($0))" } ?? ""
            return ".scaleEffect(\(renderArg(scale, usePortValueDescription: usePortValueDescription, valueType: "number"))\(anchorPart))"
        case .xy(let x, let y, let anchor):
            let anchorPart = anchor.map { ", anchor: \(renderArg($0))" } ?? ""
            return ".scaleEffect(x: \(renderArg(x, usePortValueDescription: usePortValueDescription, valueType: "number")), y: \(renderArg(y, usePortValueDescription: usePortValueDescription, valueType: "number"))\(anchorPart))"
        case .size(let size, let anchor):
            let anchorPart = anchor.map { ", anchor: \(renderArg($0))" } ?? ""
            return ".scaleEffect(\(renderArg(size, usePortValueDescription: usePortValueDescription, valueType: "size"))\(anchorPart))"
        }
    case .blur(let m):
        return ".blur(radius: \(renderArg(m.radius, usePortValueDescription: usePortValueDescription, valueType: "number")))"
    case .zIndex(let m):
        return ".zIndex(\(renderArg(m.value, usePortValueDescription: usePortValueDescription, valueType: "number")))"
    case .cornerRadius(let m):
        return ".cornerRadius(\(renderArg(m.radius, usePortValueDescription: usePortValueDescription, valueType: "number")))"
    case .frame(let m):
        var parts: [String] = []
        if let width = m.width {
            parts.append("width: \(renderArg(width, usePortValueDescription: usePortValueDescription, valueType: "number"))")
        }
        if let height = m.height {
            parts.append("height: \(renderArg(height, usePortValueDescription: usePortValueDescription, valueType: "number"))")
        }
        // Only generate .frame() if we have at least one parameter
        guard !parts.isEmpty else { return "" }
        return ".frame(\(parts.joined(separator: ", ")))"
    case .foregroundColor(let m):
        return ".foregroundColor(\(renderArg(m.color, usePortValueDescription: usePortValueDescription, valueType: "color")))"
    case .fill(let m):
        return ".fill(\(renderArg(m.color, usePortValueDescription: usePortValueDescription, valueType: "color")))"
    case .brightness(let m):
        return ".brightness(\(renderArg(m.value)))"
    case .contrast(let m):
        return ".contrast(\(renderArg(m.value)))"
    case .saturation(let m):
        return ".saturation(\(renderArg(m.value)))"
    case .hueRotation(let m):
        return ".hueRotation(\(renderArg(m.angle)))"
    case .colorInvert(_):
        return ".colorInvert()"
    case .position(let m):
        switch m {
        case .packed(let arg):
            return ".position(\(renderArg(arg, valueType: "position")))"
            
        case .unpacked(let x, let y):
            return ".position(x: \(renderArg(x, valueType: "number")), y: \(renderArg(y, valueType: "number")))"
        }
    case .offset(let m):
        return ".offset(x: \(renderArg(m.x)), y: \(renderArg(m.y)))"
    case .padding(let m):
        if let length = m.length {
            return ".padding(\(renderArg(length)))"
        } else {
            return ".padding()"
        }
    case .clipped(_):
        return ".clipped()"
    case .font(let m):
        return ".font(\(renderArg(m.font)))"
    case .fontDesign(let m):
        return ".fontDesign(\(renderArg(m.design)))"
    case .fontWeight(let m):
        return ".fontWeight(\(renderArg(m.weight)))"
    case .rotationEffect(let m):
        return ".rotationEffect(\(renderArg(m.angle)))"
    case .rotation3DEffect(let m):
        return ".rotation3DEffect(\(renderArg(m.angle)), axis: (x: 0, y: 0, z: 1))"
    case .layerId(let m):
        return ".layerId(\(renderArg(m.layerId)))"
    }
}

// MARK: - ViewConstructor → SwiftUI source string (constructors only)
extension StrictViewConstructor {
    /// Returns a SwiftUI call-site string for this constructor.
    /// NOTE: No modifiers or children are emitted here.
    func swiftUICallString() -> String {
        switch self {
        case .text(let ctor):
            return renderText(ctor)
            
        case .image(let ctor):
            return renderImage(ctor)
            
        case .hStack(let ctor):
            switch ctor {
            case .parameters(let alignment, let spacing):
                let parts = callParts([
                    named("alignment", alignment),
                    named("spacing", spacing)
                ])
                return parts.isEmpty ? "HStack" : "HStack(\(parts))"
            }
            
        case .vStack(let ctor):
            switch ctor {
            case .parameters(let alignment, let spacing):
                let parts = callParts([
                    named("alignment", alignment),
                    named("spacing", spacing)
                ])
                return parts.isEmpty ? "VStack" : "VStack(\(parts))"
            }
            
        case .zStack(let ctor):
            switch ctor {
            case .parameters(let alignment):
                if let alignment = alignment { return "ZStack(alignment: \(renderArg(alignment)))" }
                return "ZStack"
            }
            
        case .circle:
            return "Circle()"
            
        case .ellipse:
            return "Ellipse()"
            
        case .rectangle:
            return "Rectangle()"
            
            //        case .roundedRectangle(let ctor):
            //            switch ctor {
            //            case .cornerRadius(let radius):
            //                return "RoundedRectangle(cornerRadius: \(renderArg(radius)))"
            //            }
            //
        case .scrollView(let ctor):
            switch ctor {
            case .parameters(let axes, let showsIndicators):
                let parts = callParts([
                    unnamed(axes),
                    named("showsIndicators", showsIndicators)
                ])
                return parts.isEmpty ? "ScrollView" : "ScrollView(\(parts))"
            }
            //
            //        case .textField(let ctor):
            //            // Minimal placeholder to avoid binding complexity in this pass
            //            switch ctor {
            //            case .parameters(let title, _):
            //                return "TextField(\(renderTextLiteral(title)), .constant(\"\"))"
            //            default:
            //                return "TextField(/* … */)"
            //            }
            
        case .stitchRealityView:
            return "StitchRealityView()"
        case .box:
            return "Box()"
        case .cone:
            return "Cone()"
        case .cylinder:
            return "Cylinder()"
        case .sphere:
            return "Sphere()"
            
            //        case .angularGradient:
            //            return "AngularGradient(/* not emitted here */)"
            //        case .linearGradient:
            //            return "LinearGradient(/* not emitted here */)"
            //        case .radialGradient:
            //            return "RadialGradient(/* not emitted here */)"
            
        case .spacer, .lazyHStack, .lazyVStack:
            return "NOT YET SUPPORTED"
        }
    }
}

// MARK: - Specific renderers used above
func renderText(_ ctor: TextViewConstructor) -> String {
    switch ctor {
    case .string(let arg):
        return "Text(\(renderArg(arg)))"
    case .verbatim(let arg):
        return "Text(verbatim: \(renderArg(arg)))"
    case .localized(let arg):
        return "Text(\(renderArg(arg)))"
    case .attributed(let arg):
        return "Text(\(renderArg(arg)))"
    }
}

func renderImage(_ ctor: ImageViewConstructor) -> String {
    switch ctor {
    case .sfSymbol(let name):
        return "Image(systemName: \(renderArg(name)))"
    case .asset(let name):
        return "Image(\(renderArg(name)))"
    case .decorative(let name):
        return "Image(decorative: \(renderArg(name)))"
    case .uiImage:
        // Historically tied to async media; keep placeholder
        return "Image(/* async media */)"
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

//func renderTextLiteral(_ literal: TextFieldViewConstructor.TextLiteral) -> String {
//    // Render a text literal used in TextField(title:)
//    switch literal {
//    case .literal(let s):
//        return "\"\(s)\""
//    }
//}

func callParts(_ labeled: [String?]) -> String {
    labeled.compactMap { $0 }.joined(separator: ", ")
}

func named(_ label: String, _ arg: SyntaxViewModifierArgumentType?) -> String? {
    guard let a = arg else { return nil }
    return "\(label): \(renderArg(a))"
}

func unnamed(_ arg: SyntaxViewModifierArgumentType?) -> String? {
    guard let a = arg else { return nil }
    return renderArg(a)
}

func renderAnyEncodable(_ any: AnyEncodable) -> String {
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(any), let s = String(data: data, encoding: .utf8) {
        return s
    }
    return "_"
}

// TODO: this is probably redundant vs. other ways of parsing semantic colors
/// Creates proper SwiftUI color syntax for a Stitch color value
func createColorArgument(_ color: Color) -> SyntaxViewModifierArgumentType {
    // Check if this is a semantic color (e.g., Color.blue, Color.red)
    switch color {
    case .black:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "black"))
    case .blue:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "blue"))
    case .brown:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "brown"))
    case .clear:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "clear"))
    case .cyan:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "cyan"))
    case .gray:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "gray"))
    case .green:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "green"))
    case .indigo:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "indigo"))
    case .mint:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "mint"))
    case .orange:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "orange"))
    case .pink:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "pink"))
    case .purple:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "purple"))
    case .red:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "red"))
    case .teal:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "teal"))
    case .white:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "white"))
    case .yellow:
        return .memberAccess(SyntaxViewMemberAccess(base: "Color", property: "yellow"))
    default:
        // Try to convert the color back to a hex string using ColorConversionUtils
        if let hexString = ColorConversionUtils.colorToHex(color) {
            return .complex(SyntaxViewModifierComplexType(
                typeName: "Color",
                arguments: [
                    .init(label: nil, value: .simple(SyntaxViewSimpleData(value: "#\(hexString)", syntaxKind: .literal(.string))))
                ]
            ))
        }
        
        // For custom colors that can't be converted to hex, use Color(...) initializer with RGBA values
        let rgba = color.asRGBA
        let redString = String(format: "%.3f", rgba.red)
        let greenString = String(format: "%.3f", rgba.green)
        let blueString = String(format: "%.3f", rgba.blue)
        let alphaString = String(format: "%.3f", rgba.alpha)
                
        return .complex(SyntaxViewModifierComplexType(
            typeName: "Color",
            arguments: [
                .init(label: "red", value: .simple(SyntaxViewSimpleData(value: redString, syntaxKind: .literal(.float)))),
                .init(label: "green", value: .simple(SyntaxViewSimpleData(value: greenString, syntaxKind: .literal(.float)))),
                .init(label: "blue", value: .simple(SyntaxViewSimpleData(value: blueString, syntaxKind: .literal(.float)))),
                .init(label: "opacity", value: .simple(SyntaxViewSimpleData(value: alphaString, syntaxKind: .literal(.float))))
            ]
        ))
    }
}

// MARK: - ViewModifierConstructor (intermediate) mapping & rendering

/// Creates a typed view-modifier constructor from a layer input value, when supported.
func makeViewModifierConstructor(from port: LayerInputPort,
                                 value: AIGraphData_V0.PortValue,
                                 layerType: AIGraphData_V0.Layer) throws -> StrictViewModifier? {
    let syntaxFromArg = try value.getSyntaxViewModifierArgumentType()
    
    switch port {
    case .opacity:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .literal(.float))
            )
            return .opacity(OpacityViewModifier(value: arg))
        }
        return nil
    case .scale:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .literal(.float))
            )
            return .scaleEffect(.uniform(scale: arg, anchor: nil))
        }
        return nil
    case .blur, .blurRadius:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .literal(.float))
            )
            return .blur(BlurViewModifier(radius: arg))
        }
        return nil
    case .zIndex:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .literal(.float))
            )
            return .zIndex(ZIndexViewModifier(value: arg))
        }
        return nil
    case .cornerRadius:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .literal(.float))
            )
            return .cornerRadius(CornerRadiusViewModifier(radius: arg))
        }
        return nil
    case .size:
        if let size = value.getSize {
            var width: SyntaxViewModifierArgumentType?
            var height: SyntaxViewModifierArgumentType?
            
            // Convert LayerDimension to SyntaxViewModifierArgumentType
            if case .number(let widthValue) = size.width {
                width = .simple(SyntaxViewSimpleData(value: widthValue.description,
                                                     syntaxKind: .literal(.float)))
            }
            
            if case .number(let heightValue) = size.height {
                height = .simple(SyntaxViewSimpleData(value: heightValue.description,
                                                      syntaxKind: .literal(.float)))
            }
            
            // Only create the modifier if we have at least one dimension
            if width != nil || height != nil {
                return .frame(FrameViewModifier(width: width, height: height))
            }
        }
        return nil
    case .color:
        if let color = value.getColor {
            let arg = createColorArgument(color)
            // Choose modifier based on layer type
            switch layerType {
            case .rectangle, .oval, .shape:
                // Shape layers use .fill()
                return .fill(FillViewModifier(color: arg))
            case .text, .textField:
                // Text layers use .foregroundColor()
                return .foregroundColor(ForegroundColorViewModifier(color: arg))
            default:
                // Default to .foregroundColor() for other layer types
                return .foregroundColor(ForegroundColorViewModifier(color: arg))
            }
        }
        return nil
    case .brightness:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .literal(.float))
            )
            return .brightness(BrightnessViewModifier(value: arg))
        }
        return nil
    case .contrast:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .literal(.float))
            )
            return .contrast(ContrastViewModifier(value: arg))
        }
        return nil
    case .saturation:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: String(number), syntaxKind: .literal(.float))
            )
            return .saturation(SaturationViewModifier(value: arg))
        }
        return nil
    case .hueRotation:
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.complex(
                SyntaxViewModifierComplexType(
                    typeName: "",
                    arguments: [
                        .init(label: "degrees", value: .simple(SyntaxViewSimpleData(value: String(number), syntaxKind: .literal(.float))))
                    ]
                )
            )
            return .hueRotation(HueRotationViewModifier(angle: arg))
        }
        return nil
    case .colorInvert:
        if let bool = value.getBool, bool {
            return .colorInvert(ColorInvertViewModifier())
        }
        return nil
    case .position:
        return .position(PositionViewModifier.packed(syntaxFromArg))
    case .offsetInGroup:
        if let position = value.getPosition {
            let xArg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: position.x.description, syntaxKind: .literal(.float))
            )
            let yArg = SyntaxViewModifierArgumentType.simple(
                SyntaxViewSimpleData(value: position.y.description, syntaxKind: .literal(.float))
            )
            return .offset(OffsetViewModifier(x: xArg, y: yArg))
        }
        return nil
    case .padding:
        if let padding = value.getPadding {
            // For now, handle uniform padding only
            if padding.top == padding.right && padding.right == padding.bottom && padding.bottom == padding.left {
                let arg = SyntaxViewModifierArgumentType.simple(
                    SyntaxViewSimpleData(value: padding.top.description, syntaxKind: .literal(.float))
                )
                return .padding(PaddingViewModifier(edges: nil, length: arg))
            }
        }
        return nil
    case .isClipped:
        if let bool = value.getBool, bool {
            return .clipped(ClippedViewModifier())
        }
        return nil
    case .textFont:
        if let stitchFont = value.getTextFont {
            return decomposeFontToModifiers(stitchFont)
        }
        return nil
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
        if let number = value.getNumber {
            let arg = SyntaxViewModifierArgumentType.complex(
                SyntaxViewModifierComplexType(
                    typeName: "",
                    arguments: [
                        .init(label: "degrees", value: .simple(SyntaxViewSimpleData(value: String(number), syntaxKind: .literal(.float))))
                    ]
                )
            )
            return .rotationEffect(RotationEffectViewModifier(angle: arg))
        }
        return nil
    default:
        return nil
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

/// Renders a typed view-modifier constructor back into SwiftUI source code.
func renderViewModifierConstructor(_ modifier: StrictViewModifier) -> String {
    switch modifier {
    case .opacity(let m):
        return ".opacity(\(renderArg(m.value)))"
    case .scaleEffect(let m):
        switch m {
        case .uniform(let scale, let anchor):
            let anchorPart = anchor.map { ", anchor: \(renderArg($0))" } ?? ""
            return ".scaleEffect(\(renderArg(scale))\(anchorPart))"
        case .xy(let x, let y, let anchor):
            let anchorPart = anchor.map { ", anchor: \(renderArg($0))" } ?? ""
            return ".scaleEffect(x: \(renderArg(x)), y: \(renderArg(y))\(anchorPart))"
        case .size(let size, let anchor):
            let anchorPart = anchor.map { ", anchor: \(renderArg($0))" } ?? ""
            return ".scaleEffect(\(renderArg(size))\(anchorPart))"
        }
    case .blur(let m):
        return ".blur(radius: \(renderArg(m.radius)))"
    case .zIndex(let m):
        return ".zIndex(\(renderArg(m.value)))"
    case .cornerRadius(let m):
        return ".cornerRadius(\(renderArg(m.radius)))"
    case .frame(let m):
        var parts: [String] = []
        if let width = m.width {
            parts.append("width: \(renderArg(width))")
        }
        if let height = m.height {
            parts.append("height: \(renderArg(height))")
        }
        // Only generate .frame() if we have at least one parameter
        guard !parts.isEmpty else { return "" }
        return ".frame(\(parts.joined(separator: ", ")))"
    case .foregroundColor(let m):
        return ".foregroundColor(\(renderArg(m.color)))"
    case .fill(let m):
        return ".fill(\(renderArg(m.color)))"
    case .brightness(let m):
        return ".brightness(\(renderArg(m.value)))"
    case .contrast(let m):
        return ".contrast(\(renderArg(m.value)))"
    case .saturation(let m):
        return ".saturation(\(renderArg(m.value)))"
    case .hueRotation(let m):
        return ".hueRotation(\(renderArg(m.angle)))"
    case .colorInvert(_):
        return ".colorInvert()"
    case .position(let m):
        return ".position: \(m.allArgs)"
    case .offset(let m):
        return ".offset(x: \(renderArg(m.x)), y: \(renderArg(m.y)))"
    case .padding(let m):
        if let length = m.length {
            return ".padding(\(renderArg(length)))"
        } else {
            return ".padding()"
        }
    case .clipped(_):
        return ".clipped()"
    case .font(let m):
        return ".font(\(renderArg(m.font)))"
    case .fontDesign(let m):
        return ".fontDesign(\(renderArg(m.design)))"
    case .fontWeight(let m):
        return ".fontWeight(\(renderArg(m.weight)))"
    case .rotationEffect(let m):
        return ".rotationEffect(\(renderArg(m.angle)))"
    case .rotation3DEffect(let m):
        return ".rotation3DEffect(\(renderArg(m.angle)), axis: (x: 0, y: 0, z: 1))"
    case .layerId(let m):
        return ".layerId(\(renderArg(m.layerId)))"
    }
}

// MARK: - LayerInputPort → SwiftUI View Modifier Mapping

/// Maps a LayerInputPort and its PortValue to a SwiftUI view modifier string.
/// Returns nil if the LayerInputPort doesn't correspond to a view modifier.
func layerInputPortToSwiftUIModifier(port: LayerInputPort, value: AIGraphData_V0.PortValue) -> String? {
    switch port {
    // Simple single-argument modifiers
    case .opacity:
        // Handled via intermediate ViewModifierConstructor (.opacity) pathway
        return nil
    case .scale:
        // Handled via intermediate ViewModifierConstructor (.scaleEffect) pathway
        return nil
    case .zIndex:
        // Handled via intermediate ViewModifierConstructor (.zIndex) pathway
        return nil
        
    case .blur, .blurRadius:
        // Handled via intermediate ViewModifierConstructor (.blur) pathway
        return nil
        
    case .cornerRadius:
        // Handled via intermediate ViewModifierConstructor (.cornerRadius) pathway
        return nil
        
    case .brightness:
        // Handled via intermediate ViewModifierConstructor (.brightness) pathway
        return nil
        
    case .contrast:
        // Handled via intermediate ViewModifierConstructor (.contrast) pathway
        return nil
        
    case .saturation:
        // Handled via intermediate ViewModifierConstructor (.saturation) pathway
        return nil
        
    case .hueRotation:
        // Handled via intermediate ViewModifierConstructor (.hueRotation) pathway
        return nil
        
    // Color modifiers - handled via ViewModifierConstructor pathway
    case .color:
        // Handled via intermediate ViewModifierConstructor (.foregroundColor) pathway
        return nil
        
    case .backgroundColor:
        // Handled via intermediate ViewModifierConstructor (.backgroundColor) pathway
        return nil
        
    // Boolean modifiers
    case .colorInvert:
        // Handled via intermediate ViewModifierConstructor (.colorInvert) pathway
        return nil
        
    case .isClipped, .clipped:
        // Handled via intermediate ViewModifierConstructor (.clipped) pathway
        return nil
        
//    case .disabled:
//        if let bool = value.getBool {
//            return ".disabled(\(bool))"
//        }
        
    // Complex modifiers - handled via ViewModifierConstructor pathway
    case .offsetInGroup:
        // Handled via intermediate ViewModifierConstructor (.offset) pathway
        return nil
        
    case .size:
        // Handled via intermediate ViewModifierConstructor (.frame) pathway
        return nil
        
    case .padding:
        // Handled via intermediate ViewModifierConstructor (.padding) pathway
        return nil
        
    case .position:
        // Handled via intermediate ViewModifierConstructor (.position) pathway
        return nil
        
    // TODO: this is not quite correct; `.text` needs to be
    // Modifiers that don't have direct SwiftUI equivalents or are handled at constructor level
    case .anchoring, .orientation, .text, .sfSymbol, .image, .video, .spacing, .layerGroupAlignment:
        return nil
        
    default:
        return nil
    }
    
    return nil
}

// TODO: use the existing color helpers
/// Renders a Color value as SwiftUI code
func renderColor(_ color: Color) -> String {
    // Convert SwiftUI Color to a string representation
    if color == .red { return "Color.red" }
    if color == .blue { return "Color.blue" }
    if color == .green { return "Color.green" }
    if color == .yellow { return "Color.yellow" }
    if color == .orange { return "Color.orange" }
    if color == .purple { return "Color.purple" }
    if color == .pink { return "Color.pink" }
    if color == .black { return "Color.black" }
    if color == .white { return "Color.white" }
    if color == .gray { return "Color.gray" }
    if color == .clear { return "Color.clear" }
    
    // Try to convert the color back to a hex string using ColorConversionUtils
    if let hexString = ColorConversionUtils.colorToHex(color) {
        return "Color(\"#\(hexString)\")"
    }
    
    // For custom colors that can't be converted to hex, get RGBA values for a more accurate representation
    let rgba = color.asRGBA
    return "Color(red: \(rgba.red), green: \(rgba.green), blue: \(rgba.blue), opacity: \(rgba.alpha))"
}

/// Generates all view modifiers for a given LayerData as strings
/// This is a convenience wrapper around createStrictViewModifiersFromLayerData
func generateViewModifiersForLayerData(_ layerData: AIGraphData_V0.LayerData, idMap: inout [String: UUID]) throws -> [String] {
    // Reuse the typed modifier creation logic
    let typedModifiers = try createStrictViewModifiersFromLayerData(layerData, idMap: &idMap)
    
    // Convert typed modifiers to strings
    var stringModifiers = typedModifiers.map { renderViewModifierConstructor($0) }
    
    // Handle any remaining ports that don't have typed modifiers yet (legacy fallback)
    let handledPorts = Set(typedModifiers.compactMap { modifier -> LayerInputPort? in
        // Extract the port type from each typed modifier for comparison
        switch modifier {
        case .opacity: return .opacity
        case .scaleEffect: return .scale
        case .blur: return .blur
        case .zIndex: return .zIndex
        case .cornerRadius: return .cornerRadius
        case .frame: return .size
        case .foregroundColor, .fill: return .color
        case .brightness: return .brightness
        case .contrast: return .contrast
        case .saturation: return .saturation
        case .hueRotation: return .hueRotation
        case .colorInvert: return .colorInvert
        case .position: return .position
        case .offset: return .offsetInGroup
        case .padding: return .padding
        case .clipped: return .isClipped
        case .font: return .textFont
        case .fontDesign: return .textFont
        case .fontWeight: return .textFont
        case .rotationEffect: return .rotationZ
        case .rotation3DEffect: return nil // Multi-port modifier - handled separately
        case .layerId(_): return nil // Nothing to do
        }
    })
    
    // Add legacy string modifiers for unhandled ports
    for customInputValue in layerData.custom_layer_input_values {
        let port = customInputValue.coordinate.layerInput
        
        if !handledPorts.contains(port),
           let portValue = decodePortValueFromCIV(customInputValue, idMap: &idMap),
           let s = layerInputPortToSwiftUIModifier(port: port, value: portValue) {
            stringModifiers.append(s)
        }
    }
    
    return stringModifiers
}


// MARK: - Complete SwiftUI Code Generation (Constructor + Modifiers)

/// Generates complete SwiftUI code for a LayerData including constructor and view modifiers
func generateCompleteSwiftUICode(for layerData: AIGraphData_V0.LayerData, idMap: inout [String: UUID]) throws -> String? {
    // Generate the base constructor
    guard let constructor = makeConstructorFromLayerData(layerData, idMap: &idMap) else {
        return nil
    }
    
    let baseSwiftUI = constructor.swiftUICallString()
    
    // Generate view modifiers
    let modifiers = try generateViewModifiersForLayerData(layerData, idMap: &idMap)
    
    // Combine constructor with modifiers
    if modifiers.isEmpty {
        return baseSwiftUI
    } else {
        let modifierChain = modifiers.joined(separator: "\n    ")
        return baseSwiftUI + "\n    " + modifierChain
    }
}

/// Example usage function showing how to convert a Stitch layer to SwiftUI
func convertStitchLayerToSwiftUI(layerData: AIGraphData_V0.LayerData) throws -> String? {
    var idMap: [String: UUID] = [:]
    return try generateCompleteSwiftUICode(for: layerData, idMap: &idMap)
}

extension PortValue {
    func getSyntaxViewModifierArgumentType() throws -> SyntaxViewModifierArgumentType {
        let argumentData = try self.anyCodable.encodeToString()
        
        return .complex(.init(typeName: SyntaxValueName.portValueDescription.rawValue,
                       arguments: [
                        .init(label: nil,
                              value: .simple(.init(value: argumentData,
                                                   syntaxKind: .expression(.closure))))
                       ]))
    }
}
