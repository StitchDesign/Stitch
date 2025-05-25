//
//  LayerDescription.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/23.
//

import Foundation
import StitchSchemaKit

extension Layer {
    var nodeDescription: String {
        // Add new line
        "\n\(self.nodeDescriptionBody)"
    }

    var nodeDescriptionBody: String {
        NodeDescriptions.forKind(.layer(self))!
    }
}

enum NodeDescriptions {

    // MARK: Public helpers ----------------------------------------------------

    /// Markdown body for a given display title (“Pop Animation”, “3D Model”, …)
    static func forTitle(_ title: String) -> String? {
        map.get(title)
    }

    /// Convenience shim that pulls the title from `NodeKind.getDisplayTitle()`.
    static func forKind(_ kind: NodeKind) -> String? {
        forTitle(kind.getDisplayTitle(customName: nil))
    }

    // MARK: Cached data -------------------------------------------------------

    static let map: [String: String] = {
        guard
            let patchUrl = Bundle.main.url(forResource: "Patch",
                                           withExtension: "md"),
            let layerUrl = Bundle.main.url(forResource: "Layer",
                                           withExtension: "md"),

            let patchMd  = try? String(contentsOf: patchUrl, encoding: .utf8),
            let layerMd  = try? String(contentsOf: layerUrl, encoding: .utf8)
        else {
            assertionFailure("⚠️ Could not load Guides/Nodes.md from bundle")
            return [:]
        }
        
        var dict: [String: String] = [:]
        buildLookup(dict: &dict,
                    fromMarkdown: patchMd)
        buildLookup(dict: &dict,
                    fromMarkdown: layerMd)
        return dict
    }()

    // MARK: Markdown parsing --------------------------------------------------

    /// Splits markdown on “## ” headings and ignores all other header levels.
    /// Returns a `[title: body]` dictionary.
    private static func buildLookup(dict: inout [String: String],
                                    fromMarkdown md: String) {
        // (?ms)  → multi-line, dot-matches-newline
        // ^## +  → a line that *starts* with “## ”
        // (.+?)  → capture the heading text (lazy so we stop at the newline)
        // \n     → heading line ends
        // (.*?)  → capture everything until …
        // (?=^## |\z) → …the next “## ” heading *or* end-of-file
        let pattern = #"(?ms)^\s*##\s+(.+?)\s*\n(.*?)(?=^\s*##\s+|\z)"#
        let regex = try! NSRegularExpression(pattern: pattern,
                                             options: [.anchorsMatchLines,
                                                       .dotMatchesLineSeparators])

        for match in regex.matches(in: md, range: NSRange(md.startIndex..., in: md)) {
            guard
                let titleRange = Range(match.range(at: 1), in: md),
                let bodyRange  = Range(match.range(at: 2), in: md)
            else { continue }

            let title = md[titleRange].trimmingCharacters(in: .whitespacesAndNewlines)
            let body  = md[bodyRange].trimmingCharacters(in: .whitespacesAndNewlines)

            dict[title] = body
        }
    }
}
