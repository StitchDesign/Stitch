//
//  FromLayerInputToSyntax.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation

// MARK: LayerInputPort -> SwiftUI modifier
// e.g. size -> .frame
// e.g. opacity -> .opacity


enum FromLayerInputToSyntax {
    // Simple conversion where a SwiftUI View's constr-arg corresponds to a single LayerInputPort
    // e.g. `Text(<textValue>) -> LayerInputPort.text`
    // e.g. `Image(systemName:) -> LayerInputPort.sfSymbol`
    // e.g. `Image(uiImage:) -> LayerInputPort.media`
    case constructorArgument(SyntaxViewConstructorArgument)
    
    // Simple conversion where a SwiftUI view modifier corresponds to a single LayerInputPort
    // e.g. `.scaleEffect -> LayerInputPort.scale`
    // e.g. `.opacity -> LayerInputPort.opacity`
    
    // see `mapModifierToLayerInput` for handling really simple cases like this
    case modifier(SyntaxViewModifier)
    
    case function(ConversionFunction)
}


// TODO: JUNE 24: a more complex mapping
enum ConversionFunction {
    // LayerInputPort.anchoring, which is a function of a layer size, layer position, layer anchoring and parent size
    case anchoring
}

enum VPLConversionUnsupported {
    case pinning
}


extension SyntaxView {
    /// Re‑create a `SyntaxView` hierarchy from the ordered list of
    /// `VPLLayerConcept` actions produced by `SyntaxView.deriveStitchActions()`.
    ///
    /// - Parameter actions: The action list (layer creations, input sets, incoming edges, …).
    /// - Returns: The root `SyntaxView` or `nil` when no layer‑creation action is found.
    static func build(from actions: CurrentAIPatchBuilderResponseFormat.LayerData) throws -> Self? {
//        // The very first `.layer` action produced by `deriveStitchActions()` is the root.
//        guard let rootLayer = actions.first else {
//            log("SyntaxView.build: No VPLLayer creation found – cannot rebuild view tree.")
//            return nil
//        }
//
//        return
        try node(from: actions)
    }

    // MARK: - Private helpers

    /// Recursively create a `SyntaxView` from a `VPLLayer`, using `actions`
    /// to populate constructor arguments and modifiers.
    private static func node(from layerData: CurrentAIPatchBuilderResponseFormat.LayerData) throws -> Self? {

        // TODO: provide layer group orientation
        guard let layer = layerData.node_name.value.layer,
              let migratedLayer = try? layer.convert(to: Layer.self),
              let viewName = migratedLayer.deriveSyntaxViewName() else {
            log("Stitch layer has no SwiftUI view equivalent yet?: \(layerData)")
            return nil
        }
        
        // Gather all `layerInputSet` concepts that belong to this layer.
        let customInputEvents = layerData.custom_layer_input_values

        // Convert those sets into very naïve constructor‑arguments *or* modifiers.
        // For now we treat everything as a modifier unless the corresponding
        // `LayerInputPort` is marked `.isConstructorArg` for the given layer.
        var constructorArgs: [SyntaxViewConstructorArgument] = []
        var modifiers: [SyntaxViewModifier] = []

        for inputData in customInputEvents {
//            if let viewModifierName = inputSet.input.toSwiftUIViewModifierName
            let syntaxScenario: FromLayerInputToSyntax = try inputData.layer_input_coordinate.input_port_type.value
                .toSwiftUISyntax(
                // TODO: JUNE 24: handle proper PortValue here
//                port: .value(PortValue.string(.init(inputSet.value))),
                valueOrEdge: .value(inputData.value),
                layer: layer)
            
            switch syntaxScenario {
            
            case .constructorArgument(let constructorArgument):
                constructorArgs.append(constructorArgument)
                
            case .modifier(let viewModifier):
                modifiers.append(viewModifier)
                
            case .function:
                log("unsupported or function syntaxScenario for \(inputData)")
                continue
            }
        }

        // Recurse into child layers.
        let childNodes: [Self]? = try layerData.children?
            .compactMap { try node(from: $0) }

        // Build the actual SyntaxView node.
        return Self(
            name: viewName,
            constructorArguments: constructorArgs,
            modifiers: modifiers,
            children: childNodes ?? [],
            id: layerData.node_id.value
        )
    }
}

