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
    @Bindable var viewModel: OutputFieldViewModel

    let coordinate: NodeIOCoordinate
    let isMultiField: Bool
    let nodeKind: NodeKind
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
                        viewModel: viewModel,
                        coordinate: coordinate,
                        isMultiField: isMultiField,
                        nodeKind: nodeKind,
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
    @Bindable var viewModel: OutputFieldViewModel
    
    let coordinate: NodeIOCoordinate
    let isMultiField: Bool
    let nodeKind: NodeKind
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

    var body: some View {
//        NodeLayoutView(observer: viewModel) {
            switch fieldValue {
            case .string(let string):
                // Leading alignment when multifield
                ReadOnlyValueEntry(value: string.string,
                                   alignment: outputAlignment,
                                   fontColor: STITCH_FONT_GRAY_COLOR,
                                   isSelectedInspectorRow: isSelectedInspectorRow,
                                   forPropertySidebar: forPropertySidebar,
                                   isFieldInMultifieldInput: isFieldInMultifieldInput)
                
            case .number, .layerDimension, .spacing:
                ReadOnlyValueEntry(value: fieldValue.stringValue,
                                   alignment: outputAlignment,
                                   fontColor: STITCH_FONT_GRAY_COLOR,
                                   isSelectedInspectorRow: isSelectedInspectorRow,
                                   forPropertySidebar: forPropertySidebar,
                                   isFieldInMultifieldInput: isFieldInMultifieldInput)
                
            case .bool(let bool):
                BoolCheckboxView(id: nil,
                                 layerInputObserver: nil,
                                 value: bool,
                                 isFieldInsideLayerInspector: false,
                                 isSelectedInspectorRow: isSelectedInspectorRow)
                
            case .dropdown(let choiceDisplay, _):
                // Values that use dropdowns for their inputs use instead a display-only view for their outputs
                ReadOnlyValueEntry(value: choiceDisplay,
                                   alignment: outputAlignment,
                                   fontColor: STITCH_FONT_GRAY_COLOR,
                                   isSelectedInspectorRow: isSelectedInspectorRow,
                                   forPropertySidebar: forPropertySidebar,
                                   isFieldInMultifieldInput: isFieldInMultifieldInput)
                
            case .textFontDropdown(let stitchFont):
                StitchFontDropdown(input: coordinate,
                                   stitchFont: stitchFont,
                                   layerInputObserver: nil,
                                   isFieldInsideLayerInspector: false,
                                   propertyIsSelected: isSelectedInspectorRow)
                // need enough width for font design + font weight name
                .frame(minWidth: 200,
                       alignment: .leading)
                .disabled(true)
                
            case .layerDropdown(let layerId):
                // TODO: use read-only view if this is an output ?
                LayerNamesDropDownChoiceView(graph: graph,
                                             id: coordinate,
                                             value: .assignedLayer(layerId),
                                             layerInputObserver: nil,
                                             isFieldInsideLayerInspector: false,
                                             isForPinTo: false,
                                             isSelectedInspectorRow: isSelectedInspectorRow,
                                             choices: []
                                             //                                            graph.layerDropdownChoices(
                                             //                                            isForNode: coordinate.nodeId,
                                             //                                            isForLayerGroup: false,
                                             ////                                            isFieldInsideLayerInspector: false,
                                             //                                            isForPinTo: false)
                )
                .disabled(true)
                
            case .layerGroupOrientationDropdown(let x):
                LayerGroupOrientationDropDownChoiceView(
                    id: coordinate,
                    value: x,
                    layerInputObserver: nil,
                    isFieldInsideLayerInspector: false)
                .disabled(true)
                
            case .pinTo(let pinToId):
                LayerNamesDropDownChoiceView(graph: graph,
                                             id: coordinate,
                                             value: .pinTo(pinToId),
                                             layerInputObserver: nil,
                                             isFieldInsideLayerInspector: false,
                                             isForPinTo: true,
                                             isSelectedInspectorRow: isSelectedInspectorRow,
                                             choices: [] //[pinToId.asLayerDropdownChoice] //
                                             //                                            graph.layerDropdownChoices(
                                             //                                            isForNode: coordinate.nodeId,
                                             //                                            isForLayerGroup: false,
                                             ////                                            isFieldInsideLayerInspector: false,
                                             //                                            isForPinTo: false)
                )
                
                .disabled(true)
                
            case .anchorPopover(let anchor):
                AnchorPopoverView(input: coordinate,
                                  selection: anchor,
                                  layerInputObserver: nil,
                                  isFieldInsideLayerInspector: false,
                                  isSelectedInspectorRow: isSelectedInspectorRow)
                .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                       height: NODE_ROW_HEIGHT,
                       // Note: why are these reversed? Because we scaled the view down?
                       alignment: .leading)
                
            case .media(let media):
                MediaFieldValueView(inputCoordinate: coordinate,
                                    layerInputObserver: nil,
                                    isUpstreamValue: false,     // only valid for inputs
                                    media: media,
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
                PulseValueButtonView(inputCoordinate: nil,
                                     nodeId: coordinate.nodeId,
                                     pulseTime: pulseTime,
                                     hasIncomingEdge: false)
                
            case .json(let json):
                ValueJSONView(coordinate: coordinate,
                              json: isButtonPressed ? json : nil,
                              isSelectedInspectorRow: isSelectedInspectorRow,
                              isPressed: $isButtonPressed)
                
            case .readOnly(let string):
                ReadOnlyValueEntry(value: string,
                                   alignment: outputAlignment,
                                   fontColor: STITCH_FONT_GRAY_COLOR,
                                   isSelectedInspectorRow: isSelectedInspectorRow,
                                   forPropertySidebar: forPropertySidebar,
                                   isFieldInMultifieldInput: isFieldInMultifieldInput)
            }
//        }
    }
}
