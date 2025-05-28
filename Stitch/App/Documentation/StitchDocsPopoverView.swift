//
//  StitchDocsPopoverView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/27/25.
//

import SwiftUI
import StitchSchemaKit

struct StitchDocsPopoverView: View {
    let title: String
    let description: String
    
    var body: some View {
        StitchDocsTextView(title: title,
                           description: description)
        .frame(width: 500)  // maxWidth breaks the popover, cutting content short at times
        .padding()
    }
}

struct StitchDocsTextView: View {
    let title: String
    let description: String
    
    var descriptionTitle: AttributedString {
        do {
            return try AttributedString(
                styledMarkdown: "# \(title)",
                isTitle: true)
        } catch {
            fatalErrorIfDebug(error.localizedDescription)
            return ""
        }
    }
    
    var descriptionBody: AttributedString {
        do {
            return try AttributedString(
                styledMarkdown: description,
                isTitle: false)
        } catch {
            fatalErrorIfDebug(error.localizedDescription)
            return ""
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            Text(descriptionTitle)
            Text(descriptionBody)
        }
    }
}

extension StitchDocsPopoverView {
    init(router: StitchDocsRouter) {
        self.title = router.headerLabel

        guard let description = router.description else {
            fatalErrorIfDebug("StitchDocsPopover: no description found for: \(router)")
            self.description = ""
            return
        }
        
        self.description = description
    }
}

// https://blog.eidinger.info/3-surprises-when-using-markdown-in-swiftui

extension AttributedString {
    init(styledMarkdown markdownString: String,
         isTitle: Bool) throws {
        var output = try AttributedString(
            markdown: markdownString,
            options: .init(
                allowsExtendedAttributes: true,
                // .full accepts # for header, but ignores new lines
                // .inlineOnlyPreservingWhitespace ignores # for header, but accepts new lines
                interpretedSyntax: isTitle ? .full : .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            ),
            baseURL: nil
        )

        for (intentBlock, intentRange) in output.runs[AttributeScopes.FoundationAttributes.PresentationIntentAttribute.self].reversed() {
            guard let intentBlock = intentBlock else { continue }
            for intent in intentBlock.components {
                switch intent.kind {
                case .header(level: let level):
                    switch level {
                    case 1:
                        output[intentRange].font = HEADER_LEVEL_1_FONT
                    case 2:
                        output[intentRange].font = HEADER_LEVEL_2_FONT
                    case 3:
                        output[intentRange].font = .system(.title3).bold()
                    default:
                        break
                    }
                default:
                    break
                }
            }

            if intentRange.lowerBound != output.startIndex {
                output.characters.insert(contentsOf: "\n", at: intentRange.lowerBound)
            }
        }

        self = output
    }
}

