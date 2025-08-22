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
                                      orderedLayerEntities: [LayerNodeEntity],
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
                                              orderedLayerEntities: orderedLayerEntities,
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
            if let symbolName = self.sfSymbolPort.packedData.inputPort.values?.first?.getString?.string,
               symbolName != "" {
                let args = try self.sfSymbolPort
                    .getSwiftUICodeForValues(varIdNameMap: varIdNameMap)
                return SyntaxViewName.image.createConstructorCode(args)
            }
            fatalErrorIfDebug("SF Symbol layer has empty or missing symbol name")
            return nil
            
            // ───────── Text Field ─────────
        case .textField:
            let args = try self.textPort
                .getSwiftUICodeForValues(varIdNameMap: varIdNameMap)
            return SyntaxViewName.textField.createConstructorCode(args)
           
        case .spacer:
            return SyntaxViewName.spacer.createConstructorCode()
            
        // ───────── Not yet handled ─────────
        case .linearGradient, .radialGradient, .angularGradient,  .image, .video, .model3D, .shape, .colorFill, .hitArea, .canvasSketch, .map, .progressIndicator, .switchLayer, .videoStreaming, .material:
            fatalErrorIfDebug("Gradient layers (\(self.layer)) require proper color extraction implementation")
            return nil
        }
    }
    
    @MainActor
    func createNestedGroupSwiftUICode(children: [LayerNodeEntity],
                                      orderedLayerEntities: [LayerNodeEntity],
                                      varIdNameMap: [UUID: String]) throws -> String? {
        assertInDebug(self.layer == .group)
        
        let childrenContents = try children
            .createSwiftUICode(orderedLayerEntities: orderedLayerEntities,
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
                // Generate LazyVGrid code
                return try self.createLazyVGridCode(children: children,
                                                    orderedLayerEntities: orderedLayerEntities,
                                                    varIdNameMap: varIdNameMap)
            }
        }
    }
    
    @MainActor
    func createLazyVGridCode(children: [LayerNodeEntity],
                             orderedLayerEntities: [LayerNodeEntity],
                             varIdNameMap: [UUID: String]) throws -> String? {
        assertInDebug(self.layer == .group)
        
        let childrenContents = try children
            .createSwiftUICode(orderedLayerEntities: orderedLayerEntities,
                               varIdNameMap: varIdNameMap)
        
        // Get spacing from the group's spacing port
        let spacingArgs = try self.spacingPort.getSwiftUICodeForValues(varIdNameMap: varIdNameMap)
        
        // Infer column count from children count and common grid patterns
        let columnCount = inferGridColumnCount(childrenCount: children.count)
        
        // Generate flexible columns array
        let columnsDefinition = Array(repeating: "GridItem(.flexible())", count: columnCount).joined(separator: ", ")
        
        return """
            LazyVGrid(columns: [\(columnsDefinition)], spacing: \(spacingArgs)) {
                \(childrenContents)
            }
            """
    }
    
    /// Infers reasonable column count based on children count and common patterns
    private func inferGridColumnCount(childrenCount: Int) -> Int {
        // Common grid patterns:
        switch childrenCount {
        case 0...3:
            return max(1, childrenCount) // 1-3 items = 1-3 columns
        case 4...6:
            return 2 // 4-6 items = 2 columns
        case 7...9:
            return 3 // 7-9 items = 3 columns (common for keypads)
        case 10...12:
            return 3 // 10-12 items = 3 columns (phone keypad is 12 items)
        case 13...16:
            return 4 // 13-16 items = 4 columns
        default:
            // For larger grids, use square root as a reasonable default
            return max(3, Int(ceil(sqrt(Double(childrenCount)))))
        }
    }
        
    /// Converts layer data from graph to SwiftUI code
    @MainActor
    func createSwiftUICode(orderedLayerEntities: [LayerNodeEntity],
                           varIdNameMap: [UUID: String]) throws -> String? {
        let childrenLayerEntities = orderedLayerEntities.filter {
            $0.layerGroupId == self.id
        }
        
        let isGroup = self.layer == .group
        let isNotGroupButHasChildren = !isGroup && !childrenLayerEntities.isEmpty
        let constructorCode: String
        
        if isGroup {
            guard let groupSwiftUICode = try self
                .createNestedGroupSwiftUICode(children: childrenLayerEntities,
                                              orderedLayerEntities: orderedLayerEntities,
                                              varIdNameMap: varIdNameMap) else {
                return nil
            }
            
            constructorCode = groupSwiftUICode
        }
        
        else {
            // Create the constructor
            guard let constructor = try self
                .createSwiftUIViewBuilderCode(children: childrenLayerEntities,
                                              orderedLayerEntities: orderedLayerEntities,
                                              varIdNameMap: varIdNameMap) else {
                return nil
            }
                
            constructorCode = constructor
        }
        
        // Create modifiers from custom_layer_input_values
        let modifiersString = try self.getSwiftUIViewModifierStrings(varIdNameMap: varIdNameMap)
        
        var swiftUICode = """
            \(constructorCode)
                .layerId("\(self.id)")
                \(modifiersString.joined(separator: "\n\t\t"))
            """
        
        if isNotGroupButHasChildren {
            // Convert children recursively
            let swiftUICodeForChildren = try childrenLayerEntities.compactMap {
                try $0.createSwiftUICode(orderedLayerEntities: orderedLayerEntities,
                                         varIdNameMap: varIdNameMap)
            }
            
            swiftUICode += "\n\(swiftUICodeForChildren)"
        }
        
        return swiftUICode
    }
}

extension Array where Element == LayerNodeEntity {
    @MainActor
    func createSwiftUICode(orderedLayerEntities: [LayerNodeEntity],
                           varIdNameMap: [UUID: String]) throws -> String {
        var droppedLayers: [LayerNodeEntity] = []
        
        let strings = try self.compactMap { layerEntity -> String? in
            let result = try layerEntity.createSwiftUICode(orderedLayerEntities: orderedLayerEntities,
                                                           varIdNameMap: varIdNameMap)
            if result == nil {
                droppedLayers.append(layerEntity)
                log("DROPPED LAYER: \(layerEntity.layer) with id \(layerEntity.id) - createSwiftUICode returned nil")
            }
            return result
        }
        
        if !droppedLayers.isEmpty {
            log("TOTAL DROPPED LAYERS: \(droppedLayers.count) out of \(self.count)")
            for dropped in droppedLayers {
                log("  - \(dropped.layer) (id: \(dropped.id))")
            }
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
                // log("getSwiftUIViewModifierStrings: no view modifier for \(port) in \(self.layer)")
                return nil
            }
            let inputData = self[keyPath: port.schemaPortKeyPath]

            let defaultData = port.getDefaultValueForAI(for: self.layer)
            
            switch inputData.mode {
            case .packed:
                let firstValue = inputData.packedData.inputPort.values?.first
                
                guard defaultData != firstValue else {
                    // Skip if default data is equal--no view modifier needed in this event
                    return nil
                }
                
                let portValueArgs = try inputData.getSwiftUICodeForValues(varIdNameMap: varIdNameMap)
                return ".\(viewModifier.rawValue)(\(portValueArgs))"
                
            case .unpacked:
                let unpackedArgsString = try inputData
                    .getSwiftUICodeForValues(varIdNameMap: varIdNameMap)
                
                return ".\(viewModifier.rawValue)(\(unpackedArgsString))"
            }
            
        }
    }
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
