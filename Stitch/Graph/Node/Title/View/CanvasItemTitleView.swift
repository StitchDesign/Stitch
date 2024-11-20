//
//  SpecNodeTitleView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/14/22.
//

import SwiftUI
import StitchSchemaKit

extension CustomStringConvertible {
    var debugFriendlyId: String {
        String(self.description.dropLast(30))
    }
}

// fka `NodeTitleView`
struct CanvasItemTitleView: View {
    // BAD: causes re-renders even when not used anywhere in View
    //    @FocusedValue(\.focusedField) private var focusedField
    
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let isCanvasItemSelected: Bool
    let canvasId: CanvasItemId
    
    var nodeId: NodeId {
        node.id
    }
    
    @MainActor
    var name: String {
        // Use component title if component
        if let component = node.componentNode {
            return component.graph.name
        }
        
        return node.displayTitle
    }
    
    @State private var showMenu = false
            
    var body: some View {
//        logInView("NodeTitleView body \(id)")
        
        let label = name
        let mathExpression = node.patchNode?.mathExpression

        VStack(alignment: .leading) {
            if node.patch == .wirelessReceiver {
                wirelessReceiverMenuView
            } else {
                HStack {
                    if node.kind == .group {
                        Image(systemName: "folder")
                            .foregroundColor(Color(.nodeTitleFont))
                    }
                    NodeTitleTextField(graph: graph,
                                       id: canvasId,
                                       label: label,
                                       isCanvasItemSelected: isCanvasItemSelected)
                }
                
                // Always needs some math expression;
                // if none yet exists (because math-expr node just created),
                // use blank string.
                .modifier(
                    MathExpressionPopoverViewModifier(
                        id: nodeId,
                        shouldDisplay: node.patch == .mathExpression,
                        mathExpression: mathExpression ?? "",
                        isFocused: graph.graphUI.reduxFocusedField == .mathExpression(nodeId))
                )
                
                // Show formula if not empty
                if let customTitle = self.customTitleString {
                    StitchTextView(string: customTitle,
                                   fontColor: Color(.nodeTitleFont),
                                   lineLimit: 1)
                }
            }
        }
    }
    
    // TODO: need to provide some kind of additional width on the sides so that text is not chopped off as we type
    // One approach that might work IF CACHED is this: https://github.com/vpl-codesign/stitch/pull/2796/files
    // But there's some weird jump that happens when we finally commit the change?
    
    var customTitleString: String? {
        // Show formula if not empty
        if let mathExpression = node.patchNode?.mathExpression,
           !mathExpression.isEmpty {
            return mathExpression
        }
        
        return node.getValidCustomTitle()
    }
    
    @ViewBuilder
    var wirelessReceiverMenuView: some View {
        let _title = node.currentBroadcastChoiceId.flatMap { graph.getNodeViewModel($0)?.displayTitle } ?? name
                    
        Menu {
            let choice = node.currentBroadcastChoice
            NodeWirelessBroadcastSubmenuView(graph: graph,
                                             currentBroadcastChoice: choice ?? nilBroadcastChoice,
//                                                 assignedBroadcaster: choice,
                                             nodeId: nodeId,
                                             forNodeTitle: true)
        } label: {
            StitchTextView(string: _title)
                .height(NODE_TITLE_HEIGHT)
        }
        .buttonStyle(.plain)
        .foregroundColor(STITCH_TITLE_FONT_COLOR)
        .menuIndicator(.hidden)
    }
}

extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
   }
}

extension NodeKind {
    var isEligibleForDefaultTitleDisplay: Bool {
        switch self {
        case .group:
            return false
        case .layer:
            return true
        case .patch(let patch):
            switch patch {
            case .splitter, .wirelessReceiver, .wirelessBroadcaster:
                return false
            default:
                return true
            }
        }
    }
}
