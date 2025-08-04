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
    let rootView: SyntaxView?
    let bindingDeclarations: [String : SwiftParserInitializerType]
    let caughtErrors: [SwiftUISyntaxError]
}

enum SwiftParserPatternBindingArg {
    case value(SyntaxViewModifierArgumentType)
    case binding(DeclReferenceExprSyntax)
    case subscriptRef(SwiftParserSubscript)
}

struct SwiftParserPatchData {
    let id: String
    var patchName: String
    var args: [SwiftParserPatternBindingArg]
}

struct SwiftParserSubscript: Sendable {
    // The name of the variable
    var subscriptType: SwiftParserSubscriptType
    var portIndex: Int
}

enum SwiftParserInitializerType {
    // creates some patch node from a declared function
    case patchNode(SwiftParserPatchData)
    
    // access an index of some node's outputs
    case subscriptRef(SwiftParserSubscript)
    
    // initializes state
//    case stateVarName
    
    // mutates some existing state
    case stateMutation(SwiftParserStateMutation)
}

enum SwiftParserStateMutation: Sendable {
    case declrRef(String)
    case subscriptRef(SwiftParserSubscript)
}

// Subscripts can be used on references or nodes themselves
enum SwiftParserSubscriptType {
    case ref(String)
    case patchNode(SwiftParserPatchData)
}
