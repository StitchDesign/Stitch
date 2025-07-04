//
//  deriveLayer.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import StitchSchemaKit
import SwiftUI

extension SyntaxViewName {
    
    /// Leaf-level mapping for **this** node only
    func deriveLayerData(id: UUID,
                         args: [SyntaxViewConstructorArgument],
                         modifiers: [SyntaxViewModifier],
                         childrenLayers: [CurrentAIPatchBuilderResponseFormat.LayerData]) throws -> CurrentAIPatchBuilderResponseFormat.LayerData {

        // ── Base mapping from SyntaxViewName → Layer ────────────────────────
        var (layerType, layerData) = try self
            .deriveLayerAndCustomValuesFromName(id: id,
                                                args: args,
                                                childrenLayers: childrenLayers)
        
        // Handle constructor-arguments
        let customInputValues = self.deriveCustomValuesFromConstructorArguments(
            id: id,
            layerType: layerType,
            args: args)
        
        // Handle modifiers
        let customModifierEvents = try Self.deriveCustomValuesFromViewModifiers(
            id: id,
            layerType: layerType,
            modifiers: modifiers)
        
        layerData.custom_layer_input_values += customInputValues
        
        // Parse view modifier events
        for modifierEvent in customModifierEvents {
            switch modifierEvent {
            case .layerInputValues(let valuesList):
                layerData.custom_layer_input_values += valuesList
            case .layerIdAssignment(let string):
                guard let uuidValue = UUID(uuidString: string) else {
                    throw SwiftUISyntaxError.layerUUIDDecodingFailed(string)
                }
                
                // Update ID to that assigned from view
                layerData.node_id = .init(value: uuidValue)
            }
        }
        
        // Re-map all node IDs after processing layerIdAssignment
        layerData.custom_layer_input_values = layerData.custom_layer_input_values
            .map { customInputValue in
                var customInputValue = customInputValue
                customInputValue.layer_input_coordinate.layer_id = layerData.node_id
                return customInputValue
            }
        
        return layerData
    }
    
    func deriveLayerAndCustomValuesFromName(
        id: UUID,
        args: [SyntaxViewConstructorArgument],
        childrenLayers: [CurrentAIPatchBuilderResponseFormat.LayerData]
    ) throws -> (CurrentStep.Layer, CurrentAIPatchBuilderResponseFormat.LayerData) {
        
        var layerType: CurrentStep.Layer
        var customValues: [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue] = []
        
        switch self {
        case .rectangle:         layerType = .rectangle
            
            // Note: Swift Circle is a little bit different
        case .circle, .ellipse:  layerType = .oval
            
            // SwiftUI Text view has different arg-constructors, but those do not change the Layer we return
        case .text: layerType = .text
            
            // SwiftUI TextField view has different arg-constructors, but those do not change the Layer we return
        case .textField: layerType = .textField
            
        case .image:
            switch args.first?.label {
            case .systemName: layerType = .sfSymbol
            default: layerType = .image
            }
            
        case .map: layerType = .map
            
            // Revisit these
        case .videoPlayer: layerType = .video
        case .model3D: layerType = .model3D
            
        case .linearGradient: layerType = .linearGradient
        case .radialGradient: layerType = .radialGradient
        case .angularGradient: layerType = .angularGradient
        case .material: layerType = .material
            
            // TODO: JUNE 24: what actually is SwiftUI sketch ?
        case .canvas: layerType = .canvasSketch
            
        case .secureField:
            // TODO: JUNE 24: ought to return `(Layer.textField, LayerInputPort.keyboardType, UIKeyboardType.password)` ? ... so a SwiftUI View can correspond to more than just a Layer ?
            layerType = .textField
            
            // TODO: JUNE 24: current Step_V0 doesn't support keyboard ?
            //            customValues.append(
            //                .init(id: id,
            //                      input: .keyboardType,
            //                      value: .keyboardType(.password))
            //            )
            
        case .scrollView:
            let layerData = try Self
                .createScrollGroupLayer(args: args,
                                        childrenLayers: childrenLayers)
            return (.group, layerData)
            
            // MARK: CONTAINER VIEWS
            
        case .hStack, .lazyHStack:
            layerType = .group
            customValues.append(
                .init(id: id,
                      input: .orientation,
                      value: .orientation(.horizontal))
            )
            
        case .vStack, .lazyVStack:
            layerType = .group
            customValues.append(
                .init(id: id,
                      input: .orientation,
                      value: .orientation(.vertical))
            )
            
        case .zStack:
            layerType = .group
            customValues.append(
                .init(id: id,
                      input: .orientation,
                      value: .orientation(.none))
            )
            
            // TODO: JULY 3: technically, we don't support `LazyHGrid` and `Grid`?
        case .lazyVGrid, .lazyHGrid, .grid:
            layerType = .group
            customValues.append(
                .init(id: id,
                      input: .orientation,
                      value: .orientation(.grid))
            )
            
            
        case .toggle:
            layerType = .switchLayer
            
        case .progressView:
            layerType = .progressIndicator
            
            // MARK: views / layers we likely want to support ?
        case .spacer:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .divider:
            throw SwiftUISyntaxError.unsupportedLayer(self)
            
        case .color:
            throw SwiftUISyntaxError.unsupportedLayer(self) // both Layer.hitArea AND Layer.colorFill
            
            // MARK: views we may never support? Either because inferred or some other dynamic
            
            
        case .capsule,
                .path,
                .label,
                .asyncImage,
                .symbolEffect,
                .geometryReader,
                .alignmentGuide,
                .list,
                .table,
                .outlineGroup,
            
            // Never really supported? Instead just inferred.
                .forEach,
            
            // Just specifies that modifiers on the SwiftUI Group are meant to be applied to every view inside ?
                .group,
                .navigationStack,
                .navigationSplit,
                .navigationLink,
                .tabView,
                .form,
                .section,
                .button,
                .slider,
                .stepper,
                .picker,
                .datePicker,
                .gauge,
                .link,
                .timelineView,
                .anyView,
                .preview,
                .timelineSchedule:
            throw SwiftUISyntaxError.unsupportedLayer(self)
            
        case .roundedRectangle:
            layerType = .rectangle
            if let arg = args.first(where: { $0.label == .cornerRadius }),
               let firstValue = arg.values.first,
               let radius = Double(firstValue.value) {
                customValues.append(
                    .init(id: id,
                          input: .cornerRadius,
                          value: .number(radius))
                )
            }
        }
        
        // Final bare layer (children added later)
        var layerNode = CurrentAIPatchBuilderResponseFormat
            .LayerData(node_id: .init(value: id),
                       node_name: .init(value: .layer(layerType)),
                       custom_layer_input_values: customValues)
        
        if !childrenLayers.isEmpty {
            layerNode.children = childrenLayers
        }
        
        return (layerType, layerNode)
    }
    
    func deriveCustomValuesFromConstructorArguments(
        id: UUID,
        layerType: CurrentStep.Layer,
        args: [SyntaxViewConstructorArgument]) -> [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue] {
            
            var customValues = [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue]()
            
            // ── Generic constructor‑argument handling (literals & edges) ─────────
            for arg in args {
                
                // TODO: why are we skipping these ? Because we already handled them when handling SwiftUI RoundedRectangle ? ... Can we have a smarter, more programmatic skipping logic here? Or just allow ourselves to create the redundant action, which as an Equatable/Hashable in a set can be ignored ?
                // Skip the specialised RoundedRectangle .cornerRadius
                if self == .roundedRectangle && arg.label == .cornerRadius { continue }
                
                guard let port = arg.deriveLayerInputPort(layerType),
                      let portValue = arg.derivePortValue(layerType) else { continue }
                
                // Process each value in the argument
                for value in arg.values {
                    switch value.syntaxKind {
                    case .literal:
                        customValues.append(
                            .init(id: id,
                                  input: port,
                                  value: portValue)
                        )
                    case .variable, .expression:
                        // Skip variables for edges, using AI instead
                        continue
                        //                    extras.append(.createEdge(VPLCreateEdge(name: port)))
                    }
                }
            } // for arg in args
            
            return customValues
        }
    
    static func deriveCustomValuesFromViewModifiers(
        id: UUID,
        layerType: CurrentStep.Layer,
        modifiers: [SyntaxViewModifier]) throws -> [LayerInputViewModification] {
            try modifiers.map { modifier in
                try Self.deriveCustomValuesFromViewModifier(
                    id: id,
                    layerType: layerType,
                    modifier: modifier)
            }
    }
    
    private static func deriveCustomValuesFromViewModifier(
        id: UUID,
        layerType: CurrentStep.Layer,
        modifier: SyntaxViewModifier) throws -> LayerInputViewModification {
        let derivationResult = try modifier.name.deriveLayerInputPort(layerType)
        
        switch derivationResult {
        case .simple(let port):
            let newValues = try Self.deriveCustomValuesFromSimpleLayerInputTranslation(
                id: id,
                port: port,
                layerType: layerType,
                modifier: modifier)
            
            return .layerInputValues(newValues)
            
        case .rotationScenario:
            // Certain modifiers, e.g. `.rotation3DEffect` correspond to multiple layer-inputs (.rotationX, .rotationY, .rotationZ)
            let newValues = try Self.deriveCustomValuesFromRotationLayerInputTranslation(
                id: id,
                layerType: layerType,
                modifier: modifier)
            
            return .layerInputValues(newValues)
            
        case .layerId:
            guard let rawValue = modifier.arguments.first?.value.simpleValue else {
                throw SwiftUISyntaxError.unsupportedLayerIdParsing(modifier.arguments)
            }
            // Remove escape characters from any quoted substrings
            let unescaped = rawValue.replacingOccurrences(of: "\\\"", with: "\"")
            // Trim any surrounding quotes
            let cleanString = unescaped.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return .layerIdAssignment(cleanString)
        }
    }
    
    static func deriveCustomValuesFromSimpleLayerInputTranslation(
        id: UUID,
        port: CurrentStep.LayerInputPort, // simple because we have a single layer
        layerType: CurrentStep.Layer,
        modifier: SyntaxViewModifier
    ) throws -> [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue] {
        
        var customValues = [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue]()
        
        let migratedPort = try port.convert(to: LayerInputPort.self)
        let migratedLayerType = try layerType.convert(to: Layer.self)
        
        // Start with default value for that port
        var portValue: PortValue = migratedPort.getDefaultValue(for: migratedLayerType)
        
        // Process each argument based on its type
        
        // index for modifier-arguments might not always be correct ?
        
        for (idx, arg) in modifier.arguments.enumerated() {
            
            switch arg.value {
                
            case .angle, .axis:
                fatalErrorIfDebug("Only intended for rotation3DEffect case")
                throw SwiftUISyntaxError.incorrectParsing(message: ".degrees and .axis are only for the rotation layer-inputs derivation")
                
                // Handles types like PortValueDescription
            case .complex(let complexType):
                let complexTypeName = SyntaxValueName(rawValue: complexType.typeName)
                switch complexTypeName {
                case .none:
                    throw SwiftUISyntaxError.unsupportedComplexValueType(complexType.typeName)
                    
                case .portValueDescription:
                    guard let valueArg = complexType.arguments.first(where: { $0.label?.text == "value" }),
                          let valueTypeArg = complexType.arguments.first(where: { $0.label?.text == "value_type" }) else {
                        throw SwiftUISyntaxError.portValueDataDecodingFailure
                    }
                    let valueStr = valueArg.expression.trimmedDescription
                    let valueTypeStr = valueTypeArg.expression.trimmedDescription
    
                    // TODO: come back here!
                }
                
            case .simple(let data):
                // Tricky color case, for Color.systemName etc.
                if let color = Color.fromSystemName(data.value) {
                    let input = PortValue.string(.init(color.asHexDisplay))
                    let coerced = [input].coerce(to: portValue, currentGraphTime: .zero)
                    if let coercedToColor = coerced.first {
                        portValue = coercedToColor
                    } else {
                        fatalErrorIfDebug("Should not have failed to coerce color ")
                    }
                }

                // Simple, non-color case
                else {
                    portValue = portValue.parseInputEdit(
                        fieldValue: .string(.init(data.value)),
                        fieldIndex: idx)
                }
            }
            
        } // for (idx, arg) in ...
        
        
        // Important: save the `customValue` event *at the end*, after we've iterated over all the arguments to this single modifier
        customValues.append(try .init(id: id,port: port, value: portValue))
        
        return customValues
    }
    
    static func deriveCustomValuesFromRotationLayerInputTranslation(
        id: UUID,
        layerType: CurrentStep.Layer,
        modifier: SyntaxViewModifier) throws -> [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue] {
        
        var customValues = [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue]()
        
        
        guard let angleArgument = modifier.arguments[safe: 0],
              // TODO: JULY 2: could be degrees OR radians; Stitch currently only supports degrees
              case .angle(let degreesOrRadians) = angleArgument.value else {
            
            //#if !DEV_DEBUG
            throw SwiftUISyntaxError.incorrectParsing(message: "Unable to parse rotation layer inputs correctly")
            //#endif
        }
        
        
        // degrees = *how much* we're rotating the given rotation layer input
        // axes = *which* layer input (rotationX vs rotationY vs rotationZ) we're rotating
        let fn = { (port: CurrentStep.LayerInputPort) in
            let portValue = try port
                .getDefaultValue(layerType: layerType)
                .parseInputEdit(fieldValue: .string(.init(degreesOrRadians.value)),
                                fieldIndex: 0)
            
            customValues.append(try .init(id: id, port: port, value: portValue))
        }
        
        // i.e. viewModifier was .rotation3DEffect, since it had an `axis:` argument
        if let axesArgument = modifier.arguments[safe: 1],
           
            // Note: `axisX` could be a number-literal, which we can test as >0 here -- or it could be a variable, which we cannot test.
           // We only want to provide `degrees` (e.g. `60` or `x`) if the axis is greater than 1; otherwise we end up with unwanted
            
            // Ah! Hold on -- if we have an incoming edge (i.e. a variable), then we won't have to create a custom_value; we would create an `incoming_edge` case instead;
            // this incoming edge will then determine whether we apply the degrees or not --
            // ... right, what is the proper way to think about incoming edges here?
            // at the
            
            // what about expressions too, which have no incoming edges (i.e variables), e.g.  1+1 ?
            // actually -- anything that's not a literal is considered an incoming edge
            
            
            case .axis(let axisX, let axisY, let axisZ) = axesArgument.value,
           
            // TODO: JULY 2: what if we have e.g. `axes: (x: myVar, y: 0, z: 0)` instead of just literal? ... in that case, the `x: myVar` would be an incoming_edge, not a custom_value ?
           let axisX = toNumber(axisX.value),
           let axisY = toNumber(axisY.value),
           let axisZ = toNumber(axisZ.value) {
            
            if axisX > 0 {
                try fn(.rotationX)
            }
            if axisY > 0 {
                try fn(.rotationY)
            }
            if axisZ > 0 {
                try fn(.rotationZ)
            }
        }
        
        // i.e. viewModifier was .rotationEffect, since it did not have an `axis:` argument
        else {
            try fn(.rotationZ)
        }
        
        return customValues
    }
}

extension CurrentStep.LayerInputPort {
    func getDefaultValue(layerType: CurrentStep.Layer) throws -> PortValue {
        
#if DEV_DEBUG
        let migratedPort = try! self.convert(to: LayerInputPort.self)
        let migratedLayerType = try! layerType.convert(to: Layer.self)
#else
        let migratedPort = try self.convert(to: LayerInputPort.self)
        let migratedLayerType = try layerType.convert(to: Layer.self)
#endif
        
        // Start with default value for that port
        return migratedPort.getDefaultValue(for: migratedLayerType)
    }
}

extension CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue {
    
    init(id: UUID,
         port: CurrentStep.LayerInputPort,
         value: PortValue) throws {
        
        // "Downgrade" PortValue back to supported type for the AI
#if DEV_DEBUG
        let downgradedValue = try! value.convert(to: CurrentStep.PortValue.self)
#else
        let downgradedValue = try value.convert(to: CurrentStep.PortValue.self)
#endif
        
        self.init(id: id,
                  input: port,
                  value: downgradedValue)
    }
}
