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
    
    var fieldValueTypes: [FieldGroupTypeData<InputNodeRowViewModel.FieldType>] {
        layerInputObserver.fieldValueTypes
    }
    
    var layerInput: LayerInputPort {
        self.layerInputObserver.port
    }
    
    var isShadowLayerInputRow: Bool {
        self.layerInputObserver.port == SHADOW_FLYOUT_LAYER_INPUT_PROXY
    }
    
    var willShowLabel: Bool {
        return layerInput.showsLabelForInspector
    }
    
    var layerInputData: InputLayerNodeRowData {
        layerInputObserver._packedData
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
        
        LayerInspectorPortView(
            layerInputObserver: layerInputObserver,
            layerInspectorRowId: layerInspectorRowId,
            coordinate: coordinate,
            graph: graph,
            graphUI: graphUI,
            canvasItemId: canvasItemId) { propertyRowIsSelected in
                    HStack {
                        if isShadowLayerInputRow {
                            ShadowInputInspectorRow(nodeId: node.id,
                                                    propertyIsSelected: propertyRowIsSelected)
                        } else {
                            LayerNodeInputView(document: graphUI,
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

struct LayerNodeInputView: View {
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
    
    var is3DTransform: Bool {
        layerInput == .transform3D
    }
    
    var layerInputData: InputLayerNodeRowData {
        layerInputObserver._packedData
    }
    
    var fieldValueTypes: [FieldGroupTypeData<InputNodeRowViewModel.FieldType>] {
        layerInputData.inspectorRowViewModel.fieldValueTypes
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
                        propertyIsAlreadyOnGraph: layerInputObserver.getCanvasItemForWholeInput().isDefined,
                        isFieldInMultifieldInput: isMultiField,
                        isForFlyout: forFlyout,
                        isSelectedInspectorRow: propertyRowIsSelected,
                        fieldsRowLabel: layerInputObserver.fieldsRowLabel,
                        useIndividualFieldLabel: layerInputObserver.useIndividualFieldLabel(activeIndex: document.activeIndex))
    }
    
    var body: some View {
        HStack(alignment: hStackAlignment) {
            if willShowLabel {
                LabelDisplayView(label: label,
                                 isLeftAligned: false,
                                 fontColor: STITCH_FONT_GRAY_COLOR,
                                 isSelectedInspectorRow: propertyRowIsSelected)
            }
            
            Spacer()
            
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
            else if layerInput == .layerMargin || layerInput == .padding,
                    layerInputObserver.mode == .unpacked,
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
    }
    
    // Needed for alignment of e.g. Packed vs Unpacked layer inputs for Margin, Padding
    var hStackAlignment: VerticalAlignment {
        
        // Several ways an input can be "multifield":
        // 1. patch node input or packed layer node input: one fieldValue type with multiple field observers
        // 2. unpacked layer node input: multuple field value types with one field observer each
        // 3. patch node input for shape commands (IGNORED FOR NOW?)
        let isMultifield = self.layerInputObserver.usesMultifields
        
        return isMultifield ? .firstTextBaseline : .center
    }
    
    func fieldsListView(_ fieldValueTypes: [FieldGroupTypeData<InputNodeRowViewModel.FieldType>]) -> some View {
        LayerInputFieldsView(fieldValueTypes: fieldValueTypes,
                             layerInputObserver: layerInputObserver,
                             forFlyout: forFlyout,
                             valueEntryView: valueEntryView)
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
    
    var displaysNarrowMultifields: Bool {
        switch layerInput {
        case .transform3D:
            return true
        case .layerPadding, .layerMargin:
            return layerInputObserver.mode == .packed
        default:
            return false
        }
    }

    var body: some View {
        ForEach(fieldValueTypes) { (fieldGroupViewModel: FieldGroupTypeData<InputFieldViewModel>) in
            
            let multipleFieldsPerGroup = fieldGroupViewModel.fieldObservers.count > 1
            //
            //            // Note: "multifield" is more complicated for layer inputs, since `fieldObservers.count` is now inaccurate for an unpacked port
            let _isMultifield = isMultifield || multipleFieldsPerGroup
            
            // TODO: shadow field
            let isShadowMultiFieldFlyout = forFlyout && _isMultifield && layerInput == .shadowOffset
                        
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
                    
                    else if displaysNarrowMultifields {
                        HStack {
                            Spacer()
                            NodePortContrainedFieldsView(fieldGroupViewModel: fieldGroupViewModel,
                                                         isMultiField: _isMultifield,
                                                         valueEntryView: valueEntryView)
                        }
                        // TODO: `LayerInspectorPortView`'s `.listRowInsets` should maintain consistent padding between input-rows in the layer inspector, so why is additional padding needed?
                        .padding(.vertical, INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET * 2)
                    }
                    
                    // flyout fields generally are vertically stacked (`shadowOffset` is exception)
//                    else if forFlyout {
//                        VStack {
//                            fields
//                        }
//                    }
                    
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
        
        LayerInspectorPortView(
            layerInputObserver: nil,
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
                                          forFlyout: forFlyout,
                                          valueEntryView: valueEntryView)
                } // HStack
            }
    }
}

struct LayerOutputFieldsView<ValueEntry>: View where ValueEntry: View {
    typealias ValueEntryViewBuilder = (OutputFieldViewModel, Bool) -> ValueEntry
    
    let fieldValueTypes: [FieldGroupTypeData<OutputNodeRowViewModel.FieldType>]
    let forFlyout: Bool
    @ViewBuilder var valueEntryView: ValueEntryViewBuilder

    var body: some View {
        ForEach(fieldValueTypes) { (fieldGroupViewModel: FieldGroupTypeData<OutputFieldViewModel>) in
            
            let isMultifield = fieldGroupViewModel.fieldObservers.count > 1
            
            NodeFieldsView(
                fieldGroupViewModel: fieldGroupViewModel,
                valueEntryView: valueEntryView) {
                    // TODO: how to handle the multifield "shadow offset" input in the Shadow Flyout? For now, we stack those fields vertically
                    if forFlyout {
                        //                        if isMultiField && layerInput == .shadowOffset {
                        VStack {
                            ForEach(fieldGroupViewModel.fieldObservers) { fieldViewModel in
                                self.valueEntryView(fieldViewModel,
                                                    isMultifield)
                            }
                        }
                    }

                    // patch inputs and inspector fields are horizontally aligned
                    else {
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

