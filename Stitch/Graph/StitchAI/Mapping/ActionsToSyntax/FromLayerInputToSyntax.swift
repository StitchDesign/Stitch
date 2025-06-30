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
    
    // Many, many SwiftUI constructor-args and modifiers are unsupported by Stitch as of June 2025
    case unsupported
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
    static func build(from actions: VPLActionOrderedSet) -> Self? {
        // The very first `.layer` action produced by `deriveStitchActions()` is the root.
        guard let rootConcept = actions.first(where: {
            if case .layer = $0 { return true } else { return false }
        }),
            case let .layer(rootLayer) = rootConcept
        else {
            log("SyntaxView.build: No VPLLayer creation found – cannot rebuild view tree.")
            return nil
        }

        return node(from: rootLayer, in: actions)
    }

    // MARK: - Private helpers

    /// Recursively create a `SyntaxView` from a `VPLLayer`, using `actions`
    /// to populate constructor arguments and modifiers.
    private static func node(from layer: VPLCreateNode,
                             in actions: VPLActionOrderedSet) -> Self? {

        // TODO: provide layer group orientation
        guard let viewName = layer.name.deriveSyntaxViewName() else {
            log("Stitch layer has no SwiftUI view equivalent yet?: \(layer)")
            return nil
        }
        
        // Gather all `layerInputSet` concepts that belong to this layer.
        let inputsSet: [VPLSetInput] = actions.compactMap {
            if case let .layerInputSet(set) = $0,
               set.id == layer.id {
                return set
            }
            return nil
        }

        // Convert those sets into very naïve constructor‑arguments *or* modifiers.
        // For now we treat everything as a modifier unless the corresponding
        // `LayerInputPort` is marked `.isConstructorArg` for the given layer.
        var constructorArgs: [SyntaxViewConstructorArgument] = []
        var modifiers: [SyntaxViewModifier] = []

        for inputSet in inputsSet {
//            if let viewModifierName = inputSet.input.toSwiftUIViewModifierName
            let syntaxScenario: FromLayerInputToSyntax = inputSet.input.toSwiftUISyntax(
                // TODO: JUNE 24: handle proper PortValue here
//                port: .value(PortValue.string(.init(inputSet.value))),
                valueOrEdge: .value(inputSet.value),
                layer: layer.name)
            
            switch syntaxScenario {
            
            case .constructorArgument(let constructorArgument):
                constructorArgs.append(constructorArgument)
                
            case .modifier(let viewModifier):
                modifiers.append(viewModifier)
                
            case .unsupported, .function:
                log("unsupported or function syntaxScenario for \(inputSet)")
                continue
            }
        }

        // Recurse into child layers.
        let childNodes: [Self] = layer.children.compactMap { node(from: $0, in: actions) }

        // Build the actual SyntaxView node.
        return Self(
            name: viewName,
            constructorArguments: constructorArgs,
            modifiers: modifiers,
            children: childNodes,
            id: layer.id
        )
    }
}

