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

/// Nicely formats a `SyntaxViewModifierArgumentType` so that we don't dump the
/// full struct/enum hierarchy when printing.
/// Formats the `(value, syntaxKind)` pair in a compact way
private func describe(_ data: SyntaxViewArgumentData) -> String {
    "\(data.value))" //, \(describe(data.syntaxKind))"
}

private func describe(_ argType: SyntaxViewModifierArgumentType) -> String {
    switch argType {
    case .simple(let data):
        return "simple(\(data))"
        
    case .memberAccess(let data):
        return "memberAccess(\(data))"
        
    case .tuple(let args):
        return "tuple(\(args.map(describe(_:)).joined(separator: ", ")))"
        
    case .array(let args):
        return "array(\(args.map(describe(_:)).joined(separator: ", ")))"
    
    case .complex(let type):
        // TODO: better label for describe
        return type.typeName
    }
}

// Formats a ViewNode into a readable string representation - top level so it can be reused
func formatSyntaxView(_ node: SyntaxView, indent: String = "") -> String {
    var result = "\(indent)SyntaxView("
    result += "\n\(indent)    name: \"\(node.name.rawValue)\","
    
    // Format arguments
    result += "\n\(indent)    constructorArguments: ["
    if !node.constructorArguments.isEmpty {
        for (i, arg) in node.constructorArguments.enumerated() {
            let label = "\(arg.label ?? "none")"
            let valuesDesc = arg.value //values.map { "(\($0.value), \(describe($0.syntaxKind)))" }.joined(separator: ", ")
            result += "\n\(indent)        (label: \(label), values: [\(valuesDesc)])"
            if i < node.constructorArguments.count - 1 {
                result += ","
            }
        }
        result += "\n\(indent)    ],"
    } else {
        result += "],"
    }
    
    // Format modifiers
    result += "\n\(indent)    modifiers: ["
    if !node.modifiers.isEmpty {
        for (i, modifier) in node.modifiers.enumerated() {
            result += "\n\(indent)        SyntaxViewModifier("
            result += "\n\(indent)            name: \(modifier.name.rawValue),"
            // value field removed
            // Format modifier arguments
            result += "\n\(indent)            arguments: ["
            if !modifier.arguments.isEmpty {
                for (j, arg) in modifier.arguments.enumerated() {
                    let labelDesc = arg.label == nil ? "" : "\"\(arg.label!)\""
                    let valueDesc = describe(arg.value)
                    result += "\n\(indent)                (label: \(labelDesc), value: \(valueDesc))"
                    if j < modifier.arguments.count - 1 {
                        result += ","
                    }
                }
                result += "\n\(indent)            ]"
            } else {
                result += "]"
            }
            result += "\n\(indent)        )"
            if i < node.modifiers.count - 1 {
                result += ","
            }
        }
        result += "\n\(indent)    ],"
    } else {
        result += "],"
    }
    
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
