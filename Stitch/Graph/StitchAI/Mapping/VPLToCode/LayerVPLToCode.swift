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
                                      varIdNameMap: [NodeIOCoordinate: String],
                                      layerViewEventMap: [UUID: [SwiftPatchViewEvent]],
                                      isStreaming: Bool) throws -> String? {
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
                                              varIdNameMap: varIdNameMap,
                                              layerViewEventMap: layerViewEventMap,
                                              isStreaming: isStreaming)
            
            
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
            
        case .image:
            return SyntaxViewName.image.createConstructorCode()
            
        case .video:
            return SyntaxViewName.videoPlayer.createConstructorCode()
            
        case .radialGradient:
            return SyntaxViewName.radialGradient.createConstructorCode()
            
        case .linearGradient:
            return SyntaxViewName.linearGradient.createConstructorCode()
            
        case .angularGradient:
            return SyntaxViewName.angularGradient.createConstructorCode()
            
        case .model3D:
            return SyntaxViewName.model3D.createConstructorCode()

        case .map:
            return SyntaxViewName.map.createConstructorCode()
      
        case .material:
            return SyntaxViewName.material.createConstructorCode()
            
        // ───────── Not yet handled ─────────
        case .shape, .colorFill, .hitArea, .canvasSketch, .progressIndicator, .switchLayer, .videoStreaming:
            fatalErrorIfDebug("Gradient layers (\(self.layer)) require proper color extraction implementation")
            throw SwiftUISyntaxError.unsupportedSyntaxViewLayer(self.layer)
            // return nil
        }
    }
    
    @MainActor
    func createNestedGroupSwiftUICode(children: [LayerNodeEntity],
                                      orderedLayerEntities: [LayerNodeEntity],
                                      varIdNameMap: [NodeIOCoordinate: String],
                                      layerViewEventMap: [UUID: [SwiftPatchViewEvent]],
                                      isStreaming: Bool) throws -> String? {
        assertInDebug(self.layer == .group)
        
        let childrenContents = try children
            .createSwiftUICode(orderedLayerEntities: orderedLayerEntities,
                               varIdNameMap: varIdNameMap,
                               layerViewEventMap: layerViewEventMap,
                               isStreaming: isStreaming)
        
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
                \(childrenContents.indentLines())
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
                    \(childrenContents.indentLines())
                    }
                    """

            case .vertical:
                return """
                    VStack(alignment: .\(stackAlignmentArg), spacing: \(spacingArgs)) {
                    \(childrenContents.indentLines())
                    }
                    """
            case .none:
                return """
                    ZStack(alignment: .\(stackAlignmentArg)) {
                    \(childrenContents.indentLines())
                    }
                    """
            case .grid:
                // Generate LazyVGrid code
                return try self.createLazyVGridCode(children: children,
                                                    orderedLayerEntities: orderedLayerEntities,
                                                    varIdNameMap: varIdNameMap,
                                                    layerViewEventMap: layerViewEventMap,
                                                    isStreaming: isStreaming)
            }
        }
    }
    
    @MainActor
    func createLazyVGridCode(children: [LayerNodeEntity],
                             orderedLayerEntities: [LayerNodeEntity],
                             varIdNameMap: [NodeIOCoordinate: String],
                             layerViewEventMap: [UUID: [SwiftPatchViewEvent]],
                             isStreaming: Bool) throws -> String? {
        assertInDebug(self.layer == .group)
        
        let childrenContents = try children
            .createSwiftUICode(orderedLayerEntities: orderedLayerEntities,
                               varIdNameMap: varIdNameMap,
                               layerViewEventMap: layerViewEventMap,
                               isStreaming: isStreaming)
        
        // Get spacing from the group's spacing port
        let spacingArgs = try self.spacingPort.getSwiftUICodeForValues(varIdNameMap: varIdNameMap)
        
        // Infer column count from children count and common grid patterns
        let columnCount = inferGridColumnCount(childrenCount: children.count)
        
        // Generate flexible columns array
        let columnsDefinition = Array(repeating: "GridItem(.flexible())", count: columnCount).joined(separator: ", ")
        
        return """
            LazyVGrid(columns: [\(columnsDefinition)], spacing: \(spacingArgs)) {
            \(childrenContents.indentLines())
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
                           varIdNameMap: [NodeIOCoordinate: String],
                           layerViewEventMap: [UUID: [SwiftPatchViewEvent]],
                           isStreaming: Bool) throws -> String? {
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
                                              varIdNameMap: varIdNameMap,
                                              layerViewEventMap: layerViewEventMap,
                                              isStreaming: isStreaming) else {
                return nil
            }
            
            constructorCode = groupSwiftUICode
        }
        
        else {
            // Create the constructor
            guard let constructor = try self
                .createSwiftUIViewBuilderCode(children: childrenLayerEntities,
                                              orderedLayerEntities: orderedLayerEntities,
                                              varIdNameMap: varIdNameMap,
                                              layerViewEventMap: layerViewEventMap,
                                              isStreaming: isStreaming) else {
                return nil
            }
                
            constructorCode = constructor
        }
        
        // Create modifiers from custom_layer_input_values
        let modifiersString = try self.getSwiftUIViewModifierStrings(varIdNameMap: varIdNameMap)
        
        // Creates modifiers for gesture
        let gestureModifiersString = self.getSwiftUIGestureViewModifierStrings(layerViewEventMap: layerViewEventMap,
                                                                               isStreaming: isStreaming)
        
        var swiftUICode = """
            \(constructorCode)
            \(modifiersString.joined(separator: "\n").indentLines())
            \(gestureModifiersString.joined(separator: "\n").indentLines())
            """
        
        if isNotGroupButHasChildren {
            // Convert children recursively
            let swiftUICodeForChildren = try childrenLayerEntities.compactMap {
                try $0.createSwiftUICode(orderedLayerEntities: orderedLayerEntities,
                                         varIdNameMap: varIdNameMap,
                                         layerViewEventMap: layerViewEventMap,
                                         isStreaming: isStreaming)
            }
            
            swiftUICode += "\n\(swiftUICodeForChildren)"
        }
        
        return swiftUICode
    }
}

extension Array where Element == LayerNodeEntity {
    @MainActor
    func createSwiftUICode(orderedLayerEntities: [LayerNodeEntity],
                           varIdNameMap: [NodeIOCoordinate: String],
                           layerViewEventMap: [UUID: [SwiftPatchViewEvent]],
                           isStreaming: Bool) throws -> String {
        var droppedLayers: [LayerNodeEntity] = []
        
        let strings = try self.compactMap { layerEntity -> String? in
            let result = try layerEntity.createSwiftUICode(orderedLayerEntities: orderedLayerEntities,
                                                           varIdNameMap: varIdNameMap,
                                                           layerViewEventMap: layerViewEventMap,
                                                           isStreaming: isStreaming)
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
    func getSwiftUIViewModifierStrings(varIdNameMap: [NodeIOCoordinate: String]) throws -> [String] {
        let ports = self.layer.inputDefinitions
        var results: [String] = []
        var processedPositionPort = false
        
        for port in ports {
            // Special handling for position - combine with anchoring to choose modifier
            if port == .position && !processedPositionPort {
                processedPositionPort = true

                let positionInputData = self[keyPath: port.schemaPortKeyPath]
                let anchoringInputData = self.anchoringPort

                // Always generate position modifier to maintain explicit positioning
                // This prevents unintended anchoring changes when AI edits the code

                // Determine modifier type based on anchoring value
                let anchoringValue = anchoringInputData.packedData.inputPort.values?.first
                let currentAnchoring = anchoringValue?.getAnchoring ?? .centerCenter // Default to center

                let viewModifier: SyntaxViewModifierName
                switch currentAnchoring {
                case .centerCenter:
                    viewModifier = .offset
                case .topLeft:
                    viewModifier = .position
                default:
                    // For other anchorings, use position modifier
                    viewModifier = .position
                }

                // Generate the modifier string
                let portValueArgs = try positionInputData.getSwiftUICodeForValues(varIdNameMap: varIdNameMap)
                results.append(".\(viewModifier.rawValue)(\(portValueArgs))")

                continue
            }
            
            // Skip anchoring port as it's handled above with position
            if port == .anchoring { continue }
            
            // Standard handling for all other ports
            guard let viewModifier = port.viewModifierString(from: self.layer) else {
                continue
            }
            
            let inputData = self[keyPath: port.schemaPortKeyPath]
            let defaultData = port.getDefaultValueForAI(for: self.layer)
            
            switch inputData.mode {
            case .packed:
                let firstValue = inputData.packedData.inputPort.values?.first
                
                guard defaultData != firstValue else {
                    // Skip if default data is equal--no view modifier needed in this event
                    continue
                }
                
                let portValueArgs = try inputData.getSwiftUICodeForValues(varIdNameMap: varIdNameMap)
                results.append(".\(viewModifier.rawValue)(\(portValueArgs))")
                
            case .unpacked:
                let unpackedArgsString = try inputData
                    .getSwiftUICodeForValues(varIdNameMap: varIdNameMap)
                
                results.append(".\(viewModifier.rawValue)(\(unpackedArgsString))")
            }
        }
        
        return results
    }
    
    /// Creates view modifier callbacks for gesture data.
    func getSwiftUIGestureViewModifierStrings(layerViewEventMap: [UUID: [SwiftPatchViewEvent]],
                                              isStreaming: Bool) -> [String] {
        // Organize gesture data by each syntax type
        let gestureDataHere = layerViewEventMap.reduce(into: [SyntaxViewEventType : [SwiftPatchViewEvent]]()) { result, mapData in
            let (layerId, viewEvents) = mapData
            
            guard layerId == self.id else { return }
            
            viewEvents.forEach { viewEvent in
                let viewEventData = viewEvent.viewEvent
                var layerDataList = result.get(viewEventData.type) ?? []
                
                // Assuming that our code gen only makes 1 statement, allowing us to assum a state var mutation
                assertInDebug(viewEvent.codeStatements.count == 1)
                
                layerDataList.append(viewEvent)
                result.updateValue(layerDataList, forKey: viewEventData.type)
            }
        }
        
        return gestureDataHere.map { (viewEventName, viewEvents) -> String in
            switch viewEventName {
            case .dragGesture:
                let dragBindings = viewEvents.flatMap { viewData -> [String] in
                    let viewEvent = viewData.viewEvent

                    return viewData.codeStatements.map { codeData in
                        let expressionCode = codeData.1.createSwiftUICode(isStreaming: isStreaming)
                        
                        return "\(codeData.0) = [PortValueDescription(value: \(expressionCode), value_type: \"position\")]"
                    }
                }
                    .joined(separator: "\n")
                
                return """
                    .simultaneousGesture(DragGesture().onChanged { g in
                    \(dragBindings.indentLines())
                    })
                    """
            case .tapGesture:
                // Tap gesture closure is constant so no need to iterate over the full list
                assertInDebug(viewEvents.first != nil)
                let mutatedStateVar = viewEvents.first?
                    .codeStatements.first?.0 ?? "rectPulse"
                
                return """
                    .onTapGesture {
                        \(mutatedStateVar) = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                    }
                    """
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
            // Position modifier choice depends on anchoring - handled in getSwiftUIViewModifierStrings
            return nil // Special case - handled elsewhere
        case .offsetInGroup:
            return .offset
        case .layerPadding:
            return .padding
        case .isClipped:
            return .clipped
        case .textFont:
//            return decomposeFontToModifiers(stitchFont)
            return .font
            
        case .fontSize:
            // FontSize should create a font modifier when it contains PortValueDescription
            // This handles the case where fontSize comes from PortValueDescription
            return .font
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
