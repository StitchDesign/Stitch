//
//  NodeInputView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

struct LayerInspectorRowButton: View {
    
    @Environment(\.appTheme) var theme
    
    let layerInputObserver: LayerInputObserver?
    let layerInspectorRowId: LayerInspectorRowId
    let coordinate: NodeIOCoordinate
    let canvasItemId: CanvasItemId?
    let isPortSelected: Bool
    let isHovered: Bool
    
    @MainActor
    var isWholeInputWithAtleastOneFieldAlreadyOnCanvas: Bool {
        if case let .layerInput(layerInputType) = layerInspectorRowId,
           layerInputType.portType == .packed,
           let layerInputObserver = layerInputObserver,
           layerInputObserver.observerMode.isUnpacked,
           !layerInputObserver.getAllCanvasObservers().isEmpty {
            return true
        }
        
        return false
    }
    
    @MainActor
    var canBeAddedToCanvas: Bool {
        
        // If this is a button for a whole input,
        // and then input already has a field on the canvas,
        // then we cannot add the whole input to the canvas
        if isWholeInputWithAtleastOneFieldAlreadyOnCanvas {
            return false
        }
        
        switch layerInspectorRowId {
        case .layerInput(let layerInputType):
            return layerInputType.layerInput != SHADOW_FLYOUT_LAYER_INPUT_PROXY
        case .layerOutput:
            return true
        }
    }
    
    @MainActor
    var showButton: Bool {
        if canvasItemId.isDefined || isWholeInputWithAtleastOneFieldAlreadyOnCanvas ||  isHovered || (canBeAddedToCanvas && isPortSelected) {
            return true
        } else {
            return false
        }
    }
    
    @MainActor
    var imageString: String {
        if canvasItemId.isDefined {
            return "scope"
        } else if isWholeInputWithAtleastOneFieldAlreadyOnCanvas {
            return "circle.fill"
        } else {
            return "plus.circle"
        }
    }
        
    var body: some View {
        
        button(imageString: imageString) {
            
            let nodeId = coordinate.nodeId
            
            // If we're already on the canvas, jump to that canvas item
            if let canvasItemId = canvasItemId {
                dispatch(JumpToCanvasItem(id: canvasItemId))
            } 
            
            // Else we're adding an input (whole or field) or an output to the canvas
            else if let layerInput = coordinate.keyPath {
                dispatch(LayerInputAddedToGraph(
                    nodeId: nodeId,
                    coordinate: layerInput))
            } else if let portId = coordinate.portId {
                dispatch(LayerOutputAddedToGraph(nodeId: nodeId,
                                                 portId: portId))
            }
        }
        // Shrink down the dot view
        .scaleEffect(isWholeInputWithAtleastOneFieldAlreadyOnCanvas ? 0.5 : 1)
        
        // Only show the dot / plus button if we're hovering or row is selected or ...
        .opacity(showButton ? 1 : 0)
        
        .animation(.linear(duration: 0.1), value: showButton)
    }
    
    @MainActor
    func button(imageString: String,
                onTap: @escaping () -> Void) -> some View {
        Image(systemName: imageString)
            .resizable()
            .foregroundColor(isPortSelected ? theme.fontColor : .primary)
            .frame(width: LAYER_INSPECTOR_ROW_ICON_LENGTH,
                   height: LAYER_INSPECTOR_ROW_ICON_LENGTH) // per Figma
            .onTapGesture {
                onTap()
            }
    }
}

/*
 Patch node input of Point4D = one node row observer becomes 4 fields
 
 Layer node input of Size = one node row observer becomes 1 single field
 */
struct NodeInputView: View {
    
    @Environment(\.appTheme) var theme
    
    @State private var showPopover: Bool = false
    
    @Bindable var graph: GraphState
    
    let nodeId: NodeId
    let nodeKind: NodeKind
    let hasIncomingEdge: Bool
    
    // What does this really mean
    let rowObserverId: NodeIOCoordinate
        
    // ONLY for port-view, which is only on canvas items
    let rowObserver: InputNodeRowObserver?
    let rowViewModel: InputNodeRowObserver.RowViewModelType? // i.e. `InputNodeRowViewModel?`
        
    let fieldValueTypes: [FieldGroupTypeViewModel<InputNodeRowViewModel.FieldType>]
    
    let layerInputObserver: LayerInputObserver?
    
    let forPropertySidebar: Bool
    let propertyIsSelected: Bool
    let propertyIsAlreadyOnGraph: Bool
    let isCanvasItemSelected: Bool

    var label: String
    var forFlyout: Bool = false
    
    var isShadowLayerInputRow: Bool {
        layerInputObserver?.port == SHADOW_FLYOUT_LAYER_INPUT_PROXY
    }
    
    @MainActor
    private var graphUI: GraphUIState {
        self.graph.graphUI
    }
    
    @ViewBuilder @MainActor
    func valueEntryView(portViewModel: InputFieldViewModel,
                        isMultiField: Bool) -> InputValueEntry {
        InputValueEntry(graph: graph,
                        viewModel: portViewModel,
                        layerInputObserver: layerInputObserver,
                        rowObserverId: rowObserverId,
                        nodeKind: nodeKind,
                        isCanvasItemSelected: isCanvasItemSelected,
                        hasIncomingEdge: hasIncomingEdge,
                        forPropertySidebar: forPropertySidebar,
                        propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                        isFieldInMultifieldInput: isMultiField,
                        isForFlyout: forFlyout,
                        isSelectedInspectorRow: propertyIsSelected)
    }
    
    var body: some View {
        // For multifields, want the overall label to sit at top of fields' VStack.
        // For single fields, want to the overall label t
        HStack(alignment: hStackAlignment) {
            
            // Alternatively, pass `NodeRowPortView` as a closure like we do with ValueEntry view etc.?
            if !forPropertySidebar,
               let rowObserver = rowObserver,
               let rowViewModel = rowViewModel {
                NodeRowPortView(graph: graph,
                                rowObserver: rowObserver,
                                rowViewModel: rowViewModel,
                                showPopover: $showPopover)
            }
            
            if isShadowLayerInputRow, forPropertySidebar, !forFlyout {
                ShadowInputInspectorRow(nodeId: nodeId,
                                        propertyIsSelected: propertyIsSelected)
            } else {
                labelView
                
                if forPropertySidebar {
                    Spacer()
                }
                
                FieldsListView<InputNodeRowViewModel, InputValueEntry>(
                    graph: graph,
                    fieldValueTypes: fieldValueTypes,
                    nodeId: nodeId,
                    forPropertySidebar: forPropertySidebar,
                    blockedFields: layerInputObserver?.blockedFields,
                    valueEntryView: valueEntryView)
            }
        } // HStack
    }
    
    @ViewBuilder @MainActor
    var labelView: LabelDisplayView {
        LabelDisplayView(label: label,
                         isLeftAligned: false,
                         fontColor: STITCH_FONT_GRAY_COLOR,
                         isSelectedInspectorRow: propertyIsSelected)
    }
    
    // Only needed for Shadow Flyout's Shadow Offset multifield-input?
    var hStackAlignment: VerticalAlignment {
        let isMultiField = (fieldValueTypes.first?.fieldObservers.count ?? 0) > 1
        return (forPropertySidebar && isMultiField) ? .firstTextBaseline : .center
    }
}

struct ShadowInputInspectorRow: View {
    
    @Environment(\.appTheme) var theme
    
    let nodeId: NodeId
    let propertyIsSelected: Bool
    
    var body: some View {
        HStack {
            StitchTextView(string: "Shadow",
                           fontColor: propertyIsSelected ? theme.fontColor : STITCH_FONT_GRAY_COLOR)
            Spacer()
        }
        .overlay {
            Color.white.opacity(0.001)
                .onTapGesture {
                    dispatch(FlyoutToggled(
                        flyoutInput: SHADOW_FLYOUT_LAYER_INPUT_PROXY,
                        flyoutNodeId: nodeId,
                        // No particular field to focus
                        fieldToFocus: nil))
                }
        }
    }
}

struct NodeOutputView: View {
    @State private var showPopover: Bool = false
    
    @Bindable var graph: GraphState
    
    @Bindable var rowObserver: OutputNodeRowObserver
    @Bindable var rowViewModel: OutputNodeRowObserver.RowViewModelType
    let forPropertySidebar: Bool
    let propertyIsSelected: Bool
    let propertyIsAlreadyOnGraph: Bool
    let isCanvasItemSelected: Bool
    let label: String
    
    @MainActor
    private var graphUI: GraphUIState {
        self.graph.graphUI
    }
    
    var nodeId: NodeId {
        self.rowObserver.id.nodeId
    }
    
    @MainActor
    var nodeKind: NodeKind {
        self.rowObserver.nodeDelegate?.kind ?? .patch(.splitter)
    }
    
    @MainActor
    var isSplitter: Bool {
        self.nodeKind == .patch(.splitter)
    }
        
    @ViewBuilder @MainActor
    func valueEntryView(portViewModel: OutputFieldViewModel,
                        isMultiField: Bool) -> OutputValueEntry {
        OutputValueEntry(graph: graph,
                         viewModel: portViewModel,
                         coordinate: rowObserver.id,
                         isMultiField: isMultiField,
                         nodeKind: nodeKind,
                         isCanvasItemSelected: isCanvasItemSelected,
                         forPropertySidebar: forPropertySidebar,
                         propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                         isSelectedInspectorRow: propertyIsSelected)
    }
    
    var body: some View {
        HStack(alignment: forPropertySidebar ? .firstTextBaseline: .center) {
            // Property sidebar always shows labels on left side, never right
            if forPropertySidebar {
                labelView
            }
            
            // Hide outputs for value node
            if !isSplitter {
                
                FieldsListView<OutputNodeRowViewModel, OutputValueEntry>(
                    graph: graph,
                    fieldValueTypes: rowViewModel.fieldValueTypes,
                    nodeId: nodeId,
                    forPropertySidebar: forPropertySidebar,
                    blockedFields: nil, // Always nil for output fields
                    valueEntryView: valueEntryView)
            }
            
            if !forPropertySidebar {
                labelView
                NodeRowPortView(graph: graph,
                                rowObserver: rowObserver,
                                rowViewModel: rowViewModel,
                                showPopover: $showPopover)
            }
        } // HStack
        .modifier(EdgeEditModeOutputViewModifier(
            graphState: graph,
            portId: rowViewModel.id.portId,
            canvasItemId: self.rowViewModel.canvasItemDelegate?.id,
            forPropertySidebar: forPropertySidebar))
    }
    
    @ViewBuilder @MainActor
    var labelView: LabelDisplayView {
        LabelDisplayView(label: label,
                         isLeftAligned: false,
                         fontColor: STITCH_FONT_GRAY_COLOR,
                         isSelectedInspectorRow: propertyIsSelected)
    }
}

struct FieldsListView<PortType, ValueEntryView>: View where PortType: NodeRowViewModel, ValueEntryView: View {

    @Bindable var graph: GraphState

    var fieldValueTypes: [FieldGroupTypeViewModel<PortType.FieldType>]
    let nodeId: NodeId
    let forPropertySidebar: Bool
    let blockedFields: LayerPortTypeSet?

    @ViewBuilder var valueEntryView: (PortType.FieldType, Bool) -> ValueEntryView
    
    var body: some View {
     
        let multipleFieldGroups = fieldValueTypes.count > 1
        
        ForEach(fieldValueTypes) { (fieldGroupViewModel: FieldGroupTypeViewModel<PortType.FieldType>) in
            
            let multipleFieldsPerGroup = fieldGroupViewModel.fieldObservers.count > 1
            
            // Note: "multifield" is more complicated for layer inputs, since `fieldObservers.count` is now inaccurate for an unpacked port
            let isMultiField = forPropertySidebar ?  (multipleFieldGroups || multipleFieldsPerGroup) : fieldGroupViewModel.fieldObservers.count > 1
                                    
            NodeFieldsView(graph: graph,
                           fieldGroupViewModel: fieldGroupViewModel,
                           nodeId: nodeId,
                           isMultiField: isMultiField,
                           forPropertySidebar: forPropertySidebar,
                           blockedFields: blockedFields,
                           valueEntryView: valueEntryView)
        }
    }
}

struct NodeRowPortView<NodeRowObserverType: NodeRowObserver>: View {
    @Bindable var graph: GraphState
    @Bindable var rowObserver: NodeRowObserverType
    @Bindable var rowViewModel: NodeRowObserverType.RowViewModelType
    
    @Binding var showPopover: Bool
    
    var coordinate: NodeIOPortType {
        self.rowObserver.id.portType
    }
    
    var nodeIO: NodeIO {
        NodeRowObserverType.nodeIOType
    }
    
    // should be passed down as a param
    @MainActor
    var isGroup: Bool {
        self.rowObserver.nodeDelegate?.kind.isGroup ?? false
    }
    
    var body: some View {
        PortEntryView(rowViewModel: rowViewModel,
                      graph: graph,
                      coordinate: coordinate)
        /*
         In practice, seems okay; e.g. Loop node changing from 3 to 1 disables the tap, and changing from 1 to 3 enables the tap.
         */
        .onTapGesture {
            // Do nothing when input/output doesn't contain a loop
            if rowObserver.hasLoopedValues {
                self.showPopover.toggle()
            } else {
                // If input/output count is no longer a loop,
                // any tap should just close the popover.
                self.showPopover = false
            }
        }
        // TODO: get popover to work with all values
        .popover(isPresented: $showPopover) {
            // Conditional is a hack that cuts down on perf
            if showPopover {
                PortValuesPreviewView(rowObserver: rowObserver,
                                      nodeIO: nodeIO)
            }
        }
    }
}
