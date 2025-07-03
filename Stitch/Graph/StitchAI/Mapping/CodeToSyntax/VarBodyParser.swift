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
    /// Parses `source` and returns the text slice that corresponds to the
    /// `var body: some View` declaration (including its braces and original
    /// indentation). Returns `nil` if no matching declaration is found.
    public static func extract(from source: String) throws -> String? {
        let tree   = Parser.parse(source: source)
        let finder = BodyFinder(viewMode: .sourceAccurate)
        finder.walk(tree)
        
        guard let decl = finder.result else { return nil }
        
        // Remove blank lines (and trailing spaces) *before* `var body`
        // and *after* the closing `}` while keeping the interior
        // indentation untouched.
        var text = decl.description
        
        // Trim leading newline / carriage‑return only
        while let first = text.first, first == "\n" || first == "\r" {
            text.removeFirst()
        }
        // Trim trailing whitespace & newlines
        while let last = text.last, last.isWhitespace || last.isNewline {
            text.removeLast()
        }
        return text
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

// MARK: - 🚀 Interactive demo
// A lightweight playground view that lets you edit example SwiftUI files and
// instantly see the `VarBodyParser.extract` result next to it.
//
// Inspired by ASTExplorerView, but scoped just to body‑extraction.
struct VarBodyParserDemoView: View {
    
    // Demo snippets lifted from `VarBodyCodeExamples`.
    static let examples = [
        VarBodyCodeExamples.var_body,
        VarBodyCodeExamples.var_body_method,
        VarBodyCodeExamples.file_views
    ]
    
    // MARK: – UI state
    @State var codes: [String] = examples.map(\.code)
    
    @State var extracted: [String] = examples.map { code in
        (try? VarBodyParser.extract(from: code.code)) ?? "—"
    }
    @State var selectedTab = 0
    
    @State var errorStrings: [String?] = Array(repeating: nil,
                                               count: examples.count)
    
    var body: some View {
        VStack(spacing: 16) {
            Text("VarBodyParser Demo")
                .font(.title2).bold()
            
            Button("Parse Current Tab") { refresh(tab: selectedTab) }
                .buttonStyle(.borderedProminent)
            
            TabView(selection: $selectedTab) {
                ForEach(Self.examples.indices, id: \.self) { idx in
                    demoPane(for: idx)
                        .tabItem { Text(Self.examples[idx].title) }
                        .tag(idx)
                }
            }
            .tabViewStyle(.automatic)
            .onChange(of: selectedTab, initial: true) { _, newIdx in
                refresh(tab: newIdx)
            }
        }
        .padding()
    }
    
    // MARK: – Single‑tab layout
    @ViewBuilder
    func demoPane(for idx: Int) -> some View {
        let codeBinding = Binding<String>(
            get: { codes[idx] },
            set: { codes[idx] = $0; refresh(tab: idx) }
        )
        
        HStack(spacing: 18) {
            stageView(title: "Source Code",
                      text: codes[idx],
                      isEditor: true,
                      editorBinding: codeBinding)
            stageView(title: "Extracted `var body`",
                      text: extracted[idx].isEmpty ? "—" : extracted[idx])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: – Helpers
    func refresh(tab idx: Int) {
        do {
            let result = try VarBodyParser.extract(from: codes[idx])
            extracted[idx] = result ?? "—"
            errorStrings[idx] = nil
        } catch {
            extracted[idx] = "—"
            errorStrings[idx] = "\(error)"
        }
    }
    
    /// Re‑usable stage panel.
    @ViewBuilder
    func stageView(title: String,
                   text: String,
                   isEditor: Bool = false,
                   editorBinding: Binding<String>? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            if isEditor, let binding = editorBinding {
                TextEditor(text: binding)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .border(Color.secondary)
            } else {
                TextEditor(text: .constant(text))
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .border(Color.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
