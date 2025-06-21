//
//  StitchSyntaxHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/25.
//

import Foundation

 
// Formats a ViewNode into a readable string representation - top level so it can be reused
func formatViewNode(_ node: ViewNode, indent: String = "") -> String {
    var result = "\(indent)ViewNode("
    result += "\n\(indent)    name: \"\(node.name)\","
    
    // Format arguments
    result += "\n\(indent)    arguments: ["
    if !node.arguments.isEmpty {
        for (i, arg) in node.arguments.enumerated() {
            let label = arg.label != nil ? "\"\(arg.label!)\"" : "nil"
            result += "\n\(indent)        (label: \(label), value: \(arg.value))"
            if i < node.arguments.count - 1 {
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
            result += "\n\(indent)        Modifier("
            result += "\n\(indent)            name: \"\(modifier.name)\","
            result += "\n\(indent)            value: \"\(modifier.value)\","
            
            // Format modifier arguments
            result += "\n\(indent)            arguments: ["
            if !modifier.arguments.isEmpty {
                for (j, arg) in modifier.arguments.enumerated() {
                    let label = arg.label != nil ? "\"\(arg.label!)\"" : "nil"
                    result += "\n\(indent)                (label: \(label), value: \"\(arg.value)\")"
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
            result += "\n" + formatViewNode(child, indent: indent + "        ")
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
