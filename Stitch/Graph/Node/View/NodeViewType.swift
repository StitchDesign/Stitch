//
//  NodeViewType.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/11/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct NodeTypeView: View {
    // Use state rather than computed variable due to perf cost
    @State private var sortedUserTypeChoices = [UserVisibleType]()
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var canvasNode: CanvasItemViewModel
    let atleastOneCommentBoxSelected: Bool
    let activeIndex: ActiveIndex
    let groupNodeFocused: GroupNodeType?
    let isSelected: Bool

    var boundsReaderDisabled: Bool = false
    var usePositionHandler: Bool = true

    // Only true for the fake-node that lives in ContentView
    var updateMenuActiveSelectionBounds: Bool = false
    
    var userVisibleType: UserVisibleType? {
        self.node.userVisibleType
    }

    var userTypeChoices: Set<UserVisibleType> {
        self.node.patch?.availableNodeTypes ?? .init()
    }

    @MainActor
    var displayTitle: String {
        self.node.displayTitle
    }

    var body: some View {
        NodeView(node: canvasNode,
                 stitch: node,
                 document: document,
                 graph: graph,
                 nodeId: node.id,
                 isSelected: isSelected,
                 atleastOneCommentBoxSelected: atleastOneCommentBoxSelected,
                 activeGroupId: groupNodeFocused,
                 canAddInput: node.canAddInputs,
                 canRemoveInput: node.canRemoveInputs,
                 sortedUserTypeChoices: sortedUserTypeChoices,
                 boundsReaderDisabled: boundsReaderDisabled,
                 usePositionHandler: usePositionHandler,
                 updateMenuActiveSelectionBounds: updateMenuActiveSelectionBounds,
                 inputsViews: inputsViews,
                 outputsViews: outputsViews)
        .onChange(of: self.node.patch, initial: true) {
            // Sorting is expensive so we control when this is calculated
            if let patchNode = self.node.patchNode {
                self.sortedUserTypeChoices = patchNode.getSortedUserTypeChoices()
            }
        }
    }
    
    @ViewBuilder @MainActor
    func inputsViews() -> some View {
        VStack(alignment: .leading,
               spacing: SPACING_BETWEEN_NODE_ROWS) {
            if self.node.patch == .wirelessReceiver {
                WirelessPortView(graph: graph,
                                 graphUI: document,
                                 isOutput: false,
                                 id: node.id)
                    .padding(.trailing, NODE_BODY_SPACING)
            } else {
                DefaultNodeInputView(graph: graph,
                                     document: document,
                                     node: node,
                                     canvas: canvasNode,
                                     isNodeSelected: isSelected)
            }
        }
    }

    @ViewBuilder @MainActor
    func outputsViews() -> some View {
        VStack(alignment: .trailing,
               spacing: SPACING_BETWEEN_NODE_ROWS) {

            if self.node.patch == .wirelessBroadcaster {
                WirelessPortView(graph: graph,
                                 graphUI: document,
                                 isOutput: true,
                                 id: node.id)
                    .padding(.leading, NODE_BODY_SPACING)
            } else {
                DefaultNodeOutputView(graph: graph,
                                      document: document,
                                      node: node,
                                      canvas: canvasNode,
                                      isNodeSelected: isSelected)
            }
        }
    }
}

struct DefaultNodeInputView: View {
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var node: NodeViewModel
    @Bindable var canvas: CanvasItemViewModel
    let isNodeSelected: Bool
    
    @ViewBuilder @MainActor
    func valueEntryView(rowObserver: InputNodeRowObserver,
                        rowViewModel: InputNodeRowViewModel,
                        portViewModel: InputFieldViewModel,
                        isMultiField: Bool) -> InputValueEntry {
        InputValueEntry(graph: graph,
                        graphUI: document,
                        viewModel: portViewModel,
                        node: node,
                        rowViewModel: rowViewModel,
                        canvasItem: canvas,
                        rowObserver: rowObserver,
                        isCanvasItemSelected: isNodeSelected,
                        hasIncomingEdge: rowObserver.upstreamOutputCoordinate.isDefined,
                        forPropertySidebar: false,
                        propertyIsAlreadyOnGraph: true,
                        isFieldInMultifieldInput: isMultiField,
                        isForFlyout: false,
                        isSelectedInspectorRow: false,
                        fieldsRowLabel: nil,
                        useIndividualFieldLabel: true)
    }
    
    var body: some View {
        DefaultNodeRowView(graph: graph,
                           node: node,
                           canvas: canvas,
                           rowViewModels: canvas.inputViewModels,
                           nodeIO: .input) { rowViewModel in
            if let rowObserver = node.getInputRowObserverForUI(for: rowViewModel.id.portType, graph) {
                
                let isMultiField = (rowViewModel.fieldValueTypes.first?.fieldObservers.count ?? 0) > 1
                
                HStack(alignment: .center) {
                    NodeRowPortView(graph: graph,
                                    node: node,
                                    rowObserver: rowObserver,
                                    rowViewModel: rowViewModel)
                    
                    HStack(alignment: isMultiField ? .firstTextBaseline : .center) {
                        LabelDisplayView(label: rowObserver
                        // Note: Label is based on row observer's node, which in the case of a group node will be for an underlying splitter patch node, not the group node itself
                            .label(node: node,
                                   coordinate: .input(rowObserver.id),
                                   graph: graph),
                                         isLeftAligned: false,
                                         fontColor: STITCH_FONT_GRAY_COLOR,
                                         isSelectedInspectorRow: false)
                        
                        ForEach(rowViewModel.fieldValueTypes) { fieldGroupViewModel in
                            ForEach(fieldGroupViewModel.fieldObservers) { fieldViewModel in
                                self.valueEntryView(rowObserver: rowObserver,
                                                    rowViewModel: rowViewModel,
                                                    portViewModel: fieldViewModel,
                                                    isMultiField: isMultiField)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct DefaultNodeOutputView: View {
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var node: NodeViewModel
    @Bindable var canvas: CanvasItemViewModel
    let isNodeSelected: Bool
    
    // Most splitters do NOT show their outputs;
    // however, a group node's output-splitters seen from the same level as the group node (i.e. not inside the group node itself, but where)
    @MainActor
    var showOutputFields: Bool {
        
        if self.node.kind == .patch(.splitter) {
            
            // A regular (= inline) splitter NEVER shows its output
            let isRegularSplitter = node.patchNodeViewModel?.splitterType == .inline
            if isRegularSplitter {
                return false
            }
            
            // If this is a group output splitter, AND we are looking at the group node itself (i.e. NOT inside of the group node but "above" it),
            // then show the output splitter's fields.
            let isOutputSplitter = node.patchNodeViewModel?.splitterType == .output
            if isOutputSplitter {
                // See `NodeRowObserver.label()` for similar logic for *inputs*
                let parentGroupNode = node.patchNodeViewModel?.parentGroupNodeId
                let currentTraversalLevel = document.groupNodeFocused?.groupNodeId
                return parentGroupNode != currentTraversalLevel
            }
            
            return false
        }
        
        return true
    }
    
    var body: some View {
        DefaultNodeRowView(graph: graph,
                           node: node,
                           canvas: canvas,
                           rowViewModels: canvas.outputViewModels,
                           nodeIO: .output) { rowViewModel in
            if let portId = rowViewModel.id.portType.portId,
               let rowObserver = node.getOutputRowObserverForUI(for: portId, graph) {
                let isMultiField = (rowViewModel.fieldValueTypes.first?.fieldObservers.count ?? 0) > 1
                
                HStack {
                    if showOutputFields {
                        ForEach(rowViewModel.fieldValueTypes) { fieldGroupViewModel in
                            ForEach(fieldGroupViewModel.fieldObservers) { fieldViewModel in
                                OutputValueEntry(graph: graph,
                                                 graphUI: document,
                                                 viewModel: fieldViewModel,
                                                 rowViewModel: rowViewModel,
                                                 rowObserver: rowObserver,
                                                 node: node,
                                                 canvasItem: canvas,
                                                 isMultiField: isMultiField,
                                                 isCanvasItemSelected: isNodeSelected,
                                                 forPropertySidebar: false,
                                                 propertyIsAlreadyOnGraph: false,
                                                 isFieldInMultifieldInput: isMultiField,
                                                 isSelectedInspectorRow: false)
                            }
                        }
                    }
                    
                    LabelDisplayView(label: rowObserver
                        .label(node: node,
                               coordinate: .output(rowObserver.id),
                               graph: graph),
                                     isLeftAligned: false,
                                     fontColor: STITCH_FONT_GRAY_COLOR,
                                     isSelectedInspectorRow: false)
                    
                    NodeRowPortView(graph: graph,
                                    node: node,
                                    rowObserver: rowObserver,
                                    rowViewModel: rowViewModel)
                }
                .modifier(EdgeEditModeOutputHoverViewModifier(
                    graph: graph,
                    document: document,
                    outputCoordinate: .init(portId: rowViewModel.id.portId,
                                            canvasId: canvas.id)))
            }
        }
    }
}

struct DefaultNodeRowView<RowViewModel, RowView>: View where RowViewModel: NodeRowViewModel,
                                                             RowView: View {

    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var canvas: CanvasItemViewModel
    let rowViewModels: [RowViewModel]
    let nodeIO: NodeIO
    @ViewBuilder var rowView: (RowViewModel) -> RowView

    var id: NodeId {
        self.node.id
    }
    
    var nodeKind: NodeKind {
        self.node.kind
    }
    
    var isPatchWithNoRows: Bool {
        switch self.nodeKind {
        case .patch(let patch):
            switch nodeIO {
            case .input:
                return patch.nodeUIKind == .outputsOnly
            case .output:
                return patch.nodeUIKind == .inputsOnly
            }
        default:
            return false
        }
    }

    @MainActor
    var hasEmptyRows: Bool {
        rowViewModels.isEmpty || isPatchWithNoRows
    }

    var alignment: HorizontalAlignment {
        switch nodeIO {
        case .input:
            return .leading
        case .output:
            return .trailing
        }
    }
    
    var body: some View {
        VStack(alignment: self.alignment) {
            // If no rows, create a dummy view to create some empty space
            if hasEmptyRows {
                Color.clear
                    .frame(width: NODE_BODY_SPACING,
                           height: NODE_ROW_HEIGHT)
            } else {
                ForEach(self.rowViewModels) { rowViewModel in
                    self.rowView(rowViewModel)
                    // fixes issue where ports could have inconsistent height with no label
                        .height(NODE_ROW_HEIGHT + 8)
                        .onChange(of: rowViewModel.fieldValueTypes.first?.type) {
                            // Resets node sizing data when either node or portvalue types change
                            canvas.resetViewSizingCache()
                            graph.visibleNodesViewModel.needsInfiniteCanvasCacheReset = true
                        }
                }
            }
        }
    }
}
