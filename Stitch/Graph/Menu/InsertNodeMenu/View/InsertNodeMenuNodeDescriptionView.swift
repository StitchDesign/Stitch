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

//struct GraphNodeDescriptionView: View {
//    let option: InsertNodeMenuOption
//    
//    var body: some View {
//        NodeDescriptionView(option: option)
//            .frame(width: 500)  // maxWidth breaks the popover, cutting content short at times
//            .padding()
//    }
//}

struct NodeDescriptionView: View {
    let option: InsertNodeMenuOption
    
    var displayDescription: String {
        guard let description = option.displayDescription else {
            fatalErrorIfDebug()
            return ""
        }
        
        return description
    }
    
    var body: some View {
        StitchDocsTextView(title: option.displayTitle,
                              description: self.displayDescription)
    }
}
