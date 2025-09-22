//
//  ConditionalRemovalRewriter.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/22/25.
//

import Foundation
import SwiftSyntax

/// A SyntaxRewriter that removes conditional statements and expressions from Swift code.
/// - If statements: Completely removed, or only the else block is kept if it exists
/// - Ternary expressions: Replaced with the false condition (the part after :)
class ConditionalRemovalRewriter: SyntaxRewriter {

    /// Override to handle code block items that might contain if statements
    override func visit(_ node: CodeBlockItemListSyntax) -> CodeBlockItemListSyntax {
//        print("🔵 CodeBlockItemListSyntax: Processing \(node.count) items")
        var newItems: [CodeBlockItemSyntax] = []

        for (index, item) in node.enumerated() {
//            print("🔵 Item \(index): \(item.item.syntaxNodeType)")
//            print("🔵 Item content: '\(item.item.description.prefix(100))'")

            var foundIfExpr: IfExprSyntax? = nil

            // Check if this item contains an if expression/statement directly
            if let ifExpr = item.item.as(IfExprSyntax.self) {
//                print("🔵 Found direct IfExprSyntax!")
                foundIfExpr = ifExpr
            }
            // ALSO check if this is an ExpressionStmtSyntax containing an IfExprSyntax
            else if let exprStmt = item.item.as(ExpressionStmtSyntax.self) {
//                print("🔵 Found ExpressionStmtSyntax, checking if it contains IfExprSyntax...")
//                print("🔵 Expression content: '\(exprStmt.expression.description.prefix(100))'")
                if let ifExpr = exprStmt.expression.as(IfExprSyntax.self) {
//                    print("🔵 Found IfExprSyntax inside ExpressionStmtSyntax!")
                    foundIfExpr = ifExpr
                } else {
//                    print("🔵 ExpressionStmtSyntax does not contain IfExprSyntax")
                }
            }

            if let ifExpr = foundIfExpr {
//                print("🔵 Processing IfExprSyntax with condition: '\(ifExpr.conditions.description.prefix(50))'")
                // This is an if statement
                if let elseBody = ifExpr.elseBody {
//                    print("🔵 Has else body of type: \(type(of: elseBody))")
                    switch elseBody {
                    case .codeBlock(let codeBlock):
//                        print("🔵 Else body is code block with \(codeBlock.statements.count) statements")
//                        print("🔵 Code block content: '\(codeBlock.description.prefix(200))'")
                        // Add all statements from the else block
                        for (elseIndex, elseItem) in codeBlock.statements.enumerated() {
//                            print("🔵 Adding else statement \(elseIndex):")
//                            print("🔵   Type: \(elseItem.item.syntaxNodeType)")
//                            print("🔵   Content: '\(elseItem.item.description)'")
                            newItems.append(elseItem)
//                            print("🔵   ✅ Successfully added to newItems")
                        }
//                        print("🔵 Finished processing else block, newItems.count = \(newItems.count)")
                    case .ifExpr(let nestedIf):
//                        print("🔵 Else body is nested if")
                        // Handle else-if recursively by creating a new item with the nested if
                        let newItem = CodeBlockItemSyntax(item: .init(nestedIf))
                        // Recursively process this item
                        let processedList = visit(CodeBlockItemListSyntax([newItem]))
                        newItems.append(contentsOf: processedList)
                    }
                } else {
//                    print("🔵 No else body, removing if statement completely")
                }
                // If no else block, we skip this item entirely (removing the if statement)
            } else {
//                print("🔵 Not an if statement, keeping item and processing recursively")
                // Not an if statement, keep the item but process it recursively
                let processedItem = visit(item)
//                print("🔵 Processed item result: '\(processedItem.description.prefix(100))'")
                newItems.append(processedItem)
//                print("🔵 Added non-if item, newItems.count = \(newItems.count)")
            }
        }

//        print("🔵 CodeBlockItemListSyntax: Returning \(newItems.count) items")
        return CodeBlockItemListSyntax(newItems)
    }

    /// Handle if expressions that need to return a value (expression context)
    override func visit(_ node: IfExprSyntax) -> ExprSyntax {
//        print("🟡 IfExprSyntax: Called! Parent: \(node.parent?.syntaxNodeType)")

        // Check if there's an else clause
        if let elseBody = node.elseBody {
//            print("🟡 IfExprSyntax: Has else body")
            switch elseBody {
            case .codeBlock(let codeBlock):
//                print("🟡 IfExprSyntax: Else body is code block with \(codeBlock.statements.count) statements")
                // For expression context, extract the expression from the else block
                if let firstItem = codeBlock.statements.first,
                   let exprStmt = firstItem.item.as(ExpressionStmtSyntax.self) {
//                    print("🟡 IfExprSyntax: Returning expression: \(exprStmt.expression.description.prefix(50))")
                    return exprStmt.expression
                }
                // If else block doesn't contain a simple expression, return a string literal as placeholder
//                print("🟡 IfExprSyntax: Returning empty string (no expression found)")
                return ExprSyntax(StringLiteralExprSyntax(content: ""))

            case .ifExpr(let nestedIf):
//                print("🟡 IfExprSyntax: Else body is nested if, recursing")
                // Handle else-if case recursively
                return visit(nestedIf)
            }
        }

        // No else block in expression context - return empty string literal as minimal placeholder
//        print("🟡 IfExprSyntax: No else body, returning empty string")
        return ExprSyntax(StringLiteralExprSyntax(content: ""))
    }

    /// Handle sequence expressions that might contain ternary operators
    override func visit(_ node: SequenceExprSyntax) -> ExprSyntax {
//        print("🟠 SequenceExprSyntax: Called! Parent: \(node.parent?.syntaxNodeType)")
//        print("🟠 SequenceExprSyntax: \(node.elements.count) elements")

        // Check if this is a ternary expression pattern: condition ? trueExpr : falseExpr
        let elements = Array(node.elements)

        for (i, element) in elements.enumerated() {
//            print("🟠 Element [\(i)]: \(element.syntaxNodeType) - '\(element.description.prefix(50))'")
        }

        // Handle ternary expressions
        // Pattern 1: condition ? trueExpr : falseExpr (3 elements)
        // Pattern 2: lhs = condition ? trueExpr : falseExpr (5 elements)
        if elements.count == 3,
           let ternaryExpr = elements[1].as(UnresolvedTernaryExprSyntax.self) {
//            print("🟠 SequenceExprSyntax: Detected 3-element ternary pattern!")
//            print("🟠 SequenceExprSyntax: Condition: '\(elements[0].description.prefix(50))'")
//            print("🟠 SequenceExprSyntax: Ternary expr: '\(ternaryExpr.description.prefix(50))'")
//            print("🟠 SequenceExprSyntax: False expr: '\(elements[2].description.prefix(50))'")
//            print("🟠 SequenceExprSyntax: Returning false expression: '\(elements[2].description)'")
            // This is a ternary expression, return only the false expression (element 2)
            return ExprSyntax(elements[2])
        }

        // Handle assignment with ternary: lhs = condition ? trueExpr : falseExpr
        if elements.count == 5,
           elements[1].as(AssignmentExprSyntax.self) != nil,
           let ternaryExpr = elements[3].as(UnresolvedTernaryExprSyntax.self) {
//            print("🟠 SequenceExprSyntax: Detected 5-element assignment + ternary pattern!")
//            print("🟠 SequenceExprSyntax: LHS: '\(elements[0].description.prefix(50))'")
//            print("🟠 SequenceExprSyntax: Assignment: '\(elements[1].description.prefix(50))'")
//            print("🟠 SequenceExprSyntax: Condition: '\(elements[2].description.prefix(50))'")
//            print("🟠 SequenceExprSyntax: Ternary expr: '\(ternaryExpr.description.prefix(50))'")
//            print("🟠 SequenceExprSyntax: False expr: '\(elements[4].description.prefix(50))'")
//            print("🟠 SequenceExprSyntax: Returning assignment with false expression")

            // Reconstruct as: lhs = falseExpr
            let newSequence = SequenceExprSyntax(elements: ExprListSyntax([
                elements[0], // lhs
                elements[1], // =
                elements[4]  // falseExpr
            ]))
            return ExprSyntax(newSequence)
        }

        // Handle complex condition ternary: condition op value ? trueExpr : falseExpr
        if elements.count == 5,
           elements[1].as(BinaryOperatorExprSyntax.self) != nil,
           let ternaryExpr = elements[3].as(UnresolvedTernaryExprSyntax.self) {
//            print("🟠 SequenceExprSyntax: Detected 5-element complex condition + ternary pattern!")
//            print("🟠 SequenceExprSyntax: Condition part 1: '\(elements[0].description.prefix(50))'")
//            print("🟠 SequenceExprSyntax: Binary operator: '\(elements[1].description.prefix(50))'")
//            print("🟠 SequenceExprSyntax: Condition part 2: '\(elements[2].description.prefix(50))'")
//            print("🟠 SequenceExprSyntax: Ternary expr: '\(ternaryExpr.description.prefix(50))'")
//            print("🟠 SequenceExprSyntax: False expr: '\(elements[4].description.prefix(50))'")
//            print("🟠 SequenceExprSyntax: Returning false expression: '\(elements[4].description)'")
            // This is a ternary with complex condition, return false expression
            return ExprSyntax(elements[4])
        }

//        print("🟠 SequenceExprSyntax: Not a ternary, using default behavior")
        // Not a ternary, continue with default behavior
        return super.visit(node)
    }

    /// Replaces ternary expressions with the false condition
    override func visit(_ node: TernaryExprSyntax) -> ExprSyntax {
//        print("🔴 TernaryExprSyntax: Called! Parent: \(node.parent?.syntaxNodeType)")
//        print("🔴 TernaryExprSyntax: Condition: '\(node.condition.description.prefix(50))'")
//        print("🔴 TernaryExprSyntax: True expr: '\(node.thenExpression.description.prefix(50))'")
//        print("🔴 TernaryExprSyntax: False expr: '\(node.elseExpression.description.prefix(50))'")
//        print("🔴 TernaryExprSyntax: Returning false expression: '\(node.elseExpression.description)'")
        // Return only the false choice (the expression after :)
        return ExprSyntax(node.elseExpression)
    }
}
