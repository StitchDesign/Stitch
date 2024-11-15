//
//  MathExpressionNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/20/24.
//

import Foundation
import StitchSchemaKit
import SoulverCore
import SwiftUI
import OrderedCollections

// TODO: not thread-safe?
let MathExpressionSoulver: SoulverCore.Calculator = .init(customization: .standard)

struct MathExpressionPatchNode: PatchNodeDefinition {
    static let patch = Patch.mathExpression

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        // Math Expression node has no inputs or outputs when first created
        .init(inputs: [], 
              outputs: [.init(label: "",
                              type: .number)])
    }
}

@MainActor
func mathExpressionEval(node: PatchNode) -> EvalResult {
 
    let labels = node.getAllInputsObservers().map { $0.label() }
    
    guard let patchNode = node.patchNode,
          let formula = patchNode.mathExpression else {
        log("mathExpressionEval: no math expression on node \(node.id)")
        return .init(outputsValues: node.outputs)
    }
    
    let op: Operation = { values -> PortValue in
                
        // the [("a", 5), ("b", 6)] etc. VariablesList Soulver expects
        let variables = values.enumerated().map {
            let label = labels[safe: $0.offset] ?? ""
            let value = ($0.element.getNumber ?? .zero).description
            return Variable(name: label, value: value)
        }
        
        // log("mathExpressionEval: variables: \(variables)")
        // log("mathExpressionEval: formula: \(formula)")
        
        let s = MathExpressionSoulver
            .calculate(formula, 
                       with: VariableList(variables: variables))
            .stringValue
        
        // log("mathExpressionEval: s: \(s)")
        
        let n: Double = Double(s) ?? .zero
        
        return .number(n)
    }
    
    return .init(outputsValues: resultsMaker(node.inputs)(op))
}

// Can disable certain formula words, if we want:
// https://soulverteam.github.io/SoulverCore/documentation/soulvercore/enginefeatureflags

// https://documentation.soulver.app/functions/functions
let soulverSupportedOperations: Set<String> = .init([
    // Roots
    "sqrt", "cbrt", "root", "of",
    
    // Logs, Base
    "exp", "ln", "log2", "log", "log10", "base",
    
    // Trig
     "sin", "sinh", "asinh", "cos", "cosh", "acosh", "tan", "tanh", "atanh",
    
    // Inverse trig
    "asin", "acos", "atan",
    
    // Other
    "abs", "fact"
])

// https://stackoverflow.com/questions/27236505/extract-a-whole-word-from-string-in-swift
extension String {
    func getUniqueWords() -> OrderedSet<String> {
        var acc = OrderedSet<String>()
        self.enumerateSubstrings(in: self.startIndex...,
                                   options: .byWords) { substring, _, _, stop in
            if let word = substring {
                acc.append(word)
            }
        }
        return acc
    }
    
    func isSoulverSupportedOperation() -> Bool {
        soulverSupportedOperations.contains(self)
    }
    
    func getSoulverVariables() -> OrderedSet<String> {
        var s = self.getUniqueWords()
        // remove Soulver-supported operations like "cos", "tan" etc.
        s.removeAll { $0.isSoulverSupportedOperation() }
        
        // remove numbers, e.g. "1" cannot be a variable name
        s.removeAll { $0.isNumber }
        
        return s
    }
}

extension String {
    var isNumber: Bool {
        return self.range(
            of: "^[0-9]*$", // 1
            options: .regularExpression) != nil
    }
}

//struct SoulverFormula_REPL: View {
//    
//    // Each of these should
//    let f1 = "a + b + c"
//    let f2 = "apple + banana + c"
//    let f3 = "apple + banana + cocounut"
//    let f4 = "ln + apple + log10 + banana + c + cos(dog) + base + log"
//    
//    var parsed: OrderedSet<String> {
//        // Calculator.functionParametersIn(f4, matching: .init())
//        f4.getSoulverVariables()
//    }
//    
//    var body: some View {
//        VStack {
//            Text(f4)
//            ForEach(parsed, id: \.self) { s in
//                Text("variable: \(s)")
//            }
//        }
//        
//    }
//}
//
//
//#Preview {
//    SoulverFormula_REPL()
//        .scaleEffect(3)
//}

// Note: this doesn't work for finding Soulver-specific variables?
// https://soulverteam.github.io/SoulverCore/documentation/soulvercore/calculator/functionparametersin(_:matching:customization:)/
