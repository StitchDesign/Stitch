//
//  CodeToStitchModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/31/25.
//

import SwiftSyntax
import SwiftParser
import SwiftSyntaxBuilder
import SwiftUI

struct SwiftUIViewParserResult {
    let viewStack: [SyntaxView]
    let bindingDeclarations: [String : SwiftParserInitializerType]
    let caughtErrors: [SwiftUISyntaxError]
}

enum SwiftParserPatternBindingArg {
    case value(SyntaxViewModifierArgumentType)
    case binding(String)
    case subscriptRef(SwiftParserSubscript)
}

//extension SwiftParserPatternBindingArg: Encodable {
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        switch self {
//        case .value(let value):
//            try container.encode(value)
//        case .binding(let value):
//            try container.encode(value.trimmedDescription)
//        case .subscriptRef(let value):
//            try container.encode(value)
//        }
//    }
//}

struct SwiftParserPatchData {
    let id: String
    var patchType: SwiftParserPatchType
    var args: [SwiftParserPatternBindingArg]
}

enum SwiftParserPatchType: Encodable {
    case native(String)
    case js(String)
}

struct SwiftParserSubscript: Sendable {
    // The name of the variable
    var subscriptType: SwiftParserSubscriptType
    var portIndex: Int
}

indirect enum SwiftParserInitializerType: Sendable {
    // creates some patch node from a declared function
    case patchNode(SwiftParserPatchData)
    
    // access an index of some node's outputs
    case subscriptRef(SwiftParserSubscript)
    
    // makes a ref to a patch node function
    case patchNodeRef(String)
    
    case declrRef(String)

    // mutates some existing state
    case stateMutation(SwiftParserInitializerType)
    
    // js nodes
    case jsNodeScript(String)
    
    // view builder functions (script in value)
    case viewBuilder(String)
    
    case arraySyntax(ArrayExprSyntax)
}

// Subscripts can be used on references or nodes themselves
enum SwiftParserSubscriptType {
    case ref(String)
    case patchNode(SwiftParserPatchData)
}

extension SwiftParserInitializerType {
    var subscriptRef: SwiftParserSubscript? {
        switch self {
        case .subscriptRef(let swiftParserSubscript):
            return swiftParserSubscript
        default:
            return nil
        }
    }
    
    var patchNodeRef: String? {
        switch self {
        case .patchNodeRef(let ref):
            return ref
        default:
            return nil
        }
    }
    
    var viewBuilderScript: String? {
        switch self {
        case .viewBuilder(let script):
            return script
            
        default:
            return nil
        }
    }
}
