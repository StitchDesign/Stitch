//
//  LayerInspectorPortView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/24.
//

import SwiftUI
import StitchSchemaKit

struct LayerInspectorInputPortView: View {
    @Bindable var layerInputObserver: LayerInputObserver
    @Bindable var graph: GraphState
    @Bindable var graphUI: StitchDocumentViewModel
    let node: NodeViewModel
            
    var isShadowLayerInputRow: Bool {
        self.layerInputObserver.port == SHADOW_FLYOUT_LAYER_INPUT_PROXY
    }
    
    var body: some View {
        
        let observerMode = layerInputObserver.observerMode
        
        let layerInputType = LayerInputType(layerInput: layerInputObserver.port,
                                            // Always `.packed` at the inspector-row level
                                            portType: .packed)
        
        let layerInspectorRowId: LayerInspectorRowId = .layerInput(layerInputType)
        
        // We pass down coordinate because that can be either for an input (added whole input to the graph) or output (added whole output to the graph, i.e. a port id)
        // But now, what `AddLayerPropertyToGraphButton` needs is more like `RowCoordinate = LayerPortCoordinate || OutputCoordinate`
        
        // but canvas item view model needs to know "packed vs unpacked" for its id;
        // so we do need to pass the packed-vs-unpacked information
        
        let coordinate: NodeIOCoordinate = .init(
            portType: .keyPath(layerInputType),
            nodeId: node.id)
        
        // Does this inspector-row (the entire input) have a canvas item?
        let canvasItemId: CanvasItemId? = observerMode.isPacked ? layerInputObserver._packedData.canvasObserver?.id : nil
        
        LayerInspectorPortView(layerInputObserver: layerInputObserver,
                               layerInspectorRowId: layerInspectorRowId,
                               coordinate: coordinate,
                               graph: graph,
                               graphUI: graphUI,
                               canvasItemId: canvasItemId) { propertyRowIsSelected in
                    HStack {
                        if isShadowLayerInputRow {
                            ShadowInputInspectorRow(nodeId: node.id,
                                                    propertyIsSelected: propertyRowIsSelected)
                        } else if layerInputObserver.usesMultifields {
                            // Multifields in the inspector are always "read-only" and "tap to open flyout"
                            InspectorLayerMultifieldInputView(
                                document: graphUI,
                                graph: graph,
                                node: node,
                                layerInputObserver: layerInputObserver)
                        } else {
                            InspectorLayerInputView(
                                document: graphUI,
                                graph: graph,
                                node: node,
                                layerInputObserver: layerInputObserver,
                                forFlyout: false)
                        }
                    }
            }
        
        // NOTE: this fires unexpectedly, so we rely on canvas item deletion and `layer input field added to canvas` to handle changes in pack vs unpacked mode.
//            .onChange(of: layerInputObserver.mode) { oldValue, newValue in
//                self.layerInputObserver.wasPackModeToggled()
//            }
    }
}


// fka `LayerNodeInputView`
struct InspectorLayerInputView: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let layerInputObserver: LayerInputObserver
    let forFlyout: Bool
    
    var label: String {
        layerInputObserver
            .overallPortLabel(usesShortLabel: true,
                              node: node,
                              graph: graph)
    }
    
    // Can we really assume that this is packed?
    var layerInputType: LayerInputType {
        LayerInputType.init(layerInput: layerInputObserver.port,
                            portType: .packed)
    }
    
    var layerInspectorRowId: LayerInspectorRowId {
        .layerInput(layerInputType)
    }
    
    var layerInput: LayerInputPort {
        self.layerInputObserver.port
    }
    
    var isShadowLayerInputRow: Bool {
        self.layerInputObserver.port == SHADOW_FLYOUT_LAYER_INPUT_PROXY
    }
    
    var willShowLabel: Bool {
        if forFlyout {
            return true
        }
        return layerInput.showsLabelForInspector
    }
    
    var layerInputData: InputLayerNodeRowData {
        layerInputObserver._packedData
    }
    
    var fieldValueTypes: [FieldGroupTypeData<InputNodeRowViewModel.FieldType>] {
        self.layerInputObserver.fieldValueTypes
    }
    
    var propertyRowIsSelected: Bool {
        graph.propertySidebar.selectedProperty == layerInspectorRowId
    }
    
    @ViewBuilder @MainActor
    func valueEntryView(portViewModel: InputFieldViewModel,
                        isMultiField: Bool) -> InputValueEntry {
        
        InputValueEntry(graph: graph,
                        graphUI: document,
                        viewModel: portViewModel,
                        node: node,
                        rowViewModel: layerInputData.inspectorRowViewModel,
                        canvasItem: nil,
                        rowObserver: layerInputData.rowObserver,
                        isCanvasItemSelected: false,
                        hasIncomingEdge: false,
                        forPropertySidebar: true,
                        // TODO: MARCH 10: this is actually more like "is this field/input on the canvas already? if so, tapping CommonEditingView should NOT focus it"
                        // How was this logic ever correct in the past? It's not by field?
                        
                        // invalid for unpacked multifiple fields on canvas
                        propertyIsAlreadyOnGraph: layerInputObserver.getCanvasItemForWholeInput().isDefined,
                        
                        // Flyout broken with unpacked layer inputs because this passed in param is not accurate for unpacked layer inputs
                        // Should instead look at layer input observer
                        isFieldInMultifieldInput: layerInputObserver.usesMultifields,
                        
                        isForFlyout: forFlyout,
                        isSelectedInspectorRow: propertyRowIsSelected,
                        fieldsRowLabel: layerInputObserver.fieldsRowLabel,
                        useIndividualFieldLabel: layerInputObserver.useIndividualFieldLabel(activeIndex: document.activeIndex))
    }
    
    var body: some View {
        HStack {
            if willShowLabel {
                LabelDisplayView(label: label,
                                 isLeftAligned: false,
                                 fontColor: STITCH_FONT_GRAY_COLOR,
                                 isSelectedInspectorRow: propertyRowIsSelected)
            }
            
            Spacer()
          
            // Vast majority of inputs, however, have a single row of fields.
            // TODO: this part of the UI is not clear; we allow the single row of fields to float up into the enclosing HStack, yet flyouts always vertically stack their fields
            LayerInputFieldsView(fieldValueTypes: fieldValueTypes,
                                 layerInputObserver: layerInputObserver,
                                 forFlyout: forFlyout,
                                 valueEntryView: valueEntryView)
        }
    }
}

struct LayerInputFieldsView<ValueEntry>: View where ValueEntry: View {
    typealias ValueEntryViewBuilder = (InputFieldViewModel, Bool) -> ValueEntry
    
    let fieldValueTypes: [FieldGroupTypeData<InputNodeRowViewModel.FieldType>]
    let layerInputObserver: LayerInputObserver
    let forFlyout: Bool
    @ViewBuilder var valueEntryView: ValueEntryViewBuilder
    
    var layerInput: LayerInputPort {
        layerInputObserver.port
    }
    
    var isMultifield: Bool {
        layerInputObserver.usesMultifields || fieldValueTypes.count > 1
    }
    
    var blockedFields: LayerPortTypeSet? {
        layerInputObserver.blockedFields
    }
    
    var body: some View {
        ForEach(fieldValueTypes) { (fieldGroupViewModel: FieldGroupTypeData<InputFieldViewModel>) in
            
            let multipleFieldsPerGroup = fieldGroupViewModel.fieldObservers.count > 1
            
            // Note: "multifield" is more complicated for layer inputs, since `fieldObservers.count` is now inaccurate for an unpacked port
            let _isMultifield = isMultifield || multipleFieldsPerGroup
            
            if !self.isAllFieldsBlockedOut(fieldGroupViewModel: fieldGroupViewModel) {
                NodeFieldsView(
                    fieldGroupViewModel: fieldGroupViewModel,
                    valueEntryView: valueEntryView) {
                    // TODO: how to handle the multifield "shadow offset" input in the Shadow Flyout? For now, we stack those fields vertically
                    if forFlyout {
//                        if isMultiField && layerInput == .shadowOffset {
                            VStack {
                                ForEach(fieldGroupViewModel.fieldObservers) { fieldViewModel in
                                    let isBlocked = self.blockedFields.map { fieldViewModel.isBlocked($0) } ?? false
                                    if !isBlocked {
                                        self.valueEntryView(fieldViewModel,
                                                            _isMultifield)
                                    }
                                }
                            }
                    }
                    
                    // patch inputs and inspector fields are horizontally aligned
                    else {
                        HStack {
                            ForEach(fieldGroupViewModel.fieldObservers) { fieldViewModel in
                                let isBlocked = self.blockedFields.map { fieldViewModel.isBlocked($0) } ?? false
                                if !isBlocked {
                                    self.valueEntryView(fieldViewModel,
                                                        _isMultifield)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func isAllFieldsBlockedOut(fieldGroupViewModel: FieldGroupTypeData<InputFieldViewModel>) -> Bool {
        if let blockedFields = blockedFields {
            return fieldGroupViewModel.fieldObservers.allSatisfy {
                $0.isBlocked(blockedFields)
            }
        }
        return false
    }
}

// Multifeld layer inputs (regardless packed vs unpacked) ALWAYS use read-only views that open flyouts when tapped
// e.g. Size, Position, 3D Transform, Padding, Margin
// Note: this is for inspector but NOT inspector's flyout
// (Using this separate view lets us simplify CommonEditingView as well)
struct InspectorLayerMultifieldInputView: View {
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let layerInputObserver: LayerInputObserver
        
    // TODO: MARCH 10: inaccurate for unpacked ? or okay, since always ... ; check on iPad!
    // Can we really assume that this is packed?
    var layerInputType: LayerInputType {
        LayerInputType.init(layerInput: layerInputObserver.port,
                            portType: .packed)
    }
    
    var layerInspectorRowId: LayerInspectorRowId {
        .layerInput(layerInputType)
    }
    
    var layerInput: LayerInputPort {
        self.layerInputObserver.port
    }
  
    var willShowLabel: Bool {
        layerInput.showsLabelForInspector
    }
    
    var is3DTransform: Bool {
        layerInput == .transform3D
    }
    
    var layerInputData: InputLayerNodeRowData {
        layerInputObserver._packedData
    }
    
    var fieldValueTypes: [FieldGroupTypeData<InputNodeRowViewModel.FieldType>] {
        self.layerInputObserver.fieldValueTypes
    }
    
    var propertyRowIsSelected: Bool {
        graph.propertySidebar.selectedProperty == layerInspectorRowId
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
          
            if layerInputObserver.port == .transform3D {
                LayerInspectorThreeFieldInputView(document: document,
                                                  graph: graph,
                                                  node: node,
                                                  layerInputObserver: layerInputObserver)
            }
            
            else if layerInputObserver.port == .padding || layerInputObserver.port == .layerMargin || layerInputObserver.port == .layerPadding {
                LayerInspectorGridInputView(document: document,
                                            graph: graph,
                                            node: node,
                                            layerInputObserver: layerInputObserver)
            } else {
                LabelDisplayView(label: layerInputObserver.overallPortLabel(usesShortLabel: true,
                                                                            node: node,
                                                                            graph: graph),
                                 isLeftAligned: false,
                                 fontColor: STITCH_FONT_GRAY_COLOR,
                                 isSelectedInspectorRow: propertyRowIsSelected)
                
                Spacer()
                
                ForEach(fieldValueTypes) { fieldGrouping in
                    
                    // Nested ForEach works well for abstracting over packed vs unpacked for simple two-field inputs
                    ForEach(fieldGrouping.fieldObservers) { fieldObserver in
                                                
                        LabelDisplayView(label: fieldObserver.fieldLabel,
                                         isLeftAligned: true,
                                         fontColor: STITCH_FONT_GRAY_COLOR,
                                         // TODO: MARCH 10: for font color when selected on iPad
                                         isSelectedInspectorRow: propertyRowIsSelected)
                        
                        CommonEditingViewReadOnly(
                            inputField: fieldObserver,
                            inputString: fieldObserver.fieldValue.stringValue,
                            forPropertySidebar: true,
                            isHovering: false, // Can never hover on a inspector's multifield
                            choices: nil, // always nil for layer dropdown ?
                            
                            // field width is the most variable for read only views in inspector?
                            fieldWidth: self.fieldWidth,
                            
                            // TODO: MARCH 10: easier way to tell if part of heterogenous layer multiselect
                            fieldHasHeterogenousValues: false,
                            
                            // TODO: MARCH 10: for font color when selected on iPad
                            isSelectedInspectorRow: propertyRowIsSelected,
                            
                            isFieldInMultfieldInspectorInput: true) {
                                
                                // If entire packed input is already on canvas, don't do anything; rather, let the LayerInspectorPortView's onTap take over
                                if layerInputObserver.mode == .packed,
                                   let canvasNodeForPackedInput = layerInputObserver.getCanvasItemForWholeInput() {
                                    log("InspectorLayerMultifieldInputView: will jump to canvas for \(layerInput)")
                                    graph.jumpToCanvasItem(id: canvasNodeForPackedInput.id,
                                                           document: document)
                                } else {
                                    log("InspectorLayerMultifieldInputView: will open flyout for \(layerInput)")
                                    dispatch(FlyoutToggled(
                                        flyoutInput: layerInput,
                                        flyoutNodeId: self.node.id,
                                        fieldToFocus: .textInput(fieldObserver.id)))
                                }
                            }
                    }
                }
            } // else
        }
    }
    
    
    @MainActor
    var fieldWidth: CGFloat {
        // TODO: get this from activeValue.getPadding.isDefined ?
        if layerInputObserver.port == .padding || layerInputObserver.port == .layerPadding || layerInputObserver.port == .layerMargin {
            return PADDING_FIELD_WDITH
        } else {
            // is this accurate for a spacing-field in the inspector?
            // ah but spacing is a dropdown
            return INSPECTOR_MULTIFIELD_INDIVIDUAL_FIELD_WIDTH
        }
    }
}


struct LayerInspectorGridInputView: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let layerInputObserver: LayerInputObserver
    
    
    var allFieldObservers: [InputNodeRowViewModel.FieldType] {
        layerInputObserver.fieldValueTypes.flatMap(\.fieldObservers)
    }
    
    var overallLabel: String {
        layerInputObserver.overallPortLabel(usesShortLabel: true, node: node, graph: graph)
    }
    
    var body: some View {
                        
        // Align "padding" label with
        HStack(alignment: .firstTextBaseline) {
            
            // Label
            LabelDisplayView(label: overallLabel,
                             isLeftAligned: false,
                             fontColor: STITCH_FONT_GRAY_COLOR,
                             isSelectedInspectorRow: false)
            
            Spacer()
            
            if let p0 = allFieldObservers[safe: 0],
               let p1 = allFieldObservers[safe: 1],
               let p2 = allFieldObservers[safe: 2],
               let p3 = allFieldObservers[safe: 3] {
                
                // Pseudo grid
                VStack {
                    HStack {
                        self.observerView(p0)
                        self.observerView(p1)
                    }
                    HStack {
                        self.observerView(p2)
                        self.observerView(p3)
                    }
                }
            } else {
                EmptyView().onAppear { fatalErrorIfDebug() }
            }
        }
        // TODO: `LayerInspectorPortView`'s `.listRowInsets` should maintain consistent padding between input-rows in the layer inspector, so why is additional padding needed?
        .padding(.vertical, INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET * 2)
    }
    
    func observerView(_ fieldObserver: InputNodeRowViewModel.FieldType) -> some View {
        
        CommonEditingViewReadOnly(
            inputField: fieldObserver,
            inputString: fieldObserver.fieldValue.stringValue,
            forPropertySidebar: true,
            isHovering: false, // Can never hover on a inspector's multifield
            choices: nil, // always nil for layer dropdown ?
            fieldWidth: INSPECTOR_MULTIFIELD_INDIVIDUAL_FIELD_WIDTH,
            
            // TODO: MARCH 10: easier way to tell if part of heterogenous layer multiselect
            fieldHasHeterogenousValues: false,
            
            // TODO: MARCH 10: for font color when selected on iPad
            isSelectedInspectorRow: false,
            
            isFieldInMultfieldInspectorInput: true) {
                // If entire packed input is already on canvas, we should jump to that input on that canvas rather than open the flyout
                if layerInputObserver.mode == .packed,
                   let canvasNodeForPackedInput = layerInputObserver.getCanvasItemForWholeInput() {
                    log("LayerInspectorGridView: will jump to canvas for \(layerInputObserver.port)")
                    graph.jumpToCanvasItem(id: canvasNodeForPackedInput.id,
                                           document: document)
                } else {
                    log("LayerInspectorGridView: will open flyout for \(layerInputObserver.port)")
                    dispatch(FlyoutToggled(
                        flyoutInput: layerInputObserver.port,
                        flyoutNodeId: self.node.id,
                        fieldToFocus: .textInput(fieldObserver.id)))
                }
            }
    }
}

// 3D Transform, 3D Size etc.
struct LayerInspectorThreeFieldInputView: View {
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let layerInputObserver: LayerInputObserver
    
    var body: some View {
        VStack {
            ForEach(layerInputObserver.fieldValueTypes) { fieldGrouping in
                VStack {
                    if let fieldGroupLabel = fieldGrouping.groupLabel {
                        HStack {
                            LabelDisplayView(label: fieldGroupLabel,
                                             isLeftAligned: false,
                                             fontColor: STITCH_FONT_GRAY_COLOR,
                                             isSelectedInspectorRow: false)
                            Spacer()
                        }
                    }
                    
                    HStack {
                        self.observerViews(fieldGrouping.fieldObservers)
                    }
                }
            } // ForEach
        }
    }
    
    func observerViews(_ fieldObservers: [InputNodeRowViewModel.FieldType]) -> some View {
        
        ForEach(fieldObservers) { fieldObserver  in
            HStack {
                
                // NEED AN ABSTRACTION VIEW FOR THIS LABEL + READ-ONLY VIEW
                LabelDisplayView(label: fieldObserver.fieldLabel,
                                 isLeftAligned: true,
                                 fontColor: STITCH_FONT_GRAY_COLOR,
                                 // TODO: MARCH 10: for font color when selected on iPad
                                 isSelectedInspectorRow: false)
                .border(.yellow)
                
                CommonEditingViewReadOnly(
                    inputField: fieldObserver,
                    inputString: fieldObserver.fieldValue.stringValue,
                    forPropertySidebar: true,
                    isHovering: false, // Can never hover on a inspector's multifield
                    choices: nil, // always nil for layer dropdown ?
                    fieldWidth: INSPECTOR_MULTIFIELD_INDIVIDUAL_FIELD_WIDTH,
                    
                    // TODO: MARCH 10: easier way to tell if part of heterogenous layer multiselect
                    fieldHasHeterogenousValues: false,
                    
                    // TODO: MARCH 10: for font color when selected on iPad
                    isSelectedInspectorRow: false,
                    
                    isFieldInMultfieldInspectorInput: true) {
                        // If entire packed input is already on canvas, we should jump to that input on that canvas rather than open the flyout
                        if layerInputObserver.mode == .packed,
                           let canvasNodeForPackedInput = layerInputObserver.getCanvasItemForWholeInput() {
                            log("LayerInspectorThreeFieldView: will jump to canvas for \(layerInputObserver.port)")
                            graph.jumpToCanvasItem(id: canvasNodeForPackedInput.id,
                                                   document: document)
                        } else {
                            log("LayerInspectorThreeFieldView: will open flyout for \(layerInputObserver.port)")
                            
                            dispatch(FlyoutToggled(
                                flyoutInput: layerInputObserver.port,
                                flyoutNodeId: self.node.id,
                                fieldToFocus: .textInput(fieldObserver.id)))
                        }
                    }
            }
        } // ForEach
    }
}

struct LayerInspectorOutputPortView: View {
    let outputPortId: Int
    
    @Bindable var node: NodeViewModel
    @Bindable var rowViewModel: OutputNodeRowViewModel
    @Bindable var rowObserver: OutputNodeRowObserver
    @Bindable var graph: GraphState
    @Bindable var graphUI: StitchDocumentViewModel
    
    let canvasItem: CanvasItemViewModel?
    let forFlyout: Bool

    var isCanvasItemSelected: Bool {
        self.canvasItem?.isSelected(graph) ?? false
    }
    
    var propertyIsAlreadyOnGraph: Bool {
        self.canvasItem != nil
    }
    
    var propertyRowIsSelected: Bool {
        graph.propertySidebar.selectedProperty == .layerOutput(outputPortId)
    }

    var label: String {
        rowObserver
            .label(useShortLabel: true,
                   node: node,
                   coordinate: .output(rowObserver.id),
                   graph: graph)
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
                         forPropertySidebar: true,
                         propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                         isFieldInMultifieldInput: isMultiField,
                         isSelectedInspectorRow: propertyRowIsSelected)
    }
    
    var body: some View {
        
        let portId = rowViewModel.id.portId
        
        let coordinate: NodeIOCoordinate = .init(
            portType: .portIndex(portId),
            nodeId: rowViewModel.id.nodeId)

        // Does this inspector-row (entire output) have a canvas item?
        // Note: CANNOT rely on delegate since weak var references do not trigger view updates
//        let canvasItemId: CanvasItemId? = rowViewModel.canvasItemDelegate?.id
//        let canvasItemId: CanvasItemId? = graph.getCanvasItem(outputId: coordinate)?.id
        
        LayerInspectorPortView(layerInputObserver: nil,
                               layerInspectorRowId: .layerOutput(rowViewModel.id.portId),
                               coordinate: coordinate,
                               graph: graph,
                               graphUI: graphUI,
                               canvasItemId: canvasItem?.id) { propertyRowIsSelected in
            HStack(alignment: .firstTextBaseline) {
                // Property sidebar always shows labels on left side, never right
                LabelDisplayView(label: label,
                                 isLeftAligned: false,
                                 fontColor: STITCH_FONT_GRAY_COLOR,
                                 isSelectedInspectorRow: propertyRowIsSelected)
                Spacer()
                
                LayerOutputFieldsView(fieldValueTypes: rowViewModel.fieldValueTypes,
                                      valueEntryView: valueEntryView)
            } // HStack
        }
    }
}

/*
 Note: currently:
 - (1) every layer output has a single field,
 - (2) a layer output's fields can never be blocked, and
 - (3) a layer output never uses the flyout
 */
struct LayerOutputFieldsView<ValueEntry>: View where ValueEntry: View {
    typealias ValueEntryViewBuilder = (OutputFieldViewModel, Bool) -> ValueEntry
    
    let fieldValueTypes: [FieldGroupTypeData<OutputNodeRowViewModel.FieldType>]
    @ViewBuilder var valueEntryView: ValueEntryViewBuilder

    var body: some View {
        ForEach(fieldValueTypes) { (fieldGroupViewModel: FieldGroupTypeData<OutputFieldViewModel>) in
            let isMultifield = fieldGroupViewModel.fieldObservers.count > 1
            NodeFieldsView(fieldGroupViewModel: fieldGroupViewModel,
                           valueEntryView: self.valueEntryView) {
                HStack {
                    ForEach(fieldGroupViewModel.fieldObservers) { fieldViewModel in
                        self.valueEntryView(fieldViewModel,
                                            isMultifield)
                    }
                }
            }
        }
    }
}


// spacing between e.g. "add to graph" button (icon) and start of row capsule
let LAYER_INSPECTOR_ROW_SPACING = 8.0

// how big an icon / button is
let LAYER_INSPECTOR_ROW_ICON_LENGTH = 16.0

//struct LayerInspectorPortView<RowObserver, RowView>: View where RowObserver: NodeRowObserver, RowView: View {
struct LayerInspectorPortView<RowView>: View where RowView: View {
    
    // This ought to be non-optional?
    let layerInputObserver: LayerInputObserver?
    
    // input or output
    let layerInspectorRowId: LayerInspectorRowId
    
    let coordinate: NodeIOCoordinate
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    
    // non-nil = this row is present on canvas
    // NOTE: apparently, the destruction of a weak var reference does NOT trigger a SwiftUI view update; so, avoid using delegates in the UI body.
    let canvasItemId: CanvasItemId?
    
    // Arguments: 1. is row selected
    @ViewBuilder var rowView: (Bool) -> RowView
    
    @State private var isHovered: Bool = false
    
    // Is this property-row selected?
    @MainActor
    var propertyRowIsSelected: Bool {
        graph.propertySidebar.selectedProperty == layerInspectorRowId
    }
    
    var isOnGraphAlready: Bool {
        canvasItemId.isDefined
    }
    
    var isPaddingPortValueTypeRow: Bool {
        layerInputObserver?.port == .layerMargin || layerInputObserver?.port == .layerPadding
    }
    
    var isShadowProxyRow: Bool {
        layerInputObserver?.port == SHADOW_FLYOUT_LAYER_INPUT_PROXY
    }
    
    var hstackAlignment: VerticalAlignment {
        return isPaddingPortValueTypeRow ? .firstTextBaseline : .center
    }
    
    var body: some View {
        HStack(alignment: hstackAlignment) {
            
            LayerInspectorRowButton(graph: graph,
                                    graphUI: graphUI,
                                    layerInputObserver: layerInputObserver,
                                    layerInspectorRowId: layerInspectorRowId,
                                    coordinate: coordinate,
                                    canvasItemId: canvasItemId,
                                    isHovered: isHovered)
            // TODO: `.firstTextBaseline` doesn't align symbols and text in quite the way we want;
            // Really, we want the center of the symbol and the center of the input's label text to align
            // Alternatively, we want the height of the row-buton to be the same as the height of the input-row's label, e.g. specify a height in `LabelDisplayView`
            .offset(y: isPaddingPortValueTypeRow ? INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET : 0)
            
            // Do not show this button if this is the row for the shadow proxy
            .opacity(isShadowProxyRow ? 0 : 1)
                        
            rowView(propertyRowIsSelected)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(
            top: INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET,
            leading: 0,
            bottom: INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET,
            trailing: 0))
        .onHover(perform: { isHovering in
            self.isHovered = isHovering
        })
        .contentShape(Rectangle())
        .modifier(LayerInspectorPortViewTapModifier(graph: graph,
                                                    graphUI: graphUI,
                                                    isAutoLayoutRow: layerInputObserver?.port == .orientation,
                                                    layerInspectorRowId: layerInspectorRowId,
                                                    canvasItemId: canvasItemId))
    }
}

// HACK: Catalyst's Segmented Picker is unresponsive when we attach a tap gesture, even a `.simultaneousGesture(TapGesture)`
struct LayerInspectorPortViewTapModifier: ViewModifier {
    
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    let isAutoLayoutRow: Bool
    let layerInspectorRowId: LayerInspectorRowId
    let canvasItemId: CanvasItemId?
        
    var isCatalyst: Bool {
#if targetEnvironment(macCatalyst)
        return true
#else
        return false
#endif
    }
    
    func body(content: Content) -> some View {
        // HACK: If this is the LayerGroup's autolayout row (on Catalyst) and the row is not already on the canvas,
        // then do not add a 'jump to canvas item' handler that interferes with Segmented Picker.
        if isAutoLayoutRow, isCatalyst, canvasItemId == nil {
            content
        } else {
            content.gesture(TapGesture().onEnded({ _ in
                log("LayerInspectorPortView tapped")
                graphUI.onLayerPortRowTapped(
                    layerInspectorRowId: layerInspectorRowId,
                    canvasItemId: canvasItemId,
                    graph: graph)
            }))
        }
    }
}

extension StitchDocumentViewModel {
    @MainActor
    func onLayerPortRowTapped(layerInspectorRowId: LayerInspectorRowId,
                              canvasItemId: CanvasItemId?,
                              graph: GraphState) {
        // Defined canvas item id = we're already on the canvas
        if let canvasItemId = canvasItemId {
            graph.jumpToCanvasItem(id: canvasItemId,
                                   document: self)
        }
        
        // Else select/de-select the property
        else {

            // On Catalyst, use hover-only, never row-selection.
            #if !targetEnvironment(macCatalyst)
            let alreadySelected = graph.propertySidebar.selectedProperty == layerInspectorRowId
            
            withAnimation {
                if alreadySelected {
                    graph.propertySidebar.selectedProperty = nil
                } else {
                    graph.propertySidebar.selectedProperty = layerInspectorRowId
                }
            }
            #endif
        }
    }
}

