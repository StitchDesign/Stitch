//
//  NodeTagMenuView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/2/23.
//

import SwiftUI
import StitchSchemaKit

// The buttons for a node tag menu;
// what we provide to SwifUI Menu or SwiftUI .contextMenu
struct NodeTagMenuButtonsView: View {

    @Environment(StitchStore.self) private var store
    
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel

    let canvasItemId: CanvasItemId // id for Node or LayerInputOnGraph
    
    var activeGroupId: GroupNodeId?
    var nodeTypeChoices: [UserVisibleType] = []
    
    // Always false for Layer Nodes;
    // may be true for Patch Nodes.
    let canAddInput: Bool
    // Also false when we only have minimum number of inputs
    let canRemoveInput: Bool
    
    var atleastOneCommentBoxSelected: Bool

    var isHiddenLayer: Bool
    
    @MainActor
    var graphUI: GraphUIState {
        self.graph.graphUI
    }

     
    @MainActor
    var moreThanOneNodeSelected: Bool {
        graph.selectedCanvasItems.count > 1
    }

    @MainActor
    var activeIndex: ActiveIndex {
        self.graphUI.activeIndex
    }

    @MainActor
    var loopIndices: [Int] {
        self.node.getLoopIndices()
    }

    var nodeType: UserVisibleType? {
        self.node.userVisibleType
    }

    var isGroupNode: Bool {
        self.node.kind.isGroup
    }

    // current splitter type; nil for non-splitters
    var splitterType: SplitterType? {
        self.node.splitterType
    }

    @MainActor
    var singleNonGroupNodeSelected: Bool {
        !moreThanOneNodeSelected && !isGroupNode
    }

    @MainActor
    var singleGroupNodeSelected: Bool {
        !moreThanOneNodeSelected && isGroupNode
    }

    var hasNodeTypeCarousel: Bool {
        nodeType.isDefined
            && !nodeTypeChoices.isEmpty
    }

    // only show loop-indices when more than just 1 index
    @MainActor
    var hasLoopIndexCarousel: Bool {
        loopIndices.count > 1
    }

    // Only show splitter-type carousel if not at top-level
    var hasSplitterTypeCarousel: Bool {
        splitterType.isDefined
            && activeGroupId.isDefined
    }

    var body: some View {
        if singleGroupNodeSelected {
            Group {
                deleteGroupButton
                duplicateButton
                visitGroupButton
                ungroupGroupButton
//                if FeatureFlags.USE_COMMENT_BOX_FLAG {
//                    createCommentBoxButton
//                }
            }
        } else if singleNonGroupNodeSelected {
            Group {
                buttonsForSingleNongroupNode
//                if FeatureFlags.USE_COMMENT_BOX_FLAG {
//                    createCommentBoxButton
//                }
            }
        } else {
            // multiple nodes selected
            Group {
                deleteButton
                duplicateButton
                createGroupButton
//                if FeatureFlags.USE_COMMENT_BOX_FLAG {
//                    createCommentBoxButton
//                }
            }
        }
    }

    @MainActor @ViewBuilder
    var buttonsForSingleNongroupNode: some View {
        Group {
            // Always shown
            deleteButton
            duplicateButton

            if canAddInput {
                addInputButton
            }
            
            if canRemoveInput {
                removeInputButton
            }

            if let splitterType = splitterType,
               let nodeId = canvasItemId.nodeCase,
               hasSplitterTypeCarousel {
                splitterTypeSubmenu(nodeId: nodeId, splitterType)
            }

            // node-type carousel:
            // only for nodes with node-types;
            // ie only some patch nodes and never layer nodes.
            if let nodeType = nodeType,
               let nodeId = canvasItemId.nodeCase,
               !nodeTypeChoices.isEmpty {
                nodeTypeSubmenu(nodeId: nodeId, nodeType, nodeTypeChoices)
            } // if let nodeType

            if hasLoopIndexCarousel {
                loopIndexSubmenu(activeIndex: activeIndex,
                                 loopIndices)
            }

            if isWirelessReceiver {
                NodeWirelessBroadcastSubmenuView(graph: graph,
                                                 nodeId: node.id)
            }
            
            if isWirelessReceiver,
               let assignedBroadcaster = node.currentBroadcastChoiceId {
                nodeTagMenuButton(label: "Jump to Assigned Broadcaster") {
                    dispatch(JumpToCanvasItem(id: .node(assignedBroadcaster)))
                }
            }
            
            if node.kind == .patch(.mathExpression) {
                MathExpressionSubmenuButtonView(id: node.id)
            }
            
            if let layerNode = node.layerNode {
                Button {
                    dispatch(SidebarItemHiddenStatusToggled(clickedId: layerNode.id.asLayerNodeId))
                } label: {
                    Text(isHiddenLayer ? "Unhide Layer" : "Hide Layer")
                }
            }
        }
    }

    var isWirelessReceiver: Bool {
        node.kind == .patch(.wirelessReceiver)
    }
    
    @MainActor
    func splitterTypeSubmenu(nodeId: NodeId,
                             _ currentSplitterType: SplitterType) -> some View {

        let binding: Binding<SplitterType> = .init {
            currentSplitterType
        } set: { newChoice in
            dispatch(SplitterTypeChanged(
                        newType: newChoice,
                        currentType: currentSplitterType,
                        splitterNodeId: nodeId))
        }

        return Picker("Change Splitter Type", selection: binding) {
            ForEach(SplitterType.allCases, id: \.self) { choice in
                StitchTextView(string: choice.rawValue)
            }
        }.pickerStyle(.menu)
    }

    @MainActor
    func nodeTypeSubmenu(nodeId: NodeId,
                         _ currentNodeType: UserVisibleType,
                         _ nodeTypeChoices: [UserVisibleType]) -> some View {

        let binding: Binding<UserVisibleType> = .init {
            currentNodeType
        } set: { newChoice in
            dispatch(NodeTypeChanged(nodeId: nodeId,
                                     newNodeType: newChoice))
        }

        return Picker("Change Node Type", selection: binding) {
            ForEach(nodeTypeChoices, id: \.self) { choice in
                StitchTextView(string: choice.display)

                // Alternatively, we can use our own icon:
                //                Label {
                //                    StitchTextView(string: choice.display)
                //                } icon: {
                //                    Image(systemName: currentNodeType == choice ? "circle.fill" : "circle")
                //                }

            } // ForEach
        }.pickerStyle(.menu)
    }

    @MainActor
    func loopIndexSubmenu(activeIndex: ActiveIndex,
                          _ indices: [Int]) -> some View {

        let binding: Binding<Int> = .init {
            activeIndex.adjustedIndex(indices.count)
        } set: { newChoice in
            dispatch(ActiveIndexChangedAction(index: .init(newChoice)))
        }

        return Picker("Change Loop Index", selection: binding) {
            ForEach(indices, id: \.self) { choice in
                StitchTextView(string: choice.description)
            } // ForEach
        }.pickerStyle(.menu)
    }

    // If both nodes AND comments are selected,
    // distinguish between "Duplicage Nodes" and "Duplicage Comments"
    @MainActor @ViewBuilder
    var duplicateButton: some View {
        if let nodeId = canvasItemId.nodeCase {
            Group {
                if atleastOneCommentBoxSelected {
                    DuplicateNodesButton(graph: graph,
                                         label: "Duplicate Nodes",
                                         nodeId: nodeId)
                    DuplicateCommentsOnlyButton(graph: graph)
                } else {
                    // If no comment select
                    DuplicateNodesButton(graph: graph,
                                         label: "Duplicate",
                                         nodeId: nodeId)
                }
            }
        } else {
            EmptyView()
        }
        
    }
    
    // If both nodes AND comments are selected,
    // distinguish between "Delete Nodes" and "Delete Comments"
    var deleteButton: some View {
        // Delete node(s) button
        Group {
            if atleastOneCommentBoxSelected {
                DeleteNodesButton(label: "Delete Nodes",
                                  canvasItemId: canvasItemId)
                DeleteCommentsOnlyButton(graph: graph)
            } else {
                DeleteNodesButton(label: "Delete",
                                  canvasItemId: canvasItemId)
            }
        }
    }

    @MainActor
    var createGroupButton: some View {
        nodeTagMenuButton(label: "Group Nodes") {
            dispatch(GroupNodeCreatedEvent())
        }
    }

    // TODO: fix when comment boxes added back
//    @MainActor
//    var createCommentBoxButton: some View {
//        nodeTagMenuButton(label: "Create Comment") {
//            graph.commentBoxCreated(nodeId: nodeId)
//        }
//    }

    @MainActor
    var visitGroupButton: some View {
        nodeTagMenuButton(label: "Visit Group") {
            if let nodeId = canvasItemId.nodeCase {
                dispatch(GroupNodeDoubleTapped(id: GroupNodeId(nodeId)))
            }
        }
    }

    @MainActor
    var deleteGroupButton: some View {
        nodeTagMenuButton(label: "Delete",
                          role: .destructive) {
            if let nodeId = canvasItemId.nodeCase {
                dispatch(GroupNodeDeletedAction(groupNodeId: nodeId.asGroupNodeId))
            }
        }
    }

    @MainActor
    var ungroupGroupButton: some View {
        nodeTagMenuButton(label: "Ungroup") {
            if let nodeId = canvasItemId.nodeCase {
                dispatch(GroupNodeUncreated(groupId: GroupNodeId(nodeId)))
            }
        }
    }

    @MainActor
    var removeInputButton: some View {
        nodeTagMenuButton(label: "Remove Input") {
            if let nodeId = canvasItemId.nodeCase {
                dispatch(InputRemovedAction(nodeId: nodeId))
            }
        }
    }

    @MainActor
    var addInputButton: some View {
        nodeTagMenuButton(label: "Add Input") {
            if let nodeId = canvasItemId.nodeCase {
                dispatch(InputAddedAction(nodeId: nodeId))
            }
        }
    }
    
    // BUG?: Does not use red color on Catalyst when we pass in .destructive ButtonRole
    func nodeTagMenuButton(label: String,
                           role: ButtonRole? = nil,
                           action: @escaping () -> Void) -> some View {
        TagMenuButtonView(label: label,
                          role: role,
                          action: action)
    }
}

//#Preview {
//    NodeTagMenuButtonsView(
//        node: ImageImportPatchNode.createViewModel(activeIndex: .init(.zero),
//                                                   graphDelegate: nil),
//        nodeTypeChoices: [.size, .media, .anchoring],
//        canChangeInputCount: true,
//        moreThanOneNodeSelected: false,
//        atleastOneCommentBoxSelected: false,
//        isHiddenLayer: true
//    )
//}
