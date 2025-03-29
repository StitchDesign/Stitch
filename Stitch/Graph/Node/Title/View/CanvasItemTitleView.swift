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
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let canvasItem: CanvasItemViewModel
    let isCanvasItemSelected: Bool
    
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
            if node.patch == .wirelessReceiver,
               let rowObserver = node.inputsObservers.first {
                CanvasItemTitleWirelessReceiverMenuView(graph: graph,
                                                        document: document,
                                                        node: node, rowObserver: rowObserver,
                                                        nodeName: self.name)
            } else {
                HStack {
                    if node.kind == .group {
                        Image(systemName: "folder")
                            .foregroundColor(Color(.nodeTitleFont))
                    }
                    NodeTitleTextField(document: document,
                                       graph: graph,
                                       node: node,
                                       canvasItem: canvasItem,
                                       label: label,
                                       isCanvasItemSelected: isCanvasItemSelected)
                }
                
                // Always needs some math expression;
                // if none yet exists (because math-expr node just created),
                // use blank string.
                .modifier(
                    MathExpressionPopoverViewModifier(
                        id: nodeId,
                        document: document,
                        shouldDisplay: node.patch == .mathExpression,
                        mathExpression: mathExpression ?? "")
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
}

struct CanvasItemTitleWirelessReceiverMenuView: View {
    @State private var broadcasterNode: NodeViewModel?
    @State private var choice: BroadcastChoice = nilBroadcastChoice
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var node: NodeViewModel
    @Bindable var rowObserver: InputNodeRowObserver
    let nodeName: String
    
    func updateBroadcasterNode() {
        self.broadcasterNode = graph.getNodeViewModel(choice.id)
    }
    
    var currentBroadcastChoiceNodeId: NodeId? {
        self.rowObserver.upstreamOutputCoordinate?.nodeId
    }
    
    func updateCurrentBroadcastChoice() {
        guard let currentBroadcastChoiceNodeId = currentBroadcastChoiceNodeId else {
            self.choice = nilBroadcastChoice
            return
        }
        
        self.choice = .init(title: self.node.displayTitle,
                            id: currentBroadcastChoiceNodeId)
    }
    
    @ViewBuilder
    var body: some View {
        Menu {
            NodeWirelessBroadcastSubmenuView(graph: graph,
                                             document: document,
                                             currentBroadcastChoice: self.choice,
                                             nodeId: node.id,
                                             forNodeTitle: true)
        } label: {
            StitchTextView(string: self.broadcasterNode?.displayTitle ?? nodeName)
                .height(NODE_TITLE_HEIGHT)
        }
        .buttonStyle(.plain)
        .foregroundColor(STITCH_TITLE_FONT_COLOR)
        .menuIndicator(.hidden)
        // Choice logic here for perf
        .onChange(of: self.rowObserver.upstreamOutputCoordinate, initial: true) {
            self.updateCurrentBroadcastChoice()
        }
        // Broadcaster detection saved here for perf
        .onChange(of: self.choice, initial: true) {
            self.updateBroadcasterNode()
        }
        .onChange(of: document.graphUpdaterId) {
            self.updateBroadcasterNode()
        }
        // Check for new nodes
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
