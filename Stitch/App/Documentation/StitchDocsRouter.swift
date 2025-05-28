//
//  StitchDocsRouter.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/27/25.
//

import SwiftUI
import StitchSchemaKit

enum StitchDocsRouter {
    case overview(StitchDocsOverviewRouter)
    case patch(StitchDocsPatchRouter)
    case layer(StitchDocsLayerRouter)
}

extension StitchDocsRouter: CaseIterable {
    init(from nodeKind: NodeKind) {
        switch nodeKind {
        case .patch(let patch):
            self = .patch(.patch(patch))
            
        case .layer(let layer):
            self = .layer(.layer(layer))
            
        default:
            fatalErrorIfDebug()
            self = .patch(.patch(.splitter))
        }
    }
    
    static var allCases: [StitchDocsRouter] {
        StitchDocsOverviewRouter.allCases.map(Self.overview) +
        StitchDocsPatchRouter.allCases.map(Self.patch) +
        StitchDocsLayerRouter.allCases.map(Self.layer)
    }
    
    var page: StitchDocsPage {
        switch self {
        case .overview:
            return .overview
        case .patch:
            return .patch
        case .layer:
            return .layer
        }
    }
    
    var headerLabel: String {
        switch self {
        case .overview(let stitchDocsOverviewRouter):
            return stitchDocsOverviewRouter.rawValue
        case .patch(let stitchDocsPatchRouter):
            return stitchDocsPatchRouter.headerLabel
        case .layer(let stitchDocsLayerRouter):
            return stitchDocsLayerRouter.headerLabel
        }
    }
    
    /// Returns description text from markdown file.
    var description: String? {
        StitchDocsRouter.forTitle(self.headerLabel, for: self.page)
    }
}

enum StitchDocsPage: CaseIterable {
    case overview
    case patch
    case layer
}

extension StitchDocsPage: Hashable {
    var markdownFileName: String {
        switch self {
        case .overview:
            return "README"
            
        case .patch:
            return "Patch"
            
        case .layer:
            return "Layer"
        }
    }
    
    var markdownFileUrl: URL? {
        Bundle.main.url(forResource: self.markdownFileName,
                        withExtension: "md")
    }
}

enum StitchDocsOverviewRouter: String, CaseIterable {
    case layerSidebar = "Layer Sidebar"
    case patchCanvas = "Patch Canvas"
}

enum StitchDocsPatchRouter {
    case header
    case patch(Patch)
}

extension StitchDocsPatchRouter: CaseIterable {
    static var allCases: [StitchDocsPatchRouter] {
        [.header] + Patch.allCases.map { .patch($0) }
    }
    
    var headerLabel: String {
        switch self {
        case .header:
            return StitchDocsPage.patch.markdownFileName
            
        case .patch(let patch):
            return patch.defaultDisplayTitle()
        }
    }
}

enum StitchDocsLayerRouter {
    case header
    case layer(Layer)
}

extension StitchDocsLayerRouter: CaseIterable {
    static var allCases: [StitchDocsLayerRouter] {
        [.header] + Layer.allCases.map { .layer($0) }
    }
    
    var headerLabel: String {
        switch self {
        case .header:
            return StitchDocsPage.layer.markdownFileName
            
        case .layer(let layer):
            return layer.defaultDisplayTitle()
        }
    }
}

extension StitchDocsRouter {

    // MARK: Public helpers ----------------------------------------------------

    /// Markdown body for a given display title (“Pop Animation”, “3D Model”, …)
    private static func forTitle(_ title: String,
                         for page: StitchDocsPage) -> String? {
        map.get(page)?.get(title)
    }
    
    // MARK: Cached data -------------------------------------------------------
    
    static let map: [StitchDocsPage: [String: String]] = {
        var dict = [StitchDocsPage: [String: String]]()
        
        for page in StitchDocsPage.allCases {
            guard let markdownUrl = page.markdownFileUrl,
                  let markdownString  = try? String(contentsOf: markdownUrl, encoding: .utf8) else {
                fatalErrorIfDebug("⚠️ Could not load \(page) from bundle")
                return [:]
            }
            
            let dictAtPage = buildLookup(fromMarkdown: markdownString)
            dict.updateValue(dictAtPage, forKey: page)
        }
        
        return dict
    }()

    // MARK: Markdown parsing --------------------------------------------------

    /// Returns a `[heading-title : body-text]` dictionary for *all* Markdown
    /// headings whose level is ≥ `minimumLevel`.
    ///
    ///  • Level 1 = `#`, level 2 = `##`, … level 6 = `######`.
    ///  • “Body” is everything until the next heading *of the same or higher
    ///    level* (or EOF). Nested sub-headings become separate entries, so the
    ///    dictionary is flat.
    ///
    /// Example:
    ///     let dict = buildLookup(fromMarkdown: mdString, minimumLevel: 2)
    ///     dict["Arithmetic & Math"]      // intro for that section
    ///     dict["Add"]                    // description of the Add patch
    ///
    private static func buildLookup(fromMarkdown md: String,
                                    minimumLevel: Int = 1) -> [String: String] {
        precondition((1...6).contains(minimumLevel),
                     "minimumLevel must be 1–6")

        // (?ms)         → multiline & dot-matches-newline
        // ^\s*(#{1,6})  → capture 1–6 leading # symbols = heading level
        // \s+(.+?)\s*   → capture the heading text (trimmed later)
        // \n            → heading line ends
        // (.*?)         → capture body lazily until…
        // (?=^\s*#{1,6}\s+|\z) → …the next heading *any level* or EOF
        let pattern = #"(?ms)^\s*(#{1,6})\s+(.+?)\s*\n(.*?)(?=^\s*#{1,6}\s+|\z)"#
        let regex   = try! NSRegularExpression(
            pattern: pattern,
            options: [.anchorsMatchLines, .dotMatchesLineSeparators]
        )

        var dict: [String: String] = [:]

        for match in regex.matches(in: md,
                                   range: NSRange(md.startIndex..., in: md)) {
            guard
                let hashRange  = Range(match.range(at: 1), in: md),
                let titleRange = Range(match.range(at: 2), in: md),
                let bodyRange  = Range(match.range(at: 3), in: md)
            else { continue }

            // Determine heading level from the number of #
            let level = md[hashRange].count
            guard level >= minimumLevel else { continue }

            let title = md[titleRange]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let body  = md[bodyRange]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            dict[title] = body
        }

        return dict
    }
}
