//
//  InsertNodeMenuPreviewingNode.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/21/22.
//

import SwiftUI
import StitchSchemaKit

/// Displays the resulting node based on the presented query in `InsertNodeMenu`.
struct InsertNodeMenuNodeDescriptionView: View {
    let activeSelection: InsertNodeMenuOption?

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            if let activeSelection = activeSelection {
                ScrollView(showsIndicators: false) {
                    NodeDescriptionView(option: activeSelection)
                        .padding(.bottom, INSERT_NODE_MENU_SCROLL_LIST_BOTTOM_PADDING)
                        .padding([.leading], 8)
                }
            }
        }
        //        .frame(width: 460, height: 300, alignment: .leading)
        .frame(width: 460, alignment: .leading)
    }
}

struct GraphNodeDescriptionView: View {
    let option: InsertNodeMenuOption
    
    var body: some View {
        NodeDescriptionView(option: option)
            .frame(width: 500)  // maxWidth breaks the popover, cutting content short at times
            .padding()
    }
}

struct NodeDescriptionView: View {
    let option: InsertNodeMenuOption
    
    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            let descriptionTitle = try? AttributedString(
                styledMarkdown: "# \(option.displayTitle)",
                isTitle: true)
            
            Text(descriptionTitle ?? "Failed to retrieve Markdown-formatted title")
            
            let descriptionBody = try? AttributedString(
                styledMarkdown: option.displayDescription,
                isTitle: false)
            
            Text(descriptionBody ?? "Failed to retrieve Markdown-formatted body")
        }
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
