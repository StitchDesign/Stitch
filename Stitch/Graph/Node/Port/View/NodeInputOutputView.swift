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
    
    let nodeId: NodeId
    let nodeKind: NodeKind
    let hasIncomingEdge: Bool
    
    // What does this really mean
    let rowObserverId: NodeIOCoordinate
        
    // ONLY for port-view, which is only on canvas items
    let rowObserver: InputNodeRowObserver?
    let rowViewModel: InputNodeRowObserver.RowViewModelType? // i.e. `InputNodeRowViewModel?`
        
    let fieldValueTypes: [FieldGroupTypeData<InputNodeRowViewModel.FieldType>]
    
    let layerInputObserver: LayerInputObserver?
    
    let forPropertySidebar: Bool
    let propertyIsSelected: Bool
    let propertyIsAlreadyOnGraph: Bool
    let isCanvasItemSelected: Bool

    var label: String
    var forFlyout: Bool = false
    
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
    
    var isShadowLayerInputRow: Bool {
        layerInputObserver?.port == SHADOW_FLYOUT_LAYER_INPUT_PROXY
    }
    
    var is3DTransform: Bool {
        layerInputObserver?.port == .transform3D
    }
    
    var body: some View {
        HStack(alignment: hStackAlignment) {
            
            // TODO: is there a better way to build this UI, to avoid the perf-intensive `if/else` branch?
            // We want to show just a single text that, when tapped, opens the flyout; we do not want to show any fields
            if isShadowLayerInputRow, forPropertySidebar, !forFlyout {
                ShadowInputInspectorRow(nodeId: nodeId,
                                        propertyIsSelected: propertyIsSelected)
            }  else {
                
                // Skip the label if we have a 3D transform input but are not in the flyout
                if !(is3DTransform && !forFlyout) {
                    labelView
                }
                
                if forPropertySidebar {
                    Spacer()
                }
                
                // If the input has multiple rows of fields (e.g. 3D Transform)
                // then vertically stack those.
                if is3DTransform {
                    VStack {
                        fieldsListView
                    }
                }
                
                // Vast majority of inputs, however, have a single row of fields.
                // TODO: this part of the UI is not clear; we allow the single row of fields to float up into the enclosing HStack, yet flyouts always vertically stack their fields
                else {
                    fieldsListView
                }
            }
        } // HStack
    }
    
    var fieldsListView: FieldsListView<InputNodeRowViewModel, InputValueEntry> {
        FieldsListView<InputNodeRowViewModel, InputValueEntry>(
            graph: graph,
            fieldValueTypes: fieldValueTypes,
            nodeId: nodeId,
            forPropertySidebar: forPropertySidebar,
            forFlyout: forFlyout,
            blockedFields: layerInputObserver?.blockedFields,
            valueEntryView: valueEntryView)
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
            
            // Hide outputs for value node
            if !isSplitter {
                FieldsListView<OutputNodeRowViewModel, OutputValueEntry>(
                    graph: graph,
                    fieldValueTypes: rowViewModel.fieldValueTypes,
                    nodeId: nodeId,
                    forPropertySidebar: forPropertySidebar,
                    forFlyout: false, // Outputs do not use flyouts
                    blockedFields: nil, // Always nil for output fields
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
    let blockedFields: LayerPortTypeSet?

    @ViewBuilder var valueEntryView: (PortType.FieldType, Bool) -> ValueEntryView
    
    var body: some View {
     
        let multipleFieldGroups = fieldValueTypes.count > 1
        
        ForEach(fieldValueTypes) { (fieldGroupViewModel: FieldGroupTypeData<PortType.FieldType>) in
            
            let multipleFieldsPerGroup = fieldGroupViewModel.fieldObservers.count > 1
            
            // Note: "multifield" is more complicated for layer inputs, since `fieldObservers.count` is now inaccurate for an unpacked port
            let isMultiField = forPropertySidebar ?  (multipleFieldGroups || multipleFieldsPerGroup) : fieldGroupViewModel.fieldObservers.count > 1
            
            if !self.isAllFieldsBlockedOut(fieldGroupViewModel: fieldGroupViewModel) {
                NodeFieldsView(graph: graph,
                               fieldGroupViewModel: fieldGroupViewModel,
                               nodeId: nodeId,
                               isMultiField: isMultiField,
                               forPropertySidebar: forPropertySidebar,
                               forFlyout: forFlyout,
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
        self.rowObserver.nodeDelegate?.kind.isGroup ?? false
    }
    
    var document: StitchDocumentViewModel {
        guard let doc = graph.documentDelegate else {
            fatalErrorIfDebug()
            return .createEmpty()
        }
        
        return doc
    }
    
    var body: some View {
        PortEntryView(rowViewModel: rowViewModel,
                      graph: graph,
                      graphMultigesture: document.graphMovement.graphMultigesture,
                      zoomData: document.graphMovement.zoomData,
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
        .popover(isPresented: self.$showPopover) {
            // Note: there is a bug where the first time this view-closure would fire (when `self.showPopover` set `true`), the closure's `self.showPopover` was somehow still `false`, so the popover opened with an `EmptyView`
            // Perf-wise, we do not need the `if self.showPopover` check because `PortValuesPreviewView` only re-renders when the popover is open.
            PortValuesPreviewView(rowObserver: rowObserver,
                                  rowViewModel: rowViewModel,
                                  nodeIO: nodeIO)
        }
    }
}
