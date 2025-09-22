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

    /// Handle if expressions (Swift 5.9+) - these are if expressions that return values
    override func visit(_ node: IfExprSyntax) -> ExprSyntax {
        // Check if there's an else clause
        if let elseBody = node.elseBody {
            switch elseBody {
            case .codeBlock(let codeBlock):
                // For expression context, we need to extract the expression from the code block
                // This is a simplification - in practice, the else block should contain an expression
                if let firstItem = codeBlock.statements.first,
                   let exprStmt = firstItem.item.as(ExpressionStmtSyntax.self) {
                    return exprStmt.expression
                }
                // Fallback: return a nil literal if we can't extract an expression
                return ExprSyntax(NilLiteralExprSyntax())

            case .ifExpr(let nestedIf):
                // Handle else-if case recursively
                return visit(nestedIf)
            }
        }

        // No else block, return nil literal as a safe fallback
        return ExprSyntax(NilLiteralExprSyntax())
    }

    /// Replaces ternary expressions with the false condition
    override func visit(_ node: TernaryExprSyntax) -> ExprSyntax {
        // Return only the false choice (the expression after :)
        return ExprSyntax(node.elseExpression)
    }

    /// Handle sequence expressions that might contain ternary operators
    override func visit(_ node: SequenceExprSyntax) -> ExprSyntax {
        // Check if this is a ternary expression pattern: condition ? trueExpr : falseExpr
        let elements = Array(node.elements)

        if elements.count == 5,
           elements[1].as(UnresolvedTernaryExprSyntax.self) != nil,
           elements[3].as(UnresolvedTernaryExprSyntax.self) != nil {
            // This is a ternary expression, return only the false expression (element 4)
            return ExprSyntax(elements[4])
        }

        // Not a ternary, continue with default behavior
        return super.visit(node)
    }
}