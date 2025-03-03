//
//  OutputValueView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/28/24.
//

import SwiftUI
import StitchSchemaKit

struct OutputValueEntry: View {

    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    @Bindable var viewModel: OutputFieldViewModel

    let rowViewModel: OutputNodeRowViewModel
    let rowObserver: OutputNodeRowObserver
    let node: NodeViewModel
    let canvasItem: CanvasItemViewModel?
    let isMultiField: Bool
    let isCanvasItemSelected: Bool
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool
    let isFieldInMultifieldInput: Bool
    let isSelectedInspectorRow: Bool

    // Used by button view to determine if some button has been pressed.
    // Saving this state outside the button context allows us to control renders.
    @State private var isButtonPressed = false

    var label: String {
        self.viewModel.fieldLabel
    }
    
    var labelDisplay: some View {
        LabelDisplayView(label: label,
                         isLeftAligned: false,
                         fontColor: STITCH_FONT_GRAY_COLOR,
                         isSelectedInspectorRow: isSelectedInspectorRow)
    }

    var valueDisplay: some View {
        OutputValueView(graph: graph,
                        graphUI: graphUI,
                        viewModel: viewModel,
                        rowViewModel: rowViewModel,
                        rowObserver: rowObserver,
                        node: node,
                        canvasItem: canvasItem,
                        isMultiField: isMultiField,
                        isCanvasItemSelected: isCanvasItemSelected,
                        forPropertySidebar: forPropertySidebar,
                        propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                        isFieldInMultifieldInput: isFieldInMultifieldInput,
                        isSelectedInspectorRow: isSelectedInspectorRow,
                        isButtonPressed: $isButtonPressed)
            .font(STITCH_FONT)
            // Monospacing prevents jittery node widths if values change on graphstep
            .monospacedDigit()
            .lineLimit(1)
    }

    var body: some View {
        HStack(spacing: NODE_COMMON_SPACING) {
            labelDisplay
            valueDisplay
        }
        .foregroundColor(VALUE_FIELD_BODY_COLOR)
        .height(NODE_ROW_HEIGHT + 6)
    }

}

struct OutputValueView: View {
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    @Bindable var viewModel: OutputFieldViewModel
    
    let rowViewModel: OutputNodeRowViewModel
    let rowObserver: OutputNodeRowObserver
    let node: NodeViewModel
    let canvasItem: CanvasItemViewModel?
    let isMultiField: Bool
    let isCanvasItemSelected: Bool
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool
    let isFieldInMultifieldInput: Bool
    let isSelectedInspectorRow: Bool
    
    @Binding var isButtonPressed: Bool

    var fieldValue: FieldValue {
        viewModel.fieldValue
    }

    // Which part of the port-value this value is for.
    // eg for a `.position3D` port-value:
    // field index 0 = x
    // field index 1 = y
    // field index 2 = z
    var fieldIndex: Int {
        viewModel.fieldIndex
    }

    // Are the values left- or right-aligned?
    // Left-aligned when:
    // - input or,
    // - field within a multifield output
    var outputAlignment: Alignment {
        if forPropertySidebar {
            return .leading
        } else {
            return isMultiField ? .leading : .trailing
        }
    }
    
    var nodeKind: NodeKind {
        self.node.kind
    }

    var body: some View {
//        NodeLayoutView(observer: viewModel) {
            switch fieldValue {
            case .string(let string):
                // Leading alignment when multifield
                readOnlyView(string.string)
                
            case .number, .layerDimension, .spacing:
                readOnlyView(fieldValue.stringValue)
                
            case .bool(let bool):
                BoolCheckboxView(rowObserver: nil,
                                 graph: graph,
                                 layerInputObserver: nil,
                                 value: bool,
                                 isFieldInsideLayerInspector: false,
                                 isSelectedInspectorRow: isSelectedInspectorRow)
                
            case .dropdown(let choiceDisplay, _):
                // Values that use dropdowns for their inputs use instead a display-only view for their outputs
                readOnlyView(choiceDisplay)
                
//            case .textFontDropdown(let stitchFont):
//                StitchFontDropdown(input: rowObserver,
//                                   stitchFont: stitchFont,
//                                   layerInputObserver: nil,
//                                   isFieldInsideLayerInspector: false,
//                                   propertyIsSelected: isSelectedInspectorRow)
//                // need enough width for font design + font weight name
//                .frame(minWidth: 200,
//                       alignment: .leading)
//                .disabled(true)
                
//            case .layerDropdown(let layerId):
//                // TODO: use read-only view if this is an output ?
//                LayerNamesDropDownChoiceView(graph: graph,
//                                             id: coordinate,
//                                             value: .assignedLayer(layerId),
//                                             layerInputObserver: nil,
//                                             isFieldInsideLayerInspector: false,
//                                             isForPinTo: false,
//                                             isSelectedInspectorRow: isSelectedInspectorRow,
//                                             choices: [])
//                .disabled(true)
                
            case .anchorEntity(let anchorEntityId):
                let displayName = graph.getNodeViewModel(anchorEntityId ?? .init())?.getDisplayTitle() ?? AnchorDropdownChoice.noneDisplayName
                readOnlyView(displayName)
                
//            case .layerGroupOrientationDropdown(let x):
//                LayerGroupOrientationDropDownChoiceView(
//                    id: coordinate,
//                    value: x,
//                    layerInputObserver: nil,
//                    isFieldInsideLayerInspector: false)
//                .disabled(true)
                
            case .layerGroupAlignment(_):
                EmptyView() // Can't really happen
            
//            case .textAlignmentPicker(let x):
//                SpecialPickerFieldValueView(
//                    currentChoice: .textAlignment(x),
//                    id: coordinate,
//                    value: .textAlignment(x),
//                    choices: LayerTextAlignment.choices,
//                    layerInputObserver: nil,
//                    isFieldInsideLayerInspector: false)
//                .disabled(false)
                
//            case .textVerticalAlignmentPicker(let x):
//                SpecialPickerFieldValueView(
//                    currentChoice: .textVerticalAlignment(x),
//                    id: coordinate,
//                    value: .textVerticalAlignment(x),
//                    choices: LayerTextVerticalAlignment.choices,
//                    layerInputObserver: nil,
//                    isFieldInsideLayerInspector: false)
//                .disabled(false)
//            
//            case .textDecoration(let x):
//                SpecialPickerFieldValueView(
//                    currentChoice: .textDecoration(x),
//                    id: coordinate,
//                    value: .textDecoration(x),
//                    choices: LayerTextDecoration.choices,
//                    layerInputObserver: nil,
//                    isFieldInsideLayerInspector: false)
//                .disabled(false)
//                
//            case .pinTo(let pinToId):
//                LayerNamesDropDownChoiceView(graph: graph,
//                                             id: coordinate,
//                                             value: .pinTo(pinToId),
//                                             layerInputObserver: nil,
//                                             isFieldInsideLayerInspector: false,
//                                             isForPinTo: true,
//                                             isSelectedInspectorRow: isSelectedInspectorRow,
//                                             choices: [] //[pinToId.asLayerDropdownChoice] //
//                                             //                                            graph.layerDropdownChoices(
//                                             //                                            isForNode: coordinate.nodeId,
//                                             //                                            isForLayerGroup: false,
//                                             ////                                            isFieldInsideLayerInspector: false,
//                                             //                                            isForPinTo: false)
//                )
//                
//                .disabled(true)
                
//            case .anchorPopover(let anchor):
//                AnchorPopoverView(input: coordinate,
//                                  selection: anchor,
//                                  layerInputObserver: nil,
//                                  isFieldInsideLayerInspector: false,
//                                  isSelectedInspectorRow: isSelectedInspectorRow)
//                .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
//                       height: NODE_ROW_HEIGHT,
//                       // Note: why are these reversed? Because we scaled the view down?
//                       alignment: .leading)
                
            case .media(let media):
                MediaFieldValueView(viewModel: viewModel,
                                    rowViewModel: rowViewModel,
                                    rowObserver: rowObserver,
                                    node: node,
                                    layerInputObserver: nil,
                                    isUpstreamValue: false,     // only valid for inputs
                                    media: media,
                                    mediaName: media.name,
                                    nodeKind: nodeKind,
                                    isInput: false,
                                    fieldIndex: fieldIndex,
                                    isNodeSelected: isCanvasItemSelected,
                                    isFieldInsideLayerInspector: false,
                                    isSelectedInspectorRow: isSelectedInspectorRow,
                                    graph: graph)
                
            case .color(let color):
                StitchColorPickerOrb(chosenColor: color,
                                     isMultiselectInspectorInputWithHeterogenousValues: false)
                
            case .pulse(let pulseTime):
                PulseValueButtonView(graph: graph,
                                     graphUI: graphUI,
                                     rowObserver: nil,
                                     canvasItem: canvasItem,
                                     pulseTime: pulseTime,
                                     hasIncomingEdge: false)
                
            case .json(let json):
                ValueJSONView(coordinate: rowViewModel.id.asNodeIOCoordinate,
                              json: isButtonPressed ? json : nil,
                              isSelectedInspectorRow: isSelectedInspectorRow,
                              isPressed: $isButtonPressed)
                
            default:
                readOnlyView(self.fieldValue.stringValue)
            }
//        }
    }

    @ViewBuilder func readOnlyView(_ displayName: String) -> some View {
        ReadOnlyValueEntry(value: displayName,
                           alignment: outputAlignment,
                           fontColor: STITCH_FONT_GRAY_COLOR,
                           isSelectedInspectorRow: isSelectedInspectorRow,
                           forPropertySidebar: forPropertySidebar,
                           isFieldInMultifieldInput: isFieldInMultifieldInput)
    }
}
