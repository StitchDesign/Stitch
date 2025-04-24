//
//  NodeViewType.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/11/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct CanvasLayerInputViewWrapper: View {
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var node: NodeViewModel
    @Bindable var canvasNode: CanvasItemViewModel
    
    // Should this be bindable or not?
    @Bindable var layerNode: LayerNodeViewModel
    let layerInputCoordinate: LayerInputCoordinate
    let isNodeSelected: Bool
    
    var body: some View {
        // A layer canvas item, whether whole input (packed) or just a field (unpacked), will use the same LayerInputObserver
        
        // Retrieve the port-observer for this canvas item
        if let rowObserver = node.getInputRowObserver(for: .keyPath(layerInputCoordinate.keyPath)),
            // CanvasItem for a canvas layer input should only contain a single input row view model?
           let rowViewModel = self.canvasNode.inputViewModels.first {
                        
            let layerInputObserver: LayerInputObserver = layerNode.getLayerInputObserver(layerInputCoordinate.keyPath.layerInput)
            
            HStack {
                NodeRowPortView(graph: graph,
                                node: node,
                                rowObserver: rowObserver,
                                rowViewModel: rowViewModel)
                
                CanvasLayerInputView(document: document,
                                     graph: graph,
                                     node: node,
                                     canvasNode: canvasNode,
                                     layerInputObserver: layerInputObserver,
                                     inputRowObserver: rowObserver,
                                     inputRowViewModel: rowViewModel,
                                     isNodeSelected: isNodeSelected)
            }
            
        } else {
            EmptyView()
                .onAppear {
                    fatalErrorIfDebug()
                }
        }
        
    }
}

// Used just for patches' and group nodes' inputs
struct DefaultNodeInputsView: View {
    
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
                        document: document,
                        viewModel: portViewModel,
                        node: node,
                        rowViewModel: rowViewModel,
                        canvasItem: canvas,
                        rowObserver: rowObserver,
                        isCanvasItemSelected: isNodeSelected,
                        hasIncomingEdge: rowObserver.upstreamOutputCoordinate.isDefined,
                        isForLayerInspector: false,
                        isPackedLayerInputAlreadyOnCanvas: false, // Always false for patch and group node inputs
                        isFieldInMultifieldInput: isMultiField,
                        isForFlyout: false,
                        isSelectedInspectorRow: false,
                        useIndividualFieldLabel: true)
    }
    
    var body: some View {
        DefaultNodeRowsView(graph: graph,
                       node: node,
                       canvas: canvas,
                       rowViewModels: canvas.inputViewModels,
                       nodeIO: .input) { rowViewModel in
            if let rowObserver = node.getInputRowObserverForUI(for: rowViewModel.id.portType, graph) {
                
                let isMultiField = (rowViewModel.cachedFieldValueGroups.first?.fieldObservers.count ?? 0) > 1
                
                HStack(alignment: .center) {
                    NodeRowPortView(graph: graph,
                                    node: node,
                                    rowObserver: rowObserver,
                                    rowViewModel: rowViewModel)
                    
                    HStack(alignment: isMultiField ? .firstTextBaseline : .center) {
                        // Note: Label is based on row observer's node, which in the case of a group node will be for an underlying splitter patch node, not the group node itself
                        LabelDisplayView(label: rowObserver.label(node: node,
                                                                  coordinate: .input(rowObserver.id),
                                                                  graph: graph),
                                         isLeftAligned: false,
                                         fontColor: STITCH_FONT_GRAY_COLOR,
                                         isSelectedInspectorRow: false)
                        
                        ForEach(rowViewModel.cachedFieldValueGroups) { fieldGroupViewModel in
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

// Common to ALL outputs, whether patch, group or layer
struct DefaultNodeOutputsView: View {
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var node: NodeViewModel
    @Bindable var canvas: CanvasItemViewModel
    let isNodeSelected: Bool

    @MainActor
    var showOutputFields: Bool {

        // Most patches (except for splitters nodes, under certain conditions) have/show outputs.
        guard let patchNode = node.patchNode,
              let splitterType = patchNode.splitterType else {
            return true
        }
        
        // If this is a group output splitter,
        // AND we are looking at the group node itself (i.e. NOT inside of the group node but "above" it),
        // then show the output splitter's fields.
        if splitterType == .output {
            // See `NodeRowObserver.label()` for similar logic for *inputs*
            let parentGroupNode = patchNode.parentGroupNodeId
            let currentTraversalLevel = document.groupNodeFocused?.groupNodeId
            return parentGroupNode != currentTraversalLevel
        } else {
            return false
        }
    }
    
    var body: some View {
        DefaultNodeRowsView(graph: graph,
                       node: node,
                       canvas: canvas,
                       rowViewModels: canvas.outputViewModels,
                       nodeIO: .output) { rowViewModel in
            if let portId = rowViewModel.id.portType.portId,
               let rowObserver = node.getOutputRowObserverForUI(for: portId, graph) {
                let isMultiField = (rowViewModel.cachedFieldValueGroups.first?.fieldObservers.count ?? 0) > 1
                
                HStack {
                    if showOutputFields {
                        ForEach(rowViewModel.cachedFieldValueGroups) { fieldGroupViewModel in
                            ForEach(fieldGroupViewModel.fieldObservers) { fieldViewModel in
                                OutputValueEntry(graph: graph,
                                                 document: document,
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

// fka `DefaultNodeRowView`
// Used by patch and group-node inputs (but not layer inputs) and ALL ouputs (patch, group, layer)
struct DefaultNodeRowsView<RowViewModel, RowView>: View where RowViewModel: NodeRowViewModel,
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
                        .modifier(CanvasPortHeightModifier())
                        .onChange(of: rowViewModel.cachedFieldValueGroups.first?.type) {
                            // Resets node sizing data when either node or portvalue types change
                            canvas.resetViewSizingCache()
                            
                            if !graph.visibleNodesViewModel.needsInfiniteCanvasCacheReset {
                                graph.visibleNodesViewModel.needsInfiniteCanvasCacheReset = true
                            }
                        }
                }
            }
        }
    }
}
