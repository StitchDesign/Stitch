//
//  NodeInputView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

/*
 Patch node input of Point4D = one node row observer becomes 4 fields
 
 Layer node input of Size = one node row observer becomes 1 single field
 */
struct NodeInputView: View {
    
    @Environment(\.appTheme) var theme
    
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    
    let node: NodeViewModel
    let hasIncomingEdge: Bool
        
    let rowObserver: InputNodeRowObserver
    let rowViewModel: InputNodeRowObserver.RowViewModelType
    let fieldValueTypes: [FieldGroupTypeData<InputNodeRowViewModel.FieldType>]
    let canvasItem: CanvasItemViewModel?
    let layerInputObserver: LayerInputObserver?
    
    let forPropertySidebar: Bool
    let propertyIsSelected: Bool
    let propertyIsAlreadyOnGraph: Bool
    let isCanvasItemSelected: Bool

    var label: String
    var forFlyout: Bool = false

    @ViewBuilder @MainActor
    func valueEntryView(portViewModel: InputFieldViewModel,
                        isMultiField: Bool) -> InputValueEntry {
        InputValueEntry(graph: graph,
                        graphUI: graphUI,
                        viewModel: portViewModel,
                        node: node,
                        rowViewModel: rowViewModel,
                        layerInputObserver: layerInputObserver,
                        canvasItem: canvasItem,
                        rowObserver: rowObserver,
                        isCanvasItemSelected: isCanvasItemSelected,
                        hasIncomingEdge: hasIncomingEdge,
                        forPropertySidebar: forPropertySidebar,
                        propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                        isFieldInMultifieldInput: isMultiField,
                        isForFlyout: forFlyout,
                        isSelectedInspectorRow: propertyIsSelected)
    }
    
    var layerInput: LayerInputPort? {
        layerInputObserver?.port
    }
    
    var isShadowLayerInputRow: Bool {
        layerInput == SHADOW_FLYOUT_LAYER_INPUT_PROXY
    }
    
    var is3DTransform: Bool {
        layerInput == .transform3D
    }
    
    /// Skip the label if we have a 3D transform or 3D size input but are not in the flyout.
    var willShowLabel: Bool {
        if forFlyout {
            return true
        }
        return self.layerInputObserver?.port.showsLabelForInspector ?? true
    }
    
    var body: some View {
        HStack(alignment: hStackAlignment) {
            
            if let layerInputObserver = layerInputObserver {
                logInView("NodeInputView: layerInputObserver.usesMultifields: \(layerInputObserver.usesMultifields)")
            }
            
            // TODO: is there a better way to build this UI, to avoid the perf-intensive `if/else` branch?
            // We want to show just a single text that, when tapped, opens the flyout; we do not want to show any fields
            if isShadowLayerInputRow, forPropertySidebar, !forFlyout {
                ShadowInputInspectorRow(nodeId: node.id,
                                        propertyIsSelected: propertyIsSelected)
            }  else {
                if willShowLabel {
                    labelView
                }
                
                if forPropertySidebar {
                    Spacer()
                }
                
                // If the input has multiple rows of fields (e.g. 3D Transform)
                // then vertically stack those.
                if is3DTransform {
                    VStack {
                        fieldsListView(fieldValueTypes)
                    }
                }
                
                /*
                 When packed, `margin` has one row observer with four field models (which can be handled by NodeFieldsView)
                 When unpacked, `margin` has four row observers with one field model each.
                 
                 TODO: we need an API that abstracts away "packed vs unpacked" layer input's differing row observer and field model counts; "packed vs unpacked" is just for canvas items and should not affect layer inspector display
                 */
                else if forPropertySidebar,
                   layerInput == .layerMargin || layerInput == .padding,
                   layerInputObserver?.mode == .unpacked,
                   let f0 = fieldValueTypes[safeIndex: 0],
                   let f1 = fieldValueTypes[safeIndex: 1],
                   let f2 = fieldValueTypes[safeIndex: 2],
                   let f3 = fieldValueTypes[safeIndex: 3] {
                    
                    VStack {
                        HStack {
                            // Individual fields for PortValue.padding can never be blocked; only the input as a whole can be blocked
                            fieldsListView([f0])
                            fieldsListView([f1])
                        }
                        HStack {
                            fieldsListView([f2])
                            fieldsListView([f3])
                        }
                    }
                }
                
                // Vast majority of inputs, however, have a single row of fields.
                // TODO: this part of the UI is not clear; we allow the single row of fields to float up into the enclosing HStack, yet flyouts always vertically stack their fields
                else {
                    fieldsListView(fieldValueTypes)
                }
            }
        } // HStack
    }
    
    func fieldsListView(_ fieldValueTypes: [FieldGroupTypeData<InputNodeRowViewModel.FieldType>]) -> FieldsListView<InputNodeRowViewModel, InputValueEntry> {
        
        FieldsListView<InputNodeRowViewModel, InputValueEntry>(
            graph: self.graph,
            fieldValueTypes: fieldValueTypes,
            nodeId: self.node.id,
            forPropertySidebar: self.forPropertySidebar,
            forFlyout: self.forFlyout,
            layerInputObserver: self.layerInputObserver,
            valueEntryView: self.valueEntryView)
    }
    
    @ViewBuilder @MainActor
    var labelView: LabelDisplayView {
        LabelDisplayView(label: label,
                         isLeftAligned: false,
                         fontColor: STITCH_FONT_GRAY_COLOR,
                         isSelectedInspectorRow: propertyIsSelected)
    }
    
    // Needed for alignment of e.g. Packed vs Unpacked layer inputs for Margin, Padding
    var hStackAlignment: VerticalAlignment {
        
        // Several ways an input can be "multifield":
        // 1. patch node input or packed layer node input: one fieldValue type with multiple field observers
        // 2. unpacked layer node input: multuple field value types with one field observer each
        // 3. patch node input for shape commands (IGNORED FOR NOW?)
        let isMultifield = self.layerInputObserver?.usesMultifields ?? ((fieldValueTypes.first?.fieldObservers.count ?? 0) > 1)
        
        return (forPropertySidebar && isMultifield) ? .firstTextBaseline : .center
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
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    @Bindable var node: NodeViewModel
    @Bindable var rowObserver: OutputNodeRowObserver
    @Bindable var rowViewModel: OutputNodeRowObserver.RowViewModelType
    let canvasItem: CanvasItemViewModel?
    let forPropertySidebar: Bool
    let propertyIsSelected: Bool
    let propertyIsAlreadyOnGraph: Bool
    let isCanvasItemSelected: Bool
    let label: String
    
    var nodeId: NodeId {
        self.rowObserver.id.nodeId
    }
    
    @MainActor
    var nodeKind: NodeKind {
        node.kind
    }
    
    // Most splitters do NOT show their outputs;
    // however, a group node's output-splitters seen from the same level as the group node (i.e. not inside the group node itself, but where)
    @MainActor
    var showOutputFields: Bool {
                
        if self.nodeKind == .patch(.splitter) {

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
                let currentTraversalLevel = graph.groupNodeFocused
                return parentGroupNode != currentTraversalLevel
            }
            
            return false
        }
        
        return true
    }
        
    @ViewBuilder @MainActor
    func valueEntryView(portViewModel: OutputFieldViewModel,
                        isMultiField: Bool) -> OutputValueEntry {
        OutputValueEntry(graph: graph,
                         graphUI: graphUI,
                         viewModel: portViewModel,
                         rowViewModel: rowViewModel,
                         rowObserver: rowObserver,
                         node: node,
                         canvasItem: canvasItem,
                         isMultiField: isMultiField,
                         isCanvasItemSelected: isCanvasItemSelected,
                         forPropertySidebar: forPropertySidebar,
                         propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                         isFieldInMultifieldInput: isMultiField,
                         isSelectedInspectorRow: propertyIsSelected)
    }
    
    var body: some View {
        HStack(alignment: forPropertySidebar ? .firstTextBaseline: .center) {
            // Property sidebar always shows labels on left side, never right
            if forPropertySidebar {
                labelView
                Spacer()
            }
            
            if showOutputFields {
                FieldsListView<OutputNodeRowViewModel, OutputValueEntry>(
                    graph: graph,
                    fieldValueTypes: rowViewModel.fieldValueTypes,
                    nodeId: nodeId,
                    forPropertySidebar: forPropertySidebar,
                    forFlyout: false, // Outputs do not use flyouts
                    layerInputObserver: nil,
                    valueEntryView: valueEntryView)
            }
            
            if !forPropertySidebar {
                labelView
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
}

struct FieldsListView<PortType, ValueEntryView>: View where PortType: NodeRowViewModel, ValueEntryView: View {

    @Bindable var graph: GraphState

    var fieldValueTypes: [FieldGroupTypeData<PortType.FieldType>]
    let nodeId: NodeId
    let forPropertySidebar: Bool
    let forFlyout: Bool
    let layerInputObserver: LayerInputObserver?
    
    // When displaying an individual field, we often want to know whether it is one of many, so as to not display adjustment bar button, certain lavels etc.
    
    // Actually, this is really determined by the layer input observer's type.
    var blockedFields: LayerPortTypeSet? {
        layerInputObserver?.blockedFields
    }
    
    var layerInputUsesMultifields: Bool {
        layerInputObserver?.usesMultifields ?? false
    }
    
    @ViewBuilder var valueEntryView: (PortType.FieldType, Bool) -> ValueEntryView

    var body: some View {
     
//        let multipleFieldGroups = fieldValueTypes.count > 1
        let isMultifield = layerInputUsesMultifields || fieldValueTypes.count > 1
        
        ForEach(fieldValueTypes) { (fieldGroupViewModel: FieldGroupTypeData<PortType.FieldType>) in
            
            let multipleFieldsPerGroup = fieldGroupViewModel.fieldObservers.count > 1
            
            // Note: "multifield" is more complicated for layer inputs, since `fieldObservers.count` is now inaccurate for an unpacked port
            let _isMultiField = forPropertySidebar ?  (isMultifield || multipleFieldsPerGroup) : fieldGroupViewModel.fieldObservers.count > 1
                        
            if !self.isAllFieldsBlockedOut(fieldGroupViewModel: fieldGroupViewModel) {
                NodeFieldsView(graph: graph,
                               fieldGroupViewModel: fieldGroupViewModel,
                               nodeId: nodeId,
                               isMultiField: _isMultiField,
                               forPropertySidebar: forPropertySidebar,
                               forFlyout: forFlyout,
                               layerInputObserver: layerInputObserver,
                               blockedFields: blockedFields,
                               valueEntryView: valueEntryView)
            }
        }
    }
    
    func isAllFieldsBlockedOut(fieldGroupViewModel: FieldGroupTypeData<PortType.FieldType>) -> Bool {
        if let blockedFields = blockedFields {
            return fieldGroupViewModel.fieldObservers.allSatisfy {
                $0.isBlocked(blockedFields)
            }
        }
        return false
    }
}

struct NodeRowPortView<NodeRowObserverType: NodeRowObserver>: View {
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var rowObserver: NodeRowObserverType
    @Bindable var rowViewModel: NodeRowObserverType.RowViewModelType
    
    @State private var showPopover: Bool = false
    
    var coordinate: NodeIOPortType {
        self.rowObserver.id.portType
    }
    
    var nodeIO: NodeIO {
        NodeRowObserverType.nodeIOType
    }
    
    // should be passed down as a param
    @MainActor
    var isGroup: Bool {
        node.kind.isGroup
    }
    
    var body: some View {
        PortEntryView(rowViewModel: rowViewModel,
                      graph: graph,
                      coordinate: coordinate)
        .onTapGesture {
            // Can only tap canvas ports, not layer inspector ports
            guard let canvasItemId = rowViewModel.canvasItemDelegate?.id else {
                return
            }

            // Do nothing when input/output doesn't contain a loop
            if rowObserver.hasLoopedValues {
                dispatch(PortPreviewOpened(port: self.rowObserver.id,
                                           nodeIO: nodeIO,
                                           canvasItemId: canvasItemId))
                
            }
        }
    }
}
