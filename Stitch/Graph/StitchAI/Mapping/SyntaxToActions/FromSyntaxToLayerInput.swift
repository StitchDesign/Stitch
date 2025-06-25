//
//  FromSyntaxToLayerInput.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation

/*
a couple things you want to know:
- I want a "create layer" action. What do I need to know, from the ViewNode?
- I want a "set layer input" action. What do I need to know, from the ViewNode?
*/

/*
 Note: a ViewNode's core view (`name`) is either supported by Stitch (= a Layer) or not; if not, we return nil from `viewNode.deriveLayer` and do not process any of its modifiers, constructor-args or children.
 
 However, mapping between ViewNode's constructor-args and modifiers to Stitch Layer Inputs is more complicated.
 */

// TODO: maybe don't need these enums below? but a good way to understand how to convert between LayerInput and various parts of ViewNode


// Whether a given LayerInput corresponds to a ViewNode constructor-arg, a ViewNode modifier, or something much more complicated (e.g. pinning);
enum FromSyntaxToLayerInput {
    // Simple conversions like `LayerInputPort.text -> Text(<textValue>)`
    case constructorArgument(SyntaxConstructorArgumentLabel)
    
    // Simple conversions like `LayerInputPort.scale -> .scaleEffect`
    case modifier(SyntaxViewModifierName)
        
    //  When the LayerInputPort corresponds to something more complicated than a single SwiftUI view modifier or single SwiftUI view constructor
    // e.g. LayerInputPort.anchoring, which is a function of a layer size, layer position, layer anchoring and parent size
    case function
    
    // Heavier business logic cases that have no clear "SwiftUI code <-> VPL steps" equivalent, e.g. pinning;
    // if the mapping function returns `nil`, then the conversion is unsupported.
    case unsupported
}
