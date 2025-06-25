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
