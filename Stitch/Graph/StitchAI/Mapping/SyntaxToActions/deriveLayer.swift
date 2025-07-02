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
        let customModifierValues = try Self.deriveCustomValuesFromViewModifiers(
            id: id,
            layerType: layerType,
            modifiers: modifiers)

        layerData.custom_layer_input_values += customInputValues
        layerData.custom_layer_input_values += customModifierValues
        
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
            
        case .scrollView:
            let layerData = try Self
                .createScrollGroupLayer(args: args,
                                        childrenLayers: childrenLayers)
            return (.group, layerData)
            
        case .capsule:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .path:
            throw SwiftUISyntaxError.unsupportedLayer(self) // Canvas sketch ?
        case .color:
            throw SwiftUISyntaxError.unsupportedLayer(self) // both Layer.hitArea AND Layer.colorFill
            
        case .label:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .asyncImage:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .symbolEffect:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .group:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .spacer:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .divider:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .geometryReader:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .alignmentGuide:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .list:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .table:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .outlineGroup:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .forEach:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .navigationStack:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .navigationSplit:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .navigationLink:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .tabView:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .form:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .section:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .button:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .toggle:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .slider:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .stepper:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .picker:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .datePicker:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .gauge:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .progressView:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .link:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .timelineView:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .anyView:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .preview:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .timelineSchedule:
            throw SwiftUISyntaxError.unsupportedLayer(self)

        // TODO: JUNE 26: handle incoming edges as well
        // Views that create a set-input as well
            
        case .hStack:
            layerType = .group
            customValues.append(
                .init(id: id,
                      input: .orientation,
                      value: .orientation(.horizontal))
            )

        case .vStack:
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

        // TODO: handle these? `lazyVStack` is a LayerGroup with grid orientation
        case .lazyVStack, .lazyHStack, .lazyVGrid, .lazyHGrid, .grid:
            throw SwiftUISyntaxError.unsupportedLayer(self)
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
        modifiers: [SyntaxViewModifier]) throws -> [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue] {
        
        var customValues = [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue]()
        
        for modifier in modifiers {
            customValues = try deriveCustomValuesFromViewModifier(
                id: id,
                layerType: layerType,
                modifier: modifier,
                customValues: customValues)
        }
        
        return customValues
    }
    
    private func deriveCustomValuesFromViewModifier(
        id: UUID,
        layerType: CurrentStep.Layer,
        modifier: SyntaxViewModifier,
        customValues: [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue]
    ) throws -> [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue] {
        
        var customValues = customValues
        
        guard let derivationResult = modifier.name.deriveLayerInputPort(layerType) else {
            throw SwiftUISyntaxError.unexpectedViewModifier(modifier.name)
        }
        
        switch derivationResult {
            
        case .simple(let port):
            customValues = try self.deriveCustomValuesFromSimpleLayerInputTranslation(
                id: id,
                port: port,
                layerType: layerType,
                modifier: modifier,
                customValues: customValues)
            
        case .rotationScenario:
            // Certain modifiers, e.g. `.rotation3DEffect` correspond to multiple layer-inputs (.rotationX, .rotationY, .rotationZ)
            customValues = try self.deriveCustomValuesFromRotationLayerInputTranslation(
                id: id,
                layerType: layerType,
                modifier: modifier,
                customValues: customValues)
        }
        
        return customValues
    }
    
    func deriveCustomValuesFromSimpleLayerInputTranslation(
        id: UUID,
        port: CurrentStep.LayerInputPort, // simple because we have a single layer
        layerType: CurrentStep.Layer,
        modifier: SyntaxViewModifier,
        customValues: [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue]
    ) throws -> [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue] {
        
        var customValues = customValues
        
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
    
    func deriveCustomValuesFromRotationLayerInputTranslation(
        id: UUID,
        layerType: CurrentStep.Layer,
        modifier: SyntaxViewModifier,
        customValues: [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue]
    ) throws -> [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue] {
        
        var customValues = customValues
        
        
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
