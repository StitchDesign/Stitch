//
//  LayerInspectorPortView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/24.
//

import SwiftUI
import StitchSchemaKit
import OrderedCollections

struct LayerInspectorInputPortView: View {
    @Bindable var layerInputObserver: LayerInputObserver
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    let node: NodeViewModel
            
    var isShadowLayerInputRow: Bool {
        self.layerInputObserver.port == SHADOW_FLYOUT_LAYER_INPUT_PROXY
    }
    
    var body: some View {
        let observerMode = layerInputObserver.observerMode
        
        // TODO: is this really correct, to always treat the layer's input as packed ?
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
        //
        let canvasItemId: CanvasItemId? = observerMode.isPacked ? layerInputObserver._packedData.canvasObserver?.id : nil
        
        LayerInspectorPortView(layerInputObserver: layerInputObserver,
                               layerInspectorRowId: layerInspectorRowId,
                               coordinate: coordinate,
                               graph: graph,
                               document: document,
                               canvasItemId: canvasItemId) { isPropertyRowSelected in
                    HStack {
                        if isShadowLayerInputRow {
                            ShadowInputInspectorRow(nodeId: node.id,
                                                    isPropertyRowSelected: isPropertyRowSelected)
                        }
                        
                        // Note: 3D Transform and PortValue.padding are arranged in a "grid" in the inspector ONLY.
                        // So we handle them here, rather than in `fields` views used in flyouts and on canvas.
                        else if layerInputObserver.port == .transform3D {
                            LayerInspector3DTransformInputView(document: document,
                                                               graph: graph,
                                                               nodeId: node.id,
                                                               layerInputObserver: layerInputObserver,
                                                               isPropertyRowSelected: isPropertyRowSelected)
                        } else if layerInputObserver.usesGridMultifieldArrangement() {
                            // Multifields in the inspector are always "read-only" and "tap to open flyout"
                            LayerInspectorGridInputView(document: document,
                                                        graph: graph,
                                                        node: node,
                                                        layerInputObserver: layerInputObserver,
                                                        isPropertyRowSelected: isPropertyRowSelected)
                        } else {
                            // Handles both single- and multifield-inputs (arranges an input's multiple-fields in an HStack)
                            InspectorLayerInputView(
                                document: document,
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


/*
 fka `LayerNodeInputView`
 
 Used by
 - (1) inspector's ShadowFlyoutRow,
 - (2) inspector single-field inputs,
 - (3) inspector multi-field inputs that can be arranged in a simple HStack
 */
struct InspectorLayerInputView: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let layerInputObserver: LayerInputObserver
    let forFlyout: Bool
    
    var label: String {
        layerInputObserver.overallPortLabel(usesShortLabel: true)
    }
        
    var layerInput: LayerInputPort {
        self.layerInputObserver.port
    }
    
    var isShadowLayerInputRow: Bool {
        self.layerInput == SHADOW_FLYOUT_LAYER_INPUT_PROXY
    }
    
    var willShowLabel: Bool {
        if forFlyout {
            return true
        }
        return layerInput.showsLabelForInspector
    }
    
    var fieldValueTypes: [FieldGroup] {
        self.layerInputObserver.fieldValueTypes
    }
    
    // iPad-only?
    var packedPropertyRowIsSelected: Bool {
        graph.propertySidebar.selectedProperty == .layerInput(LayerInputType.init(layerInput: layerInputObserver.port,
                                                                                  portType: .packed))
    }
    
    var body: some View {
        // Note: ShadowFlyout's .shadowOffset row uses a VStack for it's x vs y fields
        // TODO: let .shadowOffset fields appear side-by-side?
        HStack(alignment: layerInput == .shadowOffset ? .firstTextBaseline : .center) {
            if willShowLabel {
                LabelDisplayView(label: label,
                                 isLeftAligned: false,
                                 fontColor: STITCH_FONT_GRAY_COLOR,
                                 isSelectedInspectorRow: packedPropertyRowIsSelected)
            }
            Spacer()
            LayerInputFieldsView(layerInputFieldType: forFlyout ? .flyout : .inspector,
                                 document: document,
                                 graph: graph,
                                 node: node,
                                 // TODO: we always want to show all input fields in the inspector, but cannot assume data is in a packed state
                                 rowObserver: layerInputObserver.packedRowObserver,
                                 rowViewModel: layerInputObserver._packedData.inspectorRowViewModel,
                                 fieldValueTypes: fieldValueTypes,
                                 layerInputObserver: layerInputObserver,
                                 isNodeSelected: false)
        }
    }
}

enum LayerInputFieldType {
    case inspector
    case canvas(CanvasItemViewModel)
    case flyout
}

// fka `LayerInputFieldsView`
// Used by InspectorLayerInputView, most flyouts and CanvasLayerInputView
struct LayerInputFieldsView: View {
    let layerInputFieldType: LayerInputFieldType
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var rowObserver: InputNodeRowObserver
    @Bindable var rowViewModel: InputNodeRowViewModel
    let fieldValueTypes: [FieldGroup]
    let layerInputObserver: LayerInputObserver
    let isNodeSelected: Bool
        
    var isMultifield: Bool {
        layerInputObserver.usesMultifields || fieldValueTypes.count > 1
    }
    
    var blockedFields: LayerPortTypeSet? {
        layerInputObserver.blockedFields
    }
    
    var forFlyout: Bool {
        switch self.layerInputFieldType {
        case .flyout:
            return true
            
        default:
            return false
        }
    }
    
    @ViewBuilder
    func valueEntryView(_ portViewModel: InputFieldViewModel,
                        _ isMultifield: Bool) -> some View {
        
        switch layerInputFieldType {
        
        case .inspector:
            let layerInputType = LayerInputType(layerInput: layerInputObserver.port,
                                                portType: .packed)
            let layerInspectorRowId: LayerInspectorRowId = .layerInput(layerInputType)
            let layerInputData: InputLayerNodeRowData = layerInputObserver._packedData
            let propertyRowIsSelected = graph.propertySidebar.selectedProperty == layerInspectorRowId
            
            // InspectorLayerInputView
            InputValueEntry(graph: graph,
                            document: document,
                            viewModel: portViewModel,
                            node: node,
                            rowViewModel: layerInputData.inspectorRowViewModel,
                            canvasItem: nil,
                            rowObserver: layerInputObserver.packedRowObserver,
                            isCanvasItemSelected: false,
                            hasIncomingEdge: false,
                            isForLayerInspector: true,
                            isPackedLayerInputAlreadyOnCanvas: layerInputObserver.getCanvasItemForWholeInput().isDefined,
                            isFieldInMultifieldInput: layerInputObserver.usesMultifields,
                            isForFlyout: false,
                            isSelectedInspectorRow: propertyRowIsSelected,
                            useIndividualFieldLabel: layerInputObserver.useIndividualFieldLabel(activeIndex: document.activeIndex))
            
        case .canvas(let canvasNode):
            // CanvasLayerInputView
            InputValueEntry(graph: graph,
                            document: document,
                            viewModel: portViewModel,
                            node: node,
                            rowViewModel: rowViewModel,
                            canvasItem: canvasNode,
                            rowObserver: rowObserver,
                            isCanvasItemSelected: isNodeSelected,
                            hasIncomingEdge: rowObserver.upstreamOutputCoordinate.isDefined,
                            isForLayerInspector: false,
                            isPackedLayerInputAlreadyOnCanvas: true, // Always true for canvas layer input
                            isFieldInMultifieldInput: isMultifield,
                            isForFlyout: false,
                            isSelectedInspectorRow: false, // Always false for canvas layer input
                            useIndividualFieldLabel: true)
            
        case .flyout:
            // GenericFlyoutView
            GenericFlyoutRowView(
                graph: graph,
                document: document,
                viewModel: portViewModel,
                rowViewModel: rowViewModel,
                node: node,
                layerInputObserver: layerInputObserver,
                isMultifield: isMultifield)
        }
    }
    
    var body: some View {
        ForEach(fieldValueTypes) { (fieldGroupViewModel: FieldGroup) in
            
            let multipleFieldsPerGroup = fieldGroupViewModel.fieldObservers.count > 1
            
            // Note: "multifield" is more complicated for layer inputs, since `fieldObservers.count` is now inaccurate for an unpacked port
            let _isMultifield = isMultifield || multipleFieldsPerGroup
            
            if !self.isAllFieldsBlockedOut(fieldGroupViewModel: fieldGroupViewModel) {
                // Only non-nil for 3D transform
                // NOTE: this only shows up for PACKED 3D Transform; unpacked 3D Transform fields are treat as Number fields, which are not created with a `groupLabel`
                // Alternatively we could create Number fieldGroups with their proper parent label if they are for an unpacked multifeld layer input?
                if let fieldGroupLabel = fieldGroupViewModel.groupLabel {
                    HStack {
                        LabelDisplayView(label: fieldGroupLabel,
                                         isLeftAligned: false,
                                         fontColor: STITCH_FONT_GRAY_COLOR,
                                         isSelectedInspectorRow: false)
                        Spacer()
                    }
                }
                
                // TODO: how to handle the multifield "shadow offset" input in the Shadow Flyout? For now, we stack those fields vertically
                if forFlyout {
                    VStack {
                        fieldsView(fieldGroupViewModel: fieldGroupViewModel,
                                   isMultifield: _isMultifield)
                    }
                } else {
                    HStack {
                        fieldsView(fieldGroupViewModel: fieldGroupViewModel,
                                   isMultifield: _isMultifield)
                    }
                }
            } // if ...
        } // ForEach(fieldValueTypes) { ...
    }
    
    @ViewBuilder
    func fieldsView(fieldGroupViewModel: FieldGroup,
                    isMultifield: Bool) -> some View {
        ForEach(fieldGroupViewModel.fieldObservers) { fieldViewModel in
            let isBlocked = self.blockedFields.map { fieldViewModel.isBlocked($0) } ?? false
            if !isBlocked {
                self.valueEntryView(fieldViewModel,
                                    isMultifield)
            }
        }
    }
    
    func isAllFieldsBlockedOut(fieldGroupViewModel: FieldGroup) -> Bool {
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
    @Bindable var document: StitchDocumentViewModel
    
    let canvasItem: CanvasItemViewModel?
    let forFlyout: Bool

    var isCanvasItemSelected: Bool {
        self.canvasItem.map { graph.isCanvasItemSelected($0.id) } ?? false
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
                         document: document,
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
        
        LayerInspectorPortView(layerInputObserver: nil,
                               layerInspectorRowId: .layerOutput(portId),
                               coordinate: coordinate,
                               graph: graph,
                               document: document,
                               canvasItemId: canvasItem?.id) { propertyRowIsSelected in
            HStack(alignment: .firstTextBaseline) {
                // Property sidebar always shows labels on left side, never right
                LabelDisplayView(label: label,
                                 isLeftAligned: false,
                                 fontColor: STITCH_FONT_GRAY_COLOR,
                                 isSelectedInspectorRow: propertyRowIsSelected)
                Spacer()
                
                LayerOutputFieldsView(fieldValueTypes: rowViewModel.cachedFieldValueGroups,
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
    
    let fieldValueTypes: [FieldGroup]
    @ViewBuilder var valueEntryView: ValueEntryViewBuilder

    var body: some View {
        ForEach(fieldValueTypes) { (fieldGroupViewModel: FieldGroup) in
            let isMultifield = fieldGroupViewModel.fieldObservers.count > 1
            
            if let fieldGroupLabel = fieldGroupViewModel.groupLabel {
                HStack {
                    LabelDisplayView(label: fieldGroupLabel,
                                     isLeftAligned: false,
                                     fontColor: STITCH_FONT_GRAY_COLOR,
                                     isSelectedInspectorRow: false)
                    Spacer()
                }
            }
            
            HStack {
                ForEach(fieldGroupViewModel.fieldObservers) { fieldViewModel in
                    self.valueEntryView(fieldViewModel,
                                        isMultifield)
                }
            }
        }
    }
}


// spacing between e.g. "add to graph" button (icon) and start of row capsule
let LAYER_INSPECTOR_ROW_SPACING = 8.0

// how big an icon / button is
let LAYER_INSPECTOR_ROW_ICON_LENGTH = 16.0


struct LayerInspectorPortView<RowView>: View where RowView: View {
    
    // This ought to be non-optional?
    let layerInputObserver: LayerInputObserver?
    
    // input or output
    let layerInspectorRowId: LayerInspectorRowId
    
    let coordinate: NodeIOCoordinate
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    
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
                                    document: document,
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
                                                    document: document,
                                                    isAutoLayoutRow: layerInputObserver?.port == .orientation,
                                                    layerInspectorRowId: layerInspectorRowId,
                                                    canvasItemId: canvasItemId))
    }
}

// HACK: Catalyst's Segmented Picker is unresponsive when we attach a tap gesture, even a `.simultaneousGesture(TapGesture)`
struct LayerInspectorPortViewTapModifier: ViewModifier {
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
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
                document.onLayerPortRowTapped(
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
            dispatch(JumpToCanvasItem(id: canvasItemId))
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

extension GraphState {
    /*
     We are currently at Level 1 i.e. breadcrumbs like [Root, Level 1]
     and we want to jump to Level 5.
     So we start at Level 5 and iteratively building a breadcrumb list, until we reach our current level, e.g.
     [Level 4],
     [Level 3, Level 4],
     [Level 2, Level 3, Level 4],
     
     ... Which is then added to the existing [Root, Level 1] breadcrumb list.
     
     Note: new breadcrumbs replace old breadcrumbs if we actually just to a higher (less nested) level.
     */
    @MainActor
    func getBreadcrumbs(startingPoint: GroupNodeType?, // excluded; our current traversal level
                        // inclusive; non-nil so i.e. never root level
                        destination: CanvasItemId) -> OrderedSet<GroupNodeType> {

        getParent(destination,
                  maxCeiling: startingPoint,
                  acc: .init())
    }
    
    // TODO: make this work with components as well? Cannot assume `GroupNodeType.groupNode(NodeId)` etc.
    @MainActor
    func getParent(_ forCanvasItem: CanvasItemId,
                   maxCeiling: GroupNodeType?, // go no higher than this level
                   acc: OrderedSet<GroupNodeType>) -> OrderedSet<GroupNodeType> {
        
        // log("getParent: called forCanvasItem \(forCanvasItem), maxCeiling: \(maxCeiling), acc: \(acc)")
        
        guard let canvasItem = self.getCanvasItem(forCanvasItem) else {
            fatalErrorIfDebug()
            return acc
        }
        
        guard let parentId = canvasItem.parentGroupNodeId else {
            // hit root level, so just return acc
            // log("getParent: hit root level, so just return acc for forCanvasItem \(forCanvasItem), acc: \(acc)")
            return acc
        }
        
        // If we hit the ceiling, return what we already have
        if maxCeiling == .groupNode(parentId) {
            // log("getParent: hit the ceiling: maxCeiling: \(maxCeiling), canvasItem.parentGroupNodeId: \(canvasItem.parentGroupNodeId), acc: \(acc)")
            // should we actually add
            return acc
        }
        
        // Else: add parent to front and recur
        var newAcc = OrderedSet<GroupNodeType>.init([.groupNode(parentId)])
        newAcc.append(contentsOf: acc)
        let newResult = getParent(.node(parentId),
                                  maxCeiling: maxCeiling,
                                  acc: newAcc)
        // log("getParent: newResult: \(newResult)")
        
        return newResult
    }
}
