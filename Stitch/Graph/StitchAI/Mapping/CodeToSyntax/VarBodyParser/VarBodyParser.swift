//
//  VarBodyParser.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/3/25.
//

import Foundation
import SwiftSyntax
import SwiftUI
import SwiftParser


/// A tiny utility for extracting the exact source text of the
/// `var body: some View { … }` declaration from arbitrary Swift code.
///
/// This relies on **SwiftSyntax/SwiftParser**, so it respects Swift grammar:
/// occurrences of “var body” inside comments, strings, or nested types are ignored.
public enum VarBodyParser {
    /// Parses `source` and returns *only* the source between the braces of
    /// `var body: some View { … }`, preserving every character exactly as
    /// written (indentation, comments, blank lines).
    /// - Returns: The interior text, or `nil` if no matching declaration exists.
    public static func extract(from source: String) throws -> String? {
        // Parse the source.
        let tree   = Parser.parse(source: source)
        let finder = BodyFinder(viewMode: .sourceAccurate)
        finder.walk(tree)
        guard
            let decl     = finder.result,
            let binding  = decl.bindings.first,
            let accessor = binding.accessorBlock
        else { return nil }

        // Slice the original string using absolute UTF‑8 offsets so that we
        // keep trivia (whitespace/comments) exactly as typed.
        let startOffset = accessor.leftBrace.endPosition.utf8Offset
        let endOffset   = accessor.rightBrace.position.utf8Offset

        guard endOffset >= startOffset, endOffset <= source.utf8.count else {
            return nil
        }

        // Convert offsets to String.Index and return the substring.
        let startIndex = String.Index(utf16Offset: startOffset, in: source)
        let endIndex   = String.Index(utf16Offset: endOffset, in: source)
        return String(source[startIndex..<endIndex])
    }
    
    // MARK: - Private
    
    /// Visits each `VariableDeclSyntax` until it finds the first declaration that:
    ///   * is named “body”
    ///   * has a single binding
    ///   * has a type annotation exactly equal to `some View`
    private final class BodyFinder: SyntaxVisitor {
        var result: VariableDeclSyntax?
        
        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            // Bail early once we've captured a match.
            guard result == nil else { return .skipChildren }
            
            guard
                node.bindings.count == 1,
                let binding      = node.bindings.first,
                let identPattern = binding.pattern.as(IdentifierPatternSyntax.self),
                identPattern.identifier.text == "body",
                let typeAnn      = binding.typeAnnotation?.type,
                typeAnn.trimmedDescription == "some View"
            else {
                return .skipChildren
            }
            
            // Capture the declaration exactly as it appeared in the source file.
            result = node
            return .skipChildren
        }
    }
}
