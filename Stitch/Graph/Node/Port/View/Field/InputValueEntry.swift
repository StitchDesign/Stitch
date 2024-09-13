//
//  ValueEntry.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/14/22.
//

import SwiftUI
import StitchSchemaKit

// For an individual field
struct InputValueEntry: View {

    @Bindable var graph: GraphState
    
    // Can no longer accept an input row
//    @Bindable var rowViewModel: InputNodeRowViewModel
    
//    let fieldGroupType: FieldGroupType
    
    @Bindable var viewModel: InputFieldViewModel
    
    // Always and only for inspector-rows, not flyout-rows ?
    let inputLayerNodeRowData: LayerInputObserver?
    
    let rowObserverId: NodeIOCoordinate
    let nodeKind: NodeKind
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
    
    // Label for an individual field ?
    var label: String {
//        "Pain"
        
//        if forPropertySidebar, isFieldInMultifieldInput {
//            // If this is for an inspector- or flyout-row,
//            // and is a multifield, we can't rely on just the fieldLabel,
//            // since the input maybe have been broken
////            return 
//            
////            let fieldGroupType: FieldGroupType = .xY
//            
////            let labels = fieldGroupType.labels
////            let label = labels[safe: viewModel.fieldIndex] ?? "CAT"
////            return label
//            
//            // What is the
//            return self.viewModel.fieldLabel
//            
//        } else {
//            return self.viewModel.fieldLabel
//        }
        
        // Good for most cases but not accurate when we have a property
        return self.viewModel.fieldLabel
    }
    
    // TODO: support derived field-labels
    // TODO: perf-impact? is this running all the time?
    @MainActor
    var useIndividualFieldLabel: Bool {
        if forPropertySidebar,
            isFieldInMultifieldInput,
            !isForFlyout,
           // Do not use labels on the fields of a padding-type input
            (inputLayerNodeRowData?.activeValue.getPadding.isDefined ?? false) {
            return false
        }
        
        return true
    }
    
    var labelDisplay: some View {
        LabelDisplayView(label: label,
                         isLeftAligned: true,
                         // Gray color for multi-field
//                         fontColor: isMultiField ? STITCH_FONT_GRAY_COLOR : Color(.titleFont))
                         // Seems like every input label is gray now?
                         fontColor: STITCH_FONT_GRAY_COLOR,
                         isSelectedInspectorRow: isSelectedInspectorRow)
    }

    @MainActor
    var valueDisplay: some View {
        InputValueView(graph: graph,
//                       rowViewModel: rowViewModel,
                       viewModel: viewModel,
                       inputLayerNodeRowData: inputLayerNodeRowData,
                       rowObserverId: rowObserverId,
                       nodeKind: nodeKind,
                       isCanvasItemSelected: isCanvasItemSelected,
                       forPropertySidebar: forPropertySidebar,
                       propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                       isFieldInMultifieldInput: isFieldInMultifieldInput,
                       isForFlyout: isForFlyout,
                       isSelectedInspectorRow: isSelectedInspectorRow,
                       
                       // Always false for inspector-rows
                       // ... only for pulse button and color orb
                       hasIncomingEdge: hasIncomingEdge, // rowViewModel.rowDelegate?.upstreamOutputCoordinate != nil,
                       
                       isForLayerGroup: nodeKind.getLayer == .group,
                       
                       // This is same as `hasIncomingEdge` ? a check on whether rowDelegate has a defined upstream output (coordinate vs observer should not matter?)
                       isUpstreamValue: hasIncomingEdge, // rowViewModel.rowDelegate?.upstreamOutputObserver.isDefined ?? false,
                       
                       isButtonPressed: $isButtonPressed)
            .font(STITCH_FONT)
            // Monospacing prevents jittery node widths if values change on graphstep
            .monospacedDigit()
            .lineLimit(1)
    }

    var body: some View {
        HStack(spacing: NODE_COMMON_SPACING) {
            if self.useIndividualFieldLabel {
                labelDisplay
            }
            
            //                .border(.blue)
            
            if forPropertySidebar,
               isForFlyout,
               isFieldInMultifieldInput {
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
    @Bindable var viewModel: InputFieldViewModel
    let inputLayerNodeRowData: LayerInputObserver?
    let rowObserverId: NodeIOCoordinate
    let nodeKind: NodeKind
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

    @MainActor var adjustmentBarSessionId: AdjustmentBarSessionId {
        self.graph.graphUI.adjustmentBarSessionId
    }

    var isFieldInsideLayerInspector: Bool {
        viewModel.isFieldInsideLayerInspector
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
        case .string:
            CommonEditingViewWrapper(graph: graph,
                                     fieldViewModel: viewModel,
                                     inputLayerNodeRowData: inputLayerNodeRowData,
                                     fieldValue: fieldValue,
                                     fieldCoordinate: fieldCoordinate,
                                     isCanvasItemSelected: isCanvasItemSelected,
                                     choices: nil,
                                     adjustmentBarSessionId: adjustmentBarSessionId,
                                     forPropertySidebar: forPropertySidebar,
                                     propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                     isFieldInMultifieldInput: isFieldInMultifieldInput,
                                     isForFlyout: isForFlyout,
                                     isSelectedInspectorRow: isSelectedInspectorRow)

        case .number:
            FieldValueNumberView(graph: graph,
                                 fieldViewModel: viewModel,
                                 inputLayerNodeRowData: inputLayerNodeRowData,
                                 fieldValue: fieldValue,
                                 fieldValueNumberType: .number,
                                 fieldCoordinate: fieldCoordinate,
                                 rowObserverCoordinate: rowObserverId,
                                 isCanvasItemSelected: isCanvasItemSelected,
                                 choices: nil,
                                 adjustmentBarSessionId: adjustmentBarSessionId,
                                 forPropertySidebar: forPropertySidebar,
                                 propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                 isFieldInMultifieldInput: isFieldInMultifieldInput,
                                 isForFlyout: isForFlyout,
                                 isSelectedInspectorRow: isSelectedInspectorRow)
                    
        case .layerDimension(let layerDimensionField):
            FieldValueNumberView(graph: graph,
                                 fieldViewModel: viewModel,
                                 inputLayerNodeRowData: inputLayerNodeRowData,
                                 fieldValue: fieldValue,
                                 fieldValueNumberType: layerDimensionField.fieldValueNumberType,
                                 fieldCoordinate: fieldCoordinate,
                                 rowObserverCoordinate: rowObserverId,
                                 isCanvasItemSelected: isCanvasItemSelected,
                                 choices: LayerDimension.choices,
                                 adjustmentBarSessionId: adjustmentBarSessionId,
                                 forPropertySidebar: forPropertySidebar,
                                 propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                 isFieldInMultifieldInput: isFieldInMultifieldInput,
                                 isForFlyout: isForFlyout,
                                 isSelectedInspectorRow: isSelectedInspectorRow)
            
        case .spacing:
            FieldValueNumberView(graph: graph,
                                 fieldViewModel: viewModel,
                                 inputLayerNodeRowData: inputLayerNodeRowData,
                                 fieldValue: fieldValue,
                                 fieldValueNumberType: .number,
                                 fieldCoordinate: fieldCoordinate,
                                 rowObserverCoordinate: rowObserverId,
                                 isCanvasItemSelected: isCanvasItemSelected,
                                 choices: StitchSpacing.choices,
                                 adjustmentBarSessionId: adjustmentBarSessionId,
                                 forPropertySidebar: forPropertySidebar,
                                 propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                 isFieldInMultifieldInput: isFieldInMultifieldInput,
                                 isForFlyout: isForFlyout,
                                 isSelectedInspectorRow: isSelectedInspectorRow,
                                 isForSpacingField: true)

        case .bool(let bool):
            BoolCheckboxView(id: rowObserverId, 
                             inputLayerNodeRowData: inputLayerNodeRowData,
                             value: bool,
                             isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                             isSelectedInspectorRow: isSelectedInspectorRow)

        case .dropdown(let choiceDisplay, let choices):
            DropDownChoiceView(id: rowObserverId,
                               inputLayerNodeRowData: inputLayerNodeRowData,
                               graph: graph,
                               choiceDisplay: choiceDisplay,
                               choices: choices,
                               isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                               isSelectedInspectorRow: isSelectedInspectorRow)

        case .textFontDropdown(let stitchFont):
            StitchFontDropdown(input: rowObserverId,
                               stitchFont: stitchFont, 
                               inputLayerNodeRowData: inputLayerNodeRowData,
                               isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                               propertyIsSelected: isSelectedInspectorRow)
                // need enough width for font design + font weight name
                .frame(minWidth: TEXT_FONT_DROPDOWN_WIDTH,
                       alignment: .leading)

        case .layerDropdown(let layerId):
            // TODO: disable or use read-only view if this is an output ?
            LayerNamesDropDownChoiceView(
                graph: graph,
                id: rowObserverId,
                value: .assignedLayer(layerId), 
                inputLayerNodeRowData: inputLayerNodeRowData,
                isFieldInsideLayerInspector: viewModel.isFieldInsideLayerInspector,
                isForPinTo: false,
                isSelectedInspectorRow: isSelectedInspectorRow,
                choices: graph.layerDropdownChoices(isForNode: rowObserverId.nodeId,
                                                    isForLayerGroup: false, 
                                                    isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                                    isForPinTo: false))
        
        case .pinTo(let pinToId):
            LayerNamesDropDownChoiceView(
                           graph: graph,
                           id: rowObserverId,
                           value: .pinTo(pinToId),
                           inputLayerNodeRowData: inputLayerNodeRowData,
                           isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                           isForPinTo: true,
                           isSelectedInspectorRow: isSelectedInspectorRow,
                           choices: graph.layerDropdownChoices(isForNode: rowObserverId.nodeId,
                                                               isForLayerGroup: isForLayerGroup,
                                                               isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                                               isForPinTo: true))

        case .anchorPopover(let anchor):
            AnchorPopoverView(input: rowObserverId,
                              selection: anchor,
                              inputLayerNodeRowData: inputLayerNodeRowData,
                              isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                              isSelectedInspectorRow: isSelectedInspectorRow)
            .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                   height: NODE_ROW_HEIGHT,
                   // Note: why are these reversed? Because we scaled the view down?
                   alignment: forPropertySidebar ? .leading : .trailing)
            .offset(x: forPropertySidebar ? -4 : 4)
                

        case .media(let media):
            MediaFieldValueView(inputCoordinate: rowObserverId, 
                                inputLayerNodeRowData: inputLayerNodeRowData,
                                isUpstreamValue: isUpstreamValue, // rowViewModel.rowDelegate?.upstreamOutputObserver.isDefined ?? false,
                                media: media,
                                nodeKind: nodeKind,
                                isInput: true,
                                fieldIndex: fieldIndex,
                                isNodeSelected: isCanvasItemSelected,
                                isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                isSelectedInspectorRow: isSelectedInspectorRow,
                                graph: graph)

        case .color(let color):
            ColorOrbValueButtonView(fieldViewModel: viewModel, 
                                    inputLayerNodeRowData: inputLayerNodeRowData,
                                    nodeId: rowObserverId.nodeId,
                                    id: rowObserverId,
                                    currentColor: color,
                                    hasIncomingEdge: hasIncomingEdge,
                                    graph: graph)

        case .pulse(let pulseTime):
            PulseValueButtonView(inputCoordinate: rowObserverId,
                                 nodeId: rowObserverId.nodeId,
                                 pulseTime: pulseTime,
                                 hasIncomingEdge: hasIncomingEdge)

        case .json(let json):
            EditJSONEntry(graph: graph,
                          coordinate: fieldCoordinate,
                          //FieldCoordinate(rowId: rowViewModel.id,
                          //               fieldIndex: viewModel.fieldIndex),
                          rowObserverCoordinate: rowObserverId,
                          json: isButtonPressed ? json : nil,
                          isSelectedInspectorRow: isSelectedInspectorRow,
                          isPressed: $isButtonPressed)

        // TODO: is this relevant for multiselect?
        case .readOnly(let string):
            ReadOnlyValueEntry(value: string,
                               alignment: .leading,
                               fontColor: STITCH_FONT_GRAY_COLOR, 
                               isSelectedInspectorRow: isSelectedInspectorRow)
        }
    }
}
