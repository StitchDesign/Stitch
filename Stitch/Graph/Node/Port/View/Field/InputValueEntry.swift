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
    @Bindable var graphUI: GraphUIState
    
    @Bindable var viewModel: InputFieldViewModel
    let node: NodeViewModel
    let rowViewModel: InputNodeRowViewModel
    let layerInputObserver: LayerInputObserver?
    let canvasItem: CanvasItemViewModel?
    
    let rowObserver: InputNodeRowObserver
    let isCanvasItemSelected: Bool
    let hasIncomingEdge: Bool
    
    // TODO: package these up into `InspectorData` ?
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool
    let isFieldInMultifieldInput: Bool
    let isForFlyout: Bool
    let isSelectedInspectorRow: Bool

    // Used by button view to determine if some button has been pressed.
    // Saving this state outside the button context allows us to control renders.
    @State private var isButtonPressed = false
    
    var individualFieldLabel: String {
        self.viewModel.fieldLabel
    }
    
    // TRICKY: currently only used for unpacked 3D Transform fields on the canvas,
    // but such *unpacked* values are treated as Number fields.
    // So we check information about the parent (i.e. the whole layer input, LayerInputObserver) and compare against child (i.e. the individual field, UnpackedPortType).
    var fieldsRowLabel: String? {
        if let layerInputObserver = layerInputObserver,
           layerInputObserver.port == .transform3D {
            
            if layerInputObserver.mode == .unpacked,
               let fieldGroupLabel = rowObserver.id.keyPath?.getUnpackedPortType?.fieldGroupLabelForUnpacked3DTransformInput {
                
                return layerInputObserver.port.label() + " " + fieldGroupLabel
            } else {
                // Show '3D Transform' label on packed 3D Transform input-on-canvas
                return layerInputObserver.port.label()
            }
        }
        
        return nil
    }
    
    // TODO: support derived field-labels
    // TODO: perf-impact? is this running all the time?
    @MainActor
    var useIndividualFieldLabel: Bool {
        if forPropertySidebar,
           isFieldInMultifieldInput,
           !isForFlyout,
           // Do not use labels on the fields of a padding-type input
           (layerInputObserver?
            .getActiveValue(activeIndex: self.graphUI.activeIndex)
            .getPadding.isDefined ?? false) {
            return false
        }
        
        return true
    }
        
    var individualFieldLabelDisplay: LabelDisplayView {
        LabelDisplayView(label: individualFieldLabel,
                         isLeftAligned: true,
                         fontColor: STITCH_FONT_GRAY_COLOR,
                         isSelectedInspectorRow: isSelectedInspectorRow)
    }

    @MainActor
    var valueDisplay: some View {
        InputValueView(graph: graph,
                       graphUI: graphUI,
                       viewModel: viewModel,
                       propertySidebar: graph.propertySidebar,
                       node: node,
                       rowViewModel: rowViewModel,
                       canvasItem: canvasItem,
                       rowObserver: rowObserver,
                       isCanvasItemSelected: isCanvasItemSelected,
                       forPropertySidebar: forPropertySidebar,
                       propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                       isFieldInMultifieldInput: isFieldInMultifieldInput,
                       isForFlyout: isForFlyout,
                       isSelectedInspectorRow: isSelectedInspectorRow,
                       
                       // Only for pulse button and color orb;
                       // Always false for inspector-rows
                       hasIncomingEdge: hasIncomingEdge,
                       
                       isForLayerGroup: node.kind.getLayer == .group,
                       
                       // This is same as `hasIncomingEdge` ? a check on whether rowDelegate has a defined upstream output (coordinate vs observer should not matter?)
                       isUpstreamValue: hasIncomingEdge,
                       isButtonPressed: $isButtonPressed)
            .font(STITCH_FONT)
            // Monospacing prevents jittery node widths if values change on graphstep
            .monospacedDigit()
            .lineLimit(1)
    }
    
    var body: some View {
        HStack(spacing: NODE_COMMON_SPACING) {
            
            if !forPropertySidebar,
               !isForFlyout,
               let fieldGroupLabel = fieldsRowLabel {
                LabelDisplayView(label: fieldGroupLabel,
                                 isLeftAligned: true,
                                 fontColor: STITCH_FONT_GRAY_COLOR,
                                 isSelectedInspectorRow: isSelectedInspectorRow)
            }
            
            if self.useIndividualFieldLabel {
                individualFieldLabelDisplay
            }
             
            if forPropertySidebar,
               isForFlyout,
               isFieldInMultifieldInput {
                Spacer()
            }
            
            valueDisplay
        }
        .foregroundColor(VALUE_FIELD_BODY_COLOR)
        .height(NODE_ROW_HEIGHT + 6)
        .allowsHitTesting(!(forPropertySidebar && propertyIsAlreadyOnGraph))
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

struct InputValueView: View {
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    @Bindable var viewModel: InputFieldViewModel
    @Bindable var propertySidebar: PropertySidebarObserver
    let node: NodeViewModel
    let rowViewModel: InputNodeRowViewModel
    let canvasItem: CanvasItemViewModel?
    let rowObserver: InputNodeRowObserver
    let isCanvasItemSelected: Bool
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool
    let isFieldInMultifieldInput: Bool
    let isForFlyout: Bool
    let isSelectedInspectorRow: Bool
    
    var hasIncomingEdge: Bool
    var isForLayerGroup: Bool
    var isUpstreamValue: Bool

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
                                         graphUI: graphUI,
                                         fieldViewModel: viewModel,
                                         rowObserver: rowObserver,
                                         rowViewModel: rowViewModel,
                                         fieldValue: fieldValue,
                                         fieldCoordinate: fieldCoordinate,
                                         isCanvasItemSelected: isCanvasItemSelected,
                                         choices: nil,
                                         forPropertySidebar: forPropertySidebar,
                                         propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                         hasHeterogenousValues: hasHeterogenousValues,
                                         isFieldInMultifieldInput: isFieldInMultifieldInput,
                                         isForFlyout: isForFlyout,
                                         isSelectedInspectorRow: isSelectedInspectorRow,
                                         nodeKind: nodeKind)
                
            case .number:
                FieldValueNumberView(graph: graph,
                                     graphUI: graphUI,
                                     rowObserver: rowObserver,
                                     rowViewModel: rowViewModel,
                                     fieldViewModel: viewModel,
                                     fieldValue: fieldValue,
                                     fieldValueNumberType: .number,
                                     fieldCoordinate: fieldCoordinate,
                                     isCanvasItemSelected: isCanvasItemSelected,
                                     choices: nil,
                                     forPropertySidebar: forPropertySidebar,
                                     hasHeterogenousValues: hasHeterogenousValues,
                                     propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                     isFieldInMultifieldInput: isFieldInMultifieldInput,
                                     isForFlyout: isForFlyout,
                                     isSelectedInspectorRow: isSelectedInspectorRow,
                                     nodeKind: nodeKind)
                
            case .layerDimension(let layerDimensionField):
                FieldValueNumberView(graph: graph,
                                     graphUI: graphUI,
                                     rowObserver: rowObserver,
                                     rowViewModel: rowViewModel,
                                     fieldViewModel: viewModel,
                                     fieldValue: fieldValue,
                                     fieldValueNumberType: layerDimensionField.fieldValueNumberType,
                                     fieldCoordinate: fieldCoordinate,
                                     isCanvasItemSelected: isCanvasItemSelected,
                                     choices: graph.getFilteredLayerDimensionChoices(node: node,
                                                                                     layerInputPort: layerInputPort,
                                                                                     activeIndex: graphUI.activeIndex)
                                        .map(\.rawValue),
                                     forPropertySidebar: forPropertySidebar,
                                     hasHeterogenousValues: hasHeterogenousValues,
                                     propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                     isFieldInMultifieldInput: isFieldInMultifieldInput,
                                     isForFlyout: isForFlyout,
                                     isSelectedInspectorRow: isSelectedInspectorRow,
                                     isForLayerDimensionField: true,
                                     nodeKind: nodeKind)
                
            case .spacing:
                FieldValueNumberView(graph: graph,
                                     graphUI: graphUI,
                                     rowObserver: rowObserver,
                                     rowViewModel: rowViewModel,
                                     fieldViewModel: viewModel,
                                     fieldValue: fieldValue,
                                     fieldValueNumberType: .number,
                                     fieldCoordinate: fieldCoordinate,
                                     isCanvasItemSelected: isCanvasItemSelected,
                                     choices: StitchSpacing.choices,
                                     forPropertySidebar: forPropertySidebar,
                                     hasHeterogenousValues: hasHeterogenousValues,
                                     propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                     isFieldInMultifieldInput: isFieldInMultifieldInput,
                                     isForFlyout: isForFlyout,
                                     isSelectedInspectorRow: isSelectedInspectorRow,
                                     isForSpacingField: true,
                                     nodeKind: nodeKind)
                
            case .bool(let bool):
                BoolCheckboxView(rowObserver: rowObserver,
                                 graph: graph,
                                 document: graphUI,
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
                                   activeIndex: graphUI.activeIndex)
                
            case .textFontDropdown(let stitchFont):
                StitchFontDropdown(rowObserver: rowObserver,
                                   graph: graph,
                                   stitchFont: stitchFont,
                                   isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                   propertyIsSelected: isSelectedInspectorRow,
                                   hasHeterogenousValues: hasHeterogenousValues,
                                   activeIndex: graphUI.activeIndex)
                // need enough width for font design + font weight name
                .frame(minWidth: TEXT_FONT_DROPDOWN_WIDTH,
                       alignment: .leading)
                
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
                    activeIndex: graphUI.activeIndex)
                
            case .anchorEntity(let anchorEntityId):
                AnchorEntitiesDropdownView(rowObserver: rowObserver,
                                           graph: graph,
                                           value: .anchorEntity(anchorEntityId),
                                           isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                           activeIndex: graphUI.activeIndex)
            
            case .layerGroupOrientationDropdown(let x):
                LayerGroupOrientationDropDownChoiceView(
                    rowObserver: rowObserver,
                    graph: graph,
                    value: x,
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                    hasHeterogenousValues: hasHeterogenousValues,
                    activeIndex: graphUI.activeIndex)
                
            case .layerGroupAlignment(let x):

                // If this field is for a LayerGroup layer node,
                // and the layer node has a VStack or HStack layerGroupOrientation,
                // then use this special picker:
                if nodeKind.getLayer == .group,
                   let layerNode = node.layerNodeViewModel,
                   let orientation = layerNode.orientationPort
                    .getActiveValue(activeIndex: graphUI.activeIndex)
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
                            activeIndex: graphUI.activeIndex)
                    case .horizontal:
                        // logInView("InputValueView: vertical")
                        LayerGroupVerticalAlignmentPickerFieldValueView(
                            rowObserver: rowObserver,
                            graph: graph,
                            activeIndex: graphUI.activeIndex,
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
                    activeIndex: graphUI.activeIndex)
                
            case .textVerticalAlignmentPicker(let x):
                SpecialPickerFieldValueView(
                    currentChoice: .textVerticalAlignment(x),
                    rowObserver: rowObserver,
                    graph: graph,
                    value: .textVerticalAlignment(x),
                    choices: LayerTextVerticalAlignment.choices,
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                    hasHeterogenousValues: hasHeterogenousValues,
                    activeIndex: graphUI.activeIndex)
            
            case .textDecoration(let x):
                SpecialPickerFieldValueView(
                    currentChoice: .textDecoration(x),
                    rowObserver: rowObserver,
                    graph: graph,
                    value: .textDecoration(x),
                    choices: LayerTextDecoration.choices,
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                    hasHeterogenousValues: hasHeterogenousValues,
                    activeIndex: graphUI.activeIndex)
                
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
                    activeIndex: graphUI.activeIndex)
                
            case .anchorPopover(let anchor):
                AnchorPopoverView(rowObserver: rowObserver,
                                  graph: graph,
                                  document: graphUI,
                                  selection: anchor,
                                  isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                  isSelectedInspectorRow: isSelectedInspectorRow,
                                  hasHeterogenousValues: hasHeterogenousValues)
                .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                       height: NODE_ROW_HEIGHT,
                       // Note: why are these reversed? Because we scaled the view down?
                       alignment: forPropertySidebar ? .leading : .trailing)
                .offset(x: forPropertySidebar ? -4 : 4)
                
                
            case .media(let media):
                MediaFieldValueView(
                    viewModel: viewModel,
                    rowViewModel: rowViewModel,
                    rowObserver: rowObserver,
                    node: node,
                    isUpstreamValue: isUpstreamValue,
                    media: media,
                    mediaName: media.name,
                    nodeKind: nodeKind,
                    isInput: true,
                    fieldIndex: fieldIndex,
                    isNodeSelected: isCanvasItemSelected,
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                    isSelectedInspectorRow: isSelectedInspectorRow,
                    isMultiselectInspectorInputWithHeterogenousValues: hasHeterogenousValues,
                    graph: graph,
                    document: graphUI)
                
            case .color(let color):
                ColorOrbValueButtonView(fieldViewModel: viewModel,
                                        rowViewModel: rowViewModel,
                                        rowObserver: rowObserver,
                                        isForFlyout: isForFlyout,
                                        currentColor: color,
                                        hasIncomingEdge: hasIncomingEdge,
                                        graph: graph,
                                        isMultiselectInspectorInputWithHeterogenousValues: hasHeterogenousValues,
                                        activeIndex: graphUI.activeIndex)
                
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
                              activeIndex: graphUI.activeIndex,
                              isPressed: $isButtonPressed)
                
            // TODO: is this relevant for multiselect?
            // Note: can an input EVER really have a 'read-only' value? Isn't this fieldValue case just for outputs?
            case .readOnly(let string):
                ReadOnlyValueEntry(value: string,
                                   alignment: .leading,
                                   fontColor: STITCH_FONT_GRAY_COLOR,
                                   isSelectedInspectorRow: isSelectedInspectorRow,
                                   forPropertySidebar: forPropertySidebar,
                                   isFieldInMultifieldInput: isFieldInMultifieldInput)
            }
        // }
    }
}
