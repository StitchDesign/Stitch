//
//  ValueEntry.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/14/22.
//

import SwiftUI
import StitchSchemaKit

struct ValueEntry: View {

    @Bindable var graph: GraphState
    @Bindable var rowObserver: NodeRowObserver
    @Bindable var viewModel: FieldViewModel

    let fieldCoordinate: FieldCoordinate
    let nodeIO: NodeIO
    let isMultiField: Bool
    let nodeKind: NodeKind
    let isCanvasItemSelected: Bool
    let hasIncomingEdge: Bool
    let adjustmentBarSessionId: AdjustmentBarSessionId
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool

    // Used by button view to determine if some button has been pressed.
    // Saving this state outside the button context allows us to control renders.
    @State private var isButtonPressed = false

    var coordinate: NodeIOCoordinate {
        // input is a bad name--could be either here
        self.fieldCoordinate.input
    }

    var isInput: Bool {
        self.nodeIO == .input
    }
    
    var label: String {
        self.viewModel.fieldLabel
    }
    
    var labelDisplay: some View {
        LabelDisplayView(label: label,
                         // TODO: this isn't always true
                         isLeftAligned: isInput,
                         // Gray color for multi-field
//                         fontColor: isMultiField ? STITCH_FONT_GRAY_COLOR : Color(.titleFont))
                         // Seems like every input label is gray now?
                         fontColor: STITCH_FONT_GRAY_COLOR)
    }

    var valueDisplay: some View {
        ValueView(graph: graph,
                  rowObserver: rowObserver,
                  viewModel: viewModel,
                  fieldCoordinate: fieldCoordinate,
                  coordinate: coordinate,
                  nodeIO: nodeIO,
                  isMultiField: isMultiField,
                  nodeKind: nodeKind,
                  isCanvasItemSelected: isCanvasItemSelected,
                  hasIncomingEdge: hasIncomingEdge,
                  adjustmentBarSessionId: adjustmentBarSessionId,
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

struct ValueView: View {
    @Bindable var graph: GraphState
    @Bindable var rowObserver: NodeRowObserver
    @Bindable var viewModel: FieldViewModel
    
    let fieldCoordinate: FieldCoordinate
    let coordinate: NodeIOCoordinate
    let nodeIO: NodeIO
    let isMultiField: Bool
    let nodeKind: NodeKind
    let isCanvasItemSelected: Bool
    let hasIncomingEdge: Bool
    let adjustmentBarSessionId: AdjustmentBarSessionId
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
        isMultiField ? .leading : .trailing
    }

    var isInput: Bool {
        self.nodeIO == .input
    }

    var body: some View {
        switch fieldValue {
        case .string(let string):
            switch self.nodeIO {
            case .input:
                CommonEditingView(inputString: string.string,
                                  id: coordinate,
                                  graph: graph,
                                  fieldIndex: fieldIndex,
                                  isCanvasItemSelected: isCanvasItemSelected,
                                  hasIncomingEdge: hasIncomingEdge,
                                  isLargeString: string.isLargeString,
                                  forPropertySidebar: forPropertySidebar,
                                  propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)
            case .output:
                // Leading alignment when multifield
                ReadOnlyValueEntry(value: string.string,
                                   alignment: outputAlignment,
                                   fontColor: STITCH_FONT_GRAY_COLOR)
            }

        case .number:
                FieldValueNumberView(graph: graph,
                                     fieldValue: fieldValue,
                                     fieldValueNumberType: .number,
                                     coordinate: coordinate,
                                     nodeIO: nodeIO,
                                     fieldCoordinate: fieldCoordinate,
                                     outputAlignment: outputAlignment,
                                     isCanvasItemSelected: isCanvasItemSelected,
                                     hasIncomingEdge: hasIncomingEdge,
                                     adjustmentBarSessionId: adjustmentBarSessionId,
                                     forPropertySidebar: forPropertySidebar,
                                     propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)
        
        case .layerDimension(let layerDimensionField):
            FieldValueNumberView(graph: graph,
                                 fieldValue: fieldValue,
                                 fieldValueNumberType: layerDimensionField.fieldValueNumberType,
                                 coordinate: coordinate,
                                 nodeIO: nodeIO,
                                 fieldCoordinate: fieldCoordinate,
                                 outputAlignment: outputAlignment,
                                 isCanvasItemSelected: isCanvasItemSelected,
                                 hasIncomingEdge: hasIncomingEdge,
                                 adjustmentBarSessionId: adjustmentBarSessionId,
                                 forPropertySidebar: forPropertySidebar,
                                 propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)

        case .bool(let bool):
            BoolCheckboxView(id: isInput ? self.coordinate : nil,
                             value: bool)

        case .dropdown(let choiceDisplay, let choices):
            if isInput {
                DropDownChoiceView(id: coordinate,
                                   choiceDisplay: choiceDisplay,
                                   choices: choices)
            }
            // Values that use dropdowns for their inputs use instead a display-only view for their outputs
            else {
                ReadOnlyValueEntry(value: choiceDisplay,
                                   alignment: outputAlignment,
                                   fontColor: STITCH_FONT_GRAY_COLOR)
            }

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
            .disabled(!isInput)

        case .anchorPopover(let anchor):
            AnchorPopoverView(input: coordinate,
                              selection: anchor)
            .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                   height: NODE_ROW_HEIGHT,
                   // Note: why are these reversed? Because we scaled the view down?
                   alignment: isInput ? .trailing : .leading)

        case .media(let media):
            MediaFieldValueView(rowObserver: rowObserver,
                                inputCoordinate: coordinate,
                                media: media,
                                nodeKind: nodeKind,
                                isInput: isInput,
                                fieldIndex: fieldIndex,
                                isNodeSelected: isCanvasItemSelected,
                                hasIncomingEdge: hasIncomingEdge)

        case .color(let color):
            HStack {
                if isInput {
                    // logInView("ValueEntry: color coordinate: \(coordinate)")
                    // logInView("ValueEntry: color input: color: \(color)")
                    ColorOrbValueButtonView(
                        nodeId: coordinate.nodeId,
                        id: coordinate,
                        currentColor: color,
                        hasIncomingEdge: hasIncomingEdge,
                        graph: graph)
                    //                        // will only be initialized once?
                    //                        colorState: color)
                } else {
                    StitchColorPickerOrb(chosenColor: color)
                }

                // MARK: asHexDisplay has expensive perf
                //                ReadOnlyValueEntry(
                //                    value: color.asHexDisplay,
                //                    alignment: isInput ? .leading : .trailing,
                //                    fontColor: STITCH_FONT_GRAY_COLOR)
            }

        case .pulse(let pulseTime):
            PulseValueButtonView(
                graph: graph,
                coordinate: coordinate,
                nodeIO: nodeIO,
                pulseTime: pulseTime,
                hasIncomingEdge: hasIncomingEdge)

        case .json(let json):
            if isInput {
                EditJSONEntry(coordinate: coordinate,
                              json: isButtonPressed ? json : nil,
                              isPressed: $isButtonPressed)
            } else {
                ValueJSONView(coordinate: coordinate,
                              json: isButtonPressed ? json : nil,
                              isPressed: $isButtonPressed)
            }

        case .readOnly(let string):
            ReadOnlyValueEntry(value: string,
                               alignment: isInput ? .leading : outputAlignment,
                               fontColor: STITCH_FONT_GRAY_COLOR)
        }
    }
}
