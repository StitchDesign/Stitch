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

    private static let map: [String: String] = {
        guard
            let url = Bundle.main.url(forResource: "Nodes",         // ← Guides/Nodes.md
                                      withExtension: "md"),
//                                      subdirectory: "Guides"),
            let md  = try? String(contentsOf: url, encoding: .utf8)
        else {
            assertionFailure("⚠️ Could not load Guides/Nodes.md from bundle")
            return [:]
        }
        return buildLookup(fromMarkdown: md)
    }()

    // MARK: Markdown parsing --------------------------------------------------

    /// Splits markdown on “## ” headings.  Heading → rest-of-section.
    private static func buildLookup(fromMarkdown md: String) -> [String: String] {
        var dict: [String: String] = [:]

        // First heading might be “# Stitch Nodes” – skip it by splitting on “\n## ”
        let sections = md.components(separatedBy: "\n## ")

        for raw in sections {
            // Each block is: <title>\n<body…>
            guard
                let firstBreak = raw.firstIndex(of: "\n")
            else { continue }                                      // no body

            let title = raw[..<firstBreak].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            let body  = raw[firstBreak...]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            dict[title] = body
        }
        return dict
    }
}
