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
    @Bindable var rowViewModel: OutputNodeRowViewModel
    @Bindable var viewModel: OutputFieldViewModel

    let coordinate: NodeIOCoordinate
    let isMultiField: Bool
    let nodeKind: NodeKind
    let isCanvasItemSelected: Bool
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool

    // Used by button view to determine if some button has been pressed.
    // Saving this state outside the button context allows us to control renders.
    @State private var isButtonPressed = false

    var label: String {
        self.viewModel.fieldLabel
    }
    
    var labelDisplay: some View {
        LabelDisplayView(label: label,
                         isLeftAligned: false,
                         // Gray color for multi-field
//                         fontColor: isMultiField ? STITCH_FONT_GRAY_COLOR : Color(.titleFont))
                         // Seems like every input label is gray now?
                         fontColor: STITCH_FONT_GRAY_COLOR)
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
                        isButtonPressed: $isButtonPressed)
            .font(STITCH_FONT)
            // Monospacing prevents jittery node widths if values change on graphstep
            .monospacedDigit()
            .lineLimit(1)
    }

    var body: some View {
        HStack(spacing: NODE_COMMON_SPACING) {
            labelDisplay
            //                .border(.blue)
            valueDisplay
            //                .border(.green)
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
        switch fieldValue {
        case .string(let string):
            // Leading alignment when multifield
            ReadOnlyValueEntry(value: string.string,
                               alignment: outputAlignment,
                               fontColor: STITCH_FONT_GRAY_COLOR)

        case .number, .layerDimension, .spacing:
            ReadOnlyValueEntry(value: fieldValue.stringValue,
                               alignment: outputAlignment,
                               fontColor: STITCH_FONT_GRAY_COLOR)

        case .bool(let bool):
            BoolCheckboxView(id: nil,
                             value: bool)

        case .dropdown(let choiceDisplay, let _):
            // Values that use dropdowns for their inputs use instead a display-only view for their outputs
            ReadOnlyValueEntry(value: choiceDisplay,
                               alignment: outputAlignment,
                               fontColor: STITCH_FONT_GRAY_COLOR)

        case .textFontDropdown(let stitchFont):
            StitchFontDropdown(input: coordinate,
                               stitchFont: stitchFont)
                // need enough width for font design + font weight name
                .frame(minWidth: 200,
                       alignment: .leading)

        case .layerDropdown(let layerId):
            // TODO: disable or use read-only view if this is an output ?
            LayerNamesDropDownChoiceView(graph: graph,
                                         id: coordinate,
                                         value: .assignedLayer(layerId))
            .disabled(true)

        case .anchorPopover(let anchor):
            AnchorPopoverView(input: coordinate,
                              selection: anchor)
            .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                   height: NODE_ROW_HEIGHT,
                   // Note: why are these reversed? Because we scaled the view down?
                   alignment: .leading)

        case .media(let media):
            MediaFieldValueView(inputCoordinate: coordinate,
                                isUpstreamValue: false,     // only valid for inputs
                                media: media,
                                nodeKind: nodeKind,
                                isInput: false,
                                fieldIndex: fieldIndex,
                                isNodeSelected: isCanvasItemSelected,
                                hasIncomingEdge: false)

        case .color(let color):
            StitchColorPickerOrb(chosenColor: color)

        case .pulse(let pulseTime):
            PulseValueButtonView(
                graph: graph,
                inputPort: nil,
                stitchId: coordinate.nodeId,
                pulseTime: pulseTime,
                hasIncomingEdge: false)

        case .json(let json):
            ValueJSONView(coordinate: coordinate,
                          json: isButtonPressed ? json : nil,
                          isPressed: $isButtonPressed)

        case .readOnly(let string):
            ReadOnlyValueEntry(value: string,
                               alignment: outputAlignment,
                               fontColor: STITCH_FONT_GRAY_COLOR)
        }
    }
}
