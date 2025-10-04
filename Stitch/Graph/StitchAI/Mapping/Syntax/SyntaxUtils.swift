//
//  StitchSyntaxHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/25.
//

import Foundation

 
func nilOrDebugCrash<T>() -> T? {
    fatalErrorIfDebug()
    return nil
}


// Nicely formats the nested enum so we can print it in one line
private func describe(_ kind: SyntaxArgumentKind) -> String {
    switch kind {
    case .literal(let lit):     return "literal(\(lit))"
    case .variable(let varKind): return "variable(\(varKind))"
    case .expression(let expr): return "expression(\(expr))"
    }
}

extension SyntaxViewArgumentData {
    var description: String {
        describe(self)
    }
}

extension SyntaxViewModifierArgumentType {
    var description: String {
        switch self {
        case .simple(let data):
            return "\(data)"
            
        case .memberAccess(let data):
            return data.trimmedDescription
            
        case .stateAccess(let x):
            return x
            
        case .tuple(let args):
            return args.map(\.description).joined(separator: ", ")
            
        case .array(let args):
            return args.map(\.description).joined(separator: ", ")
        
        case .complex(let type):
            return "\(type)"
            
        case .closure(let script):
            return "\(script)"
        
        case .viewEvent(let viewEvent):
            return "\(viewEvent)"

        case .view(let x):
            return "\(x)"

        case .mathExpression(let x):
            return x.description
        }
    }
}

/// Nicely formats a `SyntaxViewModifierArgumentType` so that we don't dump the
/// full struct/enum hierarchy when printing.
/// Formats the `(value, syntaxKind)` pair in a compact way
func describe(_ data: SyntaxViewArgumentData) -> String {
    "\(data.value))" //, \(describe(data.syntaxKind))"
}

func describe(_ argType: SyntaxViewModifierArgumentType) -> String {
    switch argType {
    case .simple(let data):
        return "simple(\(data))"
        
    case .memberAccess(let data):
        return "memberAccess(\(data))"
        
    case .stateAccess(let x):
        return "state access: \(x)"
        
    case .tuple(let args):
        return "tuple(\(args.map(describe(_:)).joined(separator: ", ")))"
        
    case .array(let args):
        return "array(\(args.map(describe(_:)).joined(separator: ", ")))"
    
    case .complex(let type):
        // TODO: better label for describe
        return type.typeName
        
    case .closure(let script):
        return "closure(\(script))"
    
    case .viewEvent(let viewEvent):
        return viewEvent.eventName
    
    case .view(let view):
        // TODO: revisit this?
        return view.name

    case .mathExpression(let x):
        return x.description
    }
}

// Formats a ViewNode into a readable string representation - top level so it can be reused
func formatSyntaxView(_ node: SyntaxView, indent: String = "") -> String {
    var result = "\(indent)SyntaxView("
    result += "\n\(indent)    name: \"\(node.name)\","
    
    let argsString = node.constructorArguments?.description ?? ""
    let modifiersString = "\(node.modifiers)"
    
    // Format arguments
    result += "\n\(indent)    constructorArguments: \n\(argsString)"
    
    // Format modifiers
    result += "\n\(indent)    modifiers: \n\(modifiersString)"
    
    // Format children recursively
    result += "\n\(indent)    children: ["
    if !node.children.isEmpty {
        for (i, child) in node.children.enumerated() {
            result += "\n" + formatSyntaxView(child, indent: indent + "        ")
            if i < node.children.count - 1 {
                result += ","
            }
        }
        result += "\n\(indent)    ],"
    } else {
        result += "],"
    }
    
    // Add ID
    result += "\n\(indent)    id: \"\(node.id)\""
    result += "\n\(indent))"
    
    return result
}
