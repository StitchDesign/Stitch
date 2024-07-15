//
//  ValueEntry.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/14/22.
//

import SwiftUI
import StitchSchemaKit

struct InputValueEntry: View {

    @Bindable var graph: GraphState
    @Bindable var rowViewModel: InputNodeRowViewModel
    @Bindable var viewModel: InputFieldViewModel

    let nodeKind: NodeKind
    let isCanvasItemSelected: Bool
    let hasIncomingEdge: Bool
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
                         isLeftAligned: true,
                         // Gray color for multi-field
//                         fontColor: isMultiField ? STITCH_FONT_GRAY_COLOR : Color(.titleFont))
                         // Seems like every input label is gray now?
                         fontColor: STITCH_FONT_GRAY_COLOR)
    }

    var valueDisplay: some View {
        InputValueView(graph: graph,
                       rowViewModel: rowViewModel,
                       viewModel: viewModel,
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

struct InputValueView: View {
    @Bindable var graph: GraphState
    @Bindable var rowViewModel: InputNodeRowViewModel
    @Bindable var viewModel: InputFieldViewModel
    
    let nodeKind: NodeKind
    let isCanvasItemSelected: Bool
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool
    
    @Binding var isButtonPressed: Bool

    var fieldCoordinate: FieldCoordinate {
        self.viewModel.id
    }
    
    var hasIncomingEdge: Bool {
        self.rowViewModel.rowDelegate?.upstreamOutputCoordinate != nil
    }
    
    var fieldValue: FieldValue {
        viewModel.fieldValue
    }

    @MainActor var adjustmentBarSessionId: AdjustmentBarSessionId {
        self.graph.graphUI.adjustmentBarSessionId
    }
    
    var coordinate: NodeIOCoordinate {
        .init(portType: self.rowViewModel.portType,
              nodeId: self.rowViewModel.id.nodeId)
    }

    // Which part of the port-value this value is for.
    // eg for a `.position3D` port-value:
    // field index 0 = x
    // field index 1 = y
    // field index 2 = z
    var fieldIndex: Int {
        viewModel.fieldIndex
    }

    var body: some View {
        switch fieldValue {
        case .string(let string):
            CommonEditingView(inputField: viewModel,
                              inputString: string.string,
                              graph: graph,
                              fieldIndex: fieldIndex,
                              isCanvasItemSelected: isCanvasItemSelected,
                              hasIncomingEdge: hasIncomingEdge,
                              isLargeString: string.isLargeString,
                              forPropertySidebar: forPropertySidebar,
                              propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)

        case .number:
            FieldValueNumberView(graph: graph,
                                 fieldValue: fieldValue,
                                 fieldValueNumberType: .number,
                                 fieldCoordinate: fieldCoordinate,
                                 isCanvasItemSelected: isCanvasItemSelected,
                                 hasIncomingEdge: hasIncomingEdge,
                                 adjustmentBarSessionId: adjustmentBarSessionId,
                                 forPropertySidebar: forPropertySidebar,
                                 propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)
        
        case .layerDimension(let layerDimensionField):
            FieldValueNumberView(graph: graph,
                                 fieldValue: fieldValue,
                                 fieldValueNumberType: layerDimensionField.fieldValueNumberType,
                                 fieldCoordinate: fieldCoordinate,
                                 isCanvasItemSelected: isCanvasItemSelected,
                                 hasIncomingEdge: hasIncomingEdge,
                                 adjustmentBarSessionId: adjustmentBarSessionId,
                                 forPropertySidebar: forPropertySidebar,
                                 propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)

        case .bool(let bool):
            BoolCheckboxView(id: self.coordinate,
                             value: bool)

        case .dropdown(let choiceDisplay, let choices):
            DropDownChoiceView(id: coordinate,
                               choiceDisplay: choiceDisplay,
                               choices: choices)

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

        case .anchorPopover(let anchor):
            AnchorPopoverView(input: coordinate,
                              selection: anchor)
            .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                   height: NODE_ROW_HEIGHT,
                   // Note: why are these reversed? Because we scaled the view down?
                   alignment: .trailing)

        case .media(let media):
            MediaFieldValueView(rowViewModel: rowViewModel,
                                inputCoordinate: coordinate,
                                isUpstreamValue: rowViewModel.rowDelegate?.upstreamOutputObserver.isDefined ?? false,
                                media: media,
                                nodeKind: nodeKind,
                                isInput: true,
                                fieldIndex: fieldIndex,
                                isNodeSelected: isCanvasItemSelected,
                                hasIncomingEdge: hasIncomingEdge)

        case .color(let color):
            ColorOrbValueButtonView(
                nodeId: coordinate.nodeId,
                id: coordinate,
                currentColor: color,
                hasIncomingEdge: hasIncomingEdge,
                graph: graph)

        case .pulse(let pulseTime):
            PulseValueButtonView(
                graph: graph,
                coordinate: coordinate,
                nodeIO: .input,
                pulseTime: pulseTime,
                hasIncomingEdge: hasIncomingEdge)

        case .json(let json):
            EditJSONEntry(coordinate: viewModel.coordinate,
                          json: isButtonPressed ? json : nil,
                          isPressed: $isButtonPressed)

        case .readOnly(let string):
            ReadOnlyValueEntry(value: string,
                               alignment: .leading,
                               fontColor: STITCH_FONT_GRAY_COLOR)
        }
    }
}
