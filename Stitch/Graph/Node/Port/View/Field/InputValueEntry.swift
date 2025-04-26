//
//  ValueEntry.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/14/22.
//

import SwiftUI
import StitchSchemaKit

// For an individual field
struct InputValueEntry: View {

    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    
    @Bindable var viewModel: InputFieldViewModel
    let node: NodeViewModel
    let rowViewModel: InputNodeRowViewModel
    let canvasItem: CanvasItemViewModel?
    
    let rowObserver: InputNodeRowObserver
    let isCanvasItemSelected: Bool
    let hasIncomingEdge: Bool
    
    // TODO: package these up into `InspectorData` ?
    let isForLayerInspector: Bool
    let isPackedLayerInputAlreadyOnCanvas: Bool
    let isFieldInMultifieldInput: Bool
    let isForFlyout: Bool
    let isSelectedInspectorRow: Bool
    
    let useIndividualFieldLabel: Bool

    // Used by button view to determine if some button has been pressed.
    // Saving this state outside the button context allows us to control renders.
    @State private var isButtonPressed = false
    
    var individualFieldLabelDisplay: LabelDisplayView {
        LabelDisplayView(label: self.viewModel.fieldLabel,
                         isLeftAligned: true,
                         fontColor: STITCH_FONT_GRAY_COLOR,
                         isSelectedInspectorRow: isSelectedInspectorRow)
    }

    @MainActor
    var valueDisplay: some View {
        InputFieldValueView(graph: graph,
                            document: document,
                            viewModel: viewModel,
                            propertySidebar: graph.propertySidebar,
                            node: node,
                            rowViewModel: rowViewModel,
                            canvasItem: canvasItem,
                            rowObserver: rowObserver,
                            isCanvasItemSelected: isCanvasItemSelected,
                            isForLayerInspector: isForLayerInspector,
                            isPackedLayerInputAlreadyOnCanvas: isPackedLayerInputAlreadyOnCanvas,
                            isFieldInMultifieldInput: isFieldInMultifieldInput,
                            isForFlyout: isForFlyout,
                            isSelectedInspectorRow: isSelectedInspectorRow,
                            hasIncomingEdge: hasIncomingEdge, // Only for pulse button and color orb; always false for inspector rows
                            isForLayerGroup: node.kind.getLayer == .group,
                            isButtonPressed: $isButtonPressed)
        .font(STITCH_FONT)
            // Monospacing prevents jittery node widths if values change on graphstep
            .monospacedDigit()
            .lineLimit(1)
    }
    
    var showIndividualFieldLabel: Bool {
        // Show individual field labels
        isForFlyout || (self.isFieldInMultifieldInput && self.useIndividualFieldLabel)
    }
    
    var body: some View {
        HStack(spacing: NODE_COMMON_SPACING) {
            
            if showIndividualFieldLabel {
                individualFieldLabelDisplay
            }

            if isForFlyout,
               isFieldInMultifieldInput {
                Spacer()
            }
            
            valueDisplay
        }
        .foregroundColor(VALUE_FIELD_BODY_COLOR)
        .height(NODE_ROW_HEIGHT + 6)
        .allowsHitTesting(!(isForLayerInspector && isPackedLayerInputAlreadyOnCanvas))
    }

}

extension UnpackedPortType {
    // see the `.transform3D` case in `getFieldValueTypes`:
    // ASSUMES THIS IS A PORT TYPE FOR
    var fieldGroupLabelForUnpacked3DTransformInput: String {
        switch self {
        case .port0, .port1, .port2:
            return "Position"
        case .port3, .port4, .port5:
            return "Scale"
        case .port6, .port7, .port8:
            return "Rotation"
        }
    }
}

// fka `InputValueView`
struct InputFieldValueView: View {
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var viewModel: InputFieldViewModel
    @Bindable var propertySidebar: PropertySidebarObserver
    let node: NodeViewModel
    let rowViewModel: InputNodeRowViewModel
    let canvasItem: CanvasItemViewModel?
    let rowObserver: InputNodeRowObserver
    let isCanvasItemSelected: Bool
    let isForLayerInspector: Bool
    let isPackedLayerInputAlreadyOnCanvas: Bool
    let isFieldInMultifieldInput: Bool
    let isForFlyout: Bool
    let isSelectedInspectorRow: Bool
    
    var hasIncomingEdge: Bool
    var isForLayerGroup: Bool
    
    var isUpstreamValue: Bool {
        hasIncomingEdge
    }

    @Binding var isButtonPressed: Bool
    
    var fieldCoordinate: FieldCoordinate {
        self.viewModel.id
    }
    
    var fieldValue: FieldValue {
        viewModel.fieldValue
    }

    var isFieldInsideLayerInspector: Bool {
        rowViewModel.isFieldInsideLayerInspector
    }
    
    // Which part of the port-value this value is for.
    // eg for a `.position3D` port-value:
    // field index 0 = x
    // field index 1 = y
    // field index 2 = z
    var fieldIndex: Int {
        viewModel.fieldIndex
    }
    
    var nodeKind: NodeKind {
        self.node.kind
    }

    // TODO: is `InputFieldValueView` ever used in the layer inspector now? ... vs flyout?
    @MainActor
    var hasHeterogenousValues: Bool {
        guard rowViewModel.id.graphItemType.isLayerInspector,
             let layerInputPort = rowViewModel.id.layerInputPort else {
            return false
        }
        
        return propertySidebar.heterogenousFieldsMap?
            .get(layerInputPort)?
            .contains(self.fieldIndex) ?? false
    }
    
    var layerInputPort: LayerInputPort? {
        self.rowViewModel.id.layerInputPort
    }
    
    var body: some View {
        // NodeLayout(observer: viewModel,
        //            existingCache: viewModel.viewCache) {
            switch fieldValue {
            case .string:
                CommonEditingViewWrapper(graph: graph,
                                         document: document,
                                         fieldViewModel: viewModel,
                                         rowObserver: rowObserver,
                                         rowViewModel: rowViewModel,
                                         fieldValue: fieldValue,
                                         fieldCoordinate: fieldCoordinate,
                                         isCanvasItemSelected: isCanvasItemSelected,
                                         choices: nil,
                                         isForLayerInspector: isForLayerInspector,
                                         isPackedLayerInputAlreadyOnCanvas: isPackedLayerInputAlreadyOnCanvas,
                                         hasHeterogenousValues: hasHeterogenousValues,
                                         isFieldInMultifieldInput: isFieldInMultifieldInput,
                                         isForFlyout: isForFlyout,
                                         isSelectedInspectorRow: isSelectedInspectorRow,
                                         nodeKind: nodeKind)
                
            case .number:
                FieldValueNumberView(graph: graph,
                                     document: document,
                                     rowObserver: rowObserver,
                                     rowViewModel: rowViewModel,
                                     fieldViewModel: viewModel,
                                     fieldValue: fieldValue,
                                     fieldValueNumberType: .number,
                                     fieldCoordinate: fieldCoordinate,
                                     isCanvasItemSelected: isCanvasItemSelected,
                                     choices: nil,
                                     isForLayerInspector: isForLayerInspector,
                                     hasHeterogenousValues: hasHeterogenousValues,
                                     isPackedLayerInputAlreadyOnCanvas: isPackedLayerInputAlreadyOnCanvas,
                                     isFieldInMultifieldInput: isFieldInMultifieldInput,
                                     isForFlyout: isForFlyout,
                                     isSelectedInspectorRow: isSelectedInspectorRow,
                                     nodeKind: nodeKind)
                
            case .layerDimension(let layerDimensionField):
                FieldValueNumberView(graph: graph,
                                     document: document,
                                     rowObserver: rowObserver,
                                     rowViewModel: rowViewModel,
                                     fieldViewModel: viewModel,
                                     fieldValue: fieldValue,
                                     fieldValueNumberType: layerDimensionField.fieldValueNumberType,
                                     fieldCoordinate: fieldCoordinate,
                                     isCanvasItemSelected: isCanvasItemSelected,
                                     choices: graph.getFilteredLayerDimensionChoices(node: node,
                                                                                     layerInputPort: layerInputPort,
                                                                                     activeIndex: document.activeIndex)
                                        .map(\.rawValue),
                                     isForLayerInspector: isForLayerInspector,
                                     hasHeterogenousValues: hasHeterogenousValues,
                                     isPackedLayerInputAlreadyOnCanvas: isPackedLayerInputAlreadyOnCanvas,
                                     isFieldInMultifieldInput: isFieldInMultifieldInput,
                                     isForFlyout: isForFlyout,
                                     isSelectedInspectorRow: isSelectedInspectorRow,
                                     isForLayerDimensionField: true,
                                     nodeKind: nodeKind)
                
            case .spacing:
                FieldValueNumberView(graph: graph,
                                     document: document,
                                     rowObserver: rowObserver,
                                     rowViewModel: rowViewModel,
                                     fieldViewModel: viewModel,
                                     fieldValue: fieldValue,
                                     fieldValueNumberType: .number,
                                     fieldCoordinate: fieldCoordinate,
                                     isCanvasItemSelected: isCanvasItemSelected,
                                     choices: StitchSpacing.choices,
                                     isForLayerInspector: isForLayerInspector,
                                     hasHeterogenousValues: hasHeterogenousValues,
                                     isPackedLayerInputAlreadyOnCanvas: isPackedLayerInputAlreadyOnCanvas,
                                     isFieldInMultifieldInput: isFieldInMultifieldInput,
                                     isForFlyout: isForFlyout,
                                     isSelectedInspectorRow: isSelectedInspectorRow,
                                     isForSpacingField: true,
                                     nodeKind: nodeKind)
                
            case .bool(let bool):
                BoolCheckboxView(rowObserver: rowObserver,
                                 graph: graph,
                                 document: document,
                                 value: bool,
                                 isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                 isSelectedInspectorRow: isSelectedInspectorRow,
                                 isMultiselectInspectorInputWithHeterogenousValues: hasHeterogenousValues)
                
            case .dropdown(let choiceDisplay, let choices):
                DropDownChoiceView(rowObserver: rowObserver,
                                   graph: graph,
                                   choiceDisplay: choiceDisplay,
                                   choices: choices,
                                   isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                   isSelectedInspectorRow: isSelectedInspectorRow,
                                   hasHeterogenousValues: hasHeterogenousValues,
                                   activeIndex: document.activeIndex)
                
            case .textFontDropdown(let stitchFont):
                StitchFontDropdown(rowObserver: rowObserver,
                                   graph: graph,
                                   stitchFont: stitchFont,
                                   isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                   isSelectedInspectorRow: isSelectedInspectorRow,
                                   hasHeterogenousValues: hasHeterogenousValues,
                                   activeIndex: document.activeIndex)
                // need enough width for font design + font weight name
                .frame(minWidth: TEXT_FONT_DROPDOWN_WIDTH,
                       alignment: isFieldInsideLayerInspector ? .trailing : .leading)
                
            case .layerDropdown(let layerId):
                LayerNamesDropDownChoiceView(
                    graph: graph,
                    visibleNodes: graph.visibleNodesViewModel,
                    rowObserver: rowObserver,
                    value: .assignedLayer(layerId),
                    isFieldInsideLayerInspector: rowViewModel.isFieldInsideLayerInspector,
                    isForPinTo: false,
                    isSelectedInspectorRow: isSelectedInspectorRow,
                    choices: graph
                        .layerDropdownChoices(isForNode: node.id,
                                              isForLayerGroup: false,
                                              isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                              isForPinTo: false),
                    hasHeterogenousValues: hasHeterogenousValues,
                    activeIndex: document.activeIndex)
                
            case .anchorEntity(let anchorEntityId):
                AnchorEntitiesDropdownView(rowObserver: rowObserver,
                                           graph: graph,
                                           value: .anchorEntity(anchorEntityId),
                                           isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                           activeIndex: document.activeIndex)
            
            case .layerGroupOrientationDropdown(let x):
                LayerGroupOrientationDropDownChoiceView(
                    rowObserver: rowObserver,
                    graph: graph,
                    value: x,
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                    hasHeterogenousValues: hasHeterogenousValues,
                    activeIndex: document.activeIndex)
                
            case .layerGroupAlignment(let x):

                // If this field is for a LayerGroup layer node,
                // and the layer node has a VStack or HStack layerGroupOrientation,
                // then use this special picker:
                if nodeKind.getLayer == .group,
                   let layerNode = node.layerNodeViewModel,
                   let orientation = layerNode.orientationPort
                    .getActiveValue(activeIndex: document.activeIndex)
                    .getOrientation {
                    switch orientation {
                    case .vertical:
                        // logInView("InputValueView: vertical")
                        LayerGroupHorizontalAlignmentPickerFieldValueView(
                            rowObserver: rowObserver,
                            graph: graph,
                            value: x,
                            isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                            hasHeterogenousValues: hasHeterogenousValues,
                            activeIndex: document.activeIndex)
                    case .horizontal:
                        // logInView("InputValueView: vertical")
                        LayerGroupVerticalAlignmentPickerFieldValueView(
                            rowObserver: rowObserver,
                            graph: graph,
                            activeIndex: document.activeIndex,
                            value: x,
                            isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                            hasHeterogenousValues: hasHeterogenousValues)
                        
                    case .grid, .none:
                        // Should never happen
                        // logInView("InputValueView: grid or none")
                        EmptyView()
                    }
                } else {
                    EmptyView()
                }
                
            case .textAlignmentPicker(let x):
                SpecialPickerFieldValueView(
                    currentChoice: .textAlignment(x),
                    rowObserver: rowObserver,
                    graph: graph,
                    value: .textAlignment(x),
                    choices: LayerTextAlignment.choices,
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                    hasHeterogenousValues: hasHeterogenousValues,
                    activeIndex: document.activeIndex)
                
            case .textVerticalAlignmentPicker(let x):
                SpecialPickerFieldValueView(
                    currentChoice: .textVerticalAlignment(x),
                    rowObserver: rowObserver,
                    graph: graph,
                    value: .textVerticalAlignment(x),
                    choices: LayerTextVerticalAlignment.choices,
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                    hasHeterogenousValues: hasHeterogenousValues,
                    activeIndex: document.activeIndex)
            
            case .textDecoration(let x):
                SpecialPickerFieldValueView(
                    currentChoice: .textDecoration(x),
                    rowObserver: rowObserver,
                    graph: graph,
                    value: .textDecoration(x),
                    choices: LayerTextDecoration.choices,
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                    hasHeterogenousValues: hasHeterogenousValues,
                    activeIndex: document.activeIndex)
                
            case .pinTo(let pinToId):
                LayerNamesDropDownChoiceView(
                    graph: graph,
                    visibleNodes: graph.visibleNodesViewModel,
                    rowObserver: rowObserver,
                    value: .pinTo(pinToId),
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                    isForPinTo: true,
                    isSelectedInspectorRow: isSelectedInspectorRow,
                    choices: graph
                        .layerDropdownChoices(isForNode: node.id,
                                              isForLayerGroup: isForLayerGroup,
                                              isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                              isForPinTo: true),
                    hasHeterogenousValues: hasHeterogenousValues,
                    activeIndex: document.activeIndex)
                
            case .anchorPopover(let anchor):
                AnchorPopoverView(rowObserver: rowObserver,
                                  graph: graph,
                                  document: document,
                                  selection: anchor,
                                  isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                  isSelectedInspectorRow: isSelectedInspectorRow,
                                  hasHeterogenousValues: hasHeterogenousValues)
                .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                       height: NODE_ROW_HEIGHT,
                       // Note: why are these reversed? Because we scaled the view down?
                       alignment: isForLayerInspector ? .leading : .trailing)
                .offset(x: isForLayerInspector ? -4 : 4)
                
                
            case .media(let media):
                if let mediaType = self.nodeKind.mediaType(coordinate: rowObserver.id) {
                    MediaInputFieldValueView(
                        viewModel: viewModel,
                        rowObserver: rowObserver,
                        node: node,
                        isUpstreamValue: isUpstreamValue,
                        media: media,
                        mediaName: media.name,
                        nodeKind: nodeKind,
                        isInput: true,
                        fieldIndex: fieldIndex,
                        isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                        isSelectedInspectorRow: isSelectedInspectorRow,
                        isMultiselectInspectorInputWithHeterogenousValues: hasHeterogenousValues,
                        mediaType: mediaType,
                        graph: graph,
                        document: document)
                } else {
                    Color.clear
                        .onAppear {
                            fatalErrorIfDebug()
                        }
                }
                
            case .color(let color):
                ColorOrbValueButtonView(fieldViewModel: viewModel,
                                        rowViewModel: rowViewModel,
                                        rowObserver: rowObserver,
                                        isForFlyout: isForFlyout,
                                        currentColor: color,
                                        hasIncomingEdge: hasIncomingEdge,
                                        graph: graph,
                                        isMultiselectInspectorInputWithHeterogenousValues: hasHeterogenousValues,
                                        activeIndex: document.activeIndex)
                
            case .pulse(let pulseTime):
                PulseValueButtonView(graph: graph,
                                     rowObserver: rowObserver,
                                     canvasItem: canvasItem,
                                     pulseTime: pulseTime,
                                     hasIncomingEdge: hasIncomingEdge)
                
            case .json(let json):
                EditJSONEntry(graph: graph,
                              coordinate: fieldCoordinate,
                              rowObserver: rowObserver,
                              json: isButtonPressed ? json : nil,
                              isSelectedInspectorRow: isSelectedInspectorRow,
                              activeIndex: document.activeIndex,
                              isPressed: $isButtonPressed)
                
            // TODO: is this relevant for multiselect?
            // Note: can an input EVER really have a 'read-only' value? Isn't this fieldValue case just for outputs?
            case .readOnly(let string):
                ReadOnlyValueEntry(value: string,
                                   alignment: .leading,
                                   fontColor: STITCH_FONT_GRAY_COLOR,
                                   isSelectedInspectorRow: isSelectedInspectorRow,
                                   forPropertySidebar: isForLayerInspector,
                                   isFieldInMultifieldInput: isFieldInMultifieldInput)
            }
        // }
    }
}
