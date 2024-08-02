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

    let rowObserverId: NodeIOCoordinate
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
                       rowObserverId: rowObserverId,
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
            
            if forPropertySidebar,
               (rowViewModel.rowDelegate?.id.portType.keyPath?.usesFlyout ?? false) {
                Spacer()
            }
            
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
    
    let rowObserverId: NodeIOCoordinate
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
                              propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph, 
                              isForSpacingField: false)

        case .number:
            FieldValueNumberView(graph: graph,
                                 fieldViewModel: viewModel,
                                 fieldValue: fieldValue,
                                 fieldValueNumberType: .number,
                                 fieldCoordinate: fieldCoordinate,
                                 rowObserverCoordinate: rowObserverId,
                                 isCanvasItemSelected: isCanvasItemSelected,
                                 hasIncomingEdge: hasIncomingEdge, 
                                 choices: nil,
                                 adjustmentBarSessionId: adjustmentBarSessionId,
                                 forPropertySidebar: forPropertySidebar,
                                 propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)
                    
        case .layerDimension(let layerDimensionField):
            FieldValueNumberView(graph: graph,
                                 fieldViewModel: viewModel,
                                 fieldValue: fieldValue,
                                 fieldValueNumberType: layerDimensionField.fieldValueNumberType,
                                 fieldCoordinate: fieldCoordinate,
                                 rowObserverCoordinate: rowObserverId,
                                 isCanvasItemSelected: isCanvasItemSelected,
                                 hasIncomingEdge: hasIncomingEdge, 
                                 choices: LayerDimension.choices,
                                 adjustmentBarSessionId: adjustmentBarSessionId,
                                 forPropertySidebar: forPropertySidebar,
                                 propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)
            
        case .spacing(let spacing):
            FieldValueNumberView(graph: graph,
                                 fieldViewModel: viewModel,
                                 fieldValue: fieldValue,
                                 fieldValueNumberType: .number,
                                 fieldCoordinate: fieldCoordinate,
                                 rowObserverCoordinate: rowObserverId,
                                 isCanvasItemSelected: isCanvasItemSelected,
                                 hasIncomingEdge: hasIncomingEdge,
                                 choices: StitchSpacing.choices,
                                 adjustmentBarSessionId: adjustmentBarSessionId,
                                 forPropertySidebar: forPropertySidebar,
                                 propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                 isForSpacingField: true)
//            .frame(minWidth: SPACING_FIELD_WIDTH) // min width for "Between" dropdown of LayerGroup spacing

        case .bool(let bool):
            BoolCheckboxView(id: rowObserverId,
                             value: bool)

        case .dropdown(let choiceDisplay, let choices):
            DropDownChoiceView(id: rowObserverId,
                               choiceDisplay: choiceDisplay,
                               choices: choices)

        case .textFontDropdown(let stitchFont):
            StitchFontDropdown(input: rowObserverId,
                               stitchFont: stitchFont)
                // need enough width for font design + font weight name
                .frame(minWidth: TEXT_FONT_DROPDOWN_WIDTH,
                       alignment: .leading)

        case .layerDropdown(let layerId):
            // TODO: disable or use read-only view if this is an output ?
            LayerNamesDropDownChoiceView(graph: graph,
                                         id: rowObserverId,
                                         value: .assignedLayer(layerId))

        case .anchorPopover(let anchor):
            AnchorPopoverView(input: rowObserverId,
                              selection: anchor)
            .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                   height: NODE_ROW_HEIGHT,
                   // Note: why are these reversed? Because we scaled the view down?
                   alignment: .trailing)

        case .media(let media):
            MediaFieldValueView(inputCoordinate: rowObserverId,
                                isUpstreamValue: rowViewModel.rowDelegate?.upstreamOutputObserver.isDefined ?? false,
                                media: media,
                                nodeKind: nodeKind,
                                isInput: true,
                                fieldIndex: fieldIndex,
                                isNodeSelected: isCanvasItemSelected,
                                hasIncomingEdge: hasIncomingEdge)

        case .color(let color):
            ColorOrbValueButtonView(fieldViewModel: viewModel,
                                    nodeId: rowObserverId.nodeId,
                                    id: rowObserverId,
                                    currentColor: color,
                                    hasIncomingEdge: hasIncomingEdge,
                                    graph: graph)

        case .pulse(let pulseTime):
            PulseValueButtonView(graph: graph,
                                 inputPort: rowViewModel,
                                 stitchId: rowObserverId.nodeId,
                                 pulseTime: pulseTime,
                                 hasIncomingEdge: hasIncomingEdge)

        case .json(let json):
            EditJSONEntry(graph: graph,
                          coordinate: FieldCoordinate(rowId: rowViewModel.id,
                                                      fieldIndex: viewModel.fieldIndex), 
                          rowObserverCoordinate: rowObserverId,
                          json: isButtonPressed ? json : nil,
                          isPressed: $isButtonPressed)

        case .readOnly(let string):
            ReadOnlyValueEntry(value: string,
                               alignment: .leading,
                               fontColor: STITCH_FONT_GRAY_COLOR)
        }
    }
}
