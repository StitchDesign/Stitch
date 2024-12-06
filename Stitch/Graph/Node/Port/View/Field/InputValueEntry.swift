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
    
    @Bindable var viewModel: InputFieldViewModel
    
    let layerInputObserver: LayerInputObserver?
    
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
    
    var individualFieldLabel: String {
        self.viewModel.fieldLabel
    }
    
    // TODO: support derived field-labels
    // TODO: perf-impact? is this running all the time?
    @MainActor
    var useIndividualFieldLabel: Bool {
        if forPropertySidebar,
            isFieldInMultifieldInput,
            !isForFlyout,
           // Do not use labels on the fields of a padding-type input
            (layerInputObserver?.activeValue.getPadding.isDefined ?? false) {
            return false
        }
        
        return true
    }
    
    var labelDisplay: some View {
        LabelDisplayView(label: individualFieldLabel,
                         isLeftAligned: true,
                         fontColor: STITCH_FONT_GRAY_COLOR,
                         isSelectedInspectorRow: isSelectedInspectorRow)
    }

    @MainActor
    var valueDisplay: some View {
        InputValueView(graph: graph,
                       viewModel: viewModel,
                       layerInputObserver: layerInputObserver,
                       rowObserverId: rowObserverId,
                       nodeKind: nodeKind,
                       isCanvasItemSelected: isCanvasItemSelected,
                       forPropertySidebar: forPropertySidebar,
                       propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                       isFieldInMultifieldInput: isFieldInMultifieldInput,
                       isForFlyout: isForFlyout,
                       isSelectedInspectorRow: isSelectedInspectorRow,
                       
                       // Only for pulse button and color orb;
                       // Always false for inspector-rows
                       hasIncomingEdge: hasIncomingEdge,
                       
                       isForLayerGroup: nodeKind.getLayer == .group,
                       
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
            if self.useIndividualFieldLabel {
                labelDisplay
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

struct InputValueView: View {
    @Bindable var graph: GraphState
    @Bindable var viewModel: InputFieldViewModel
    let layerInputObserver: LayerInputObserver?
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
        NodeLayout(observer: viewModel,
                   existingCache: viewModel.viewCache) {
            switch fieldValue {
            case .string:
                CommonEditingViewWrapper(graph: graph,
                                         fieldViewModel: viewModel,
                                         layerInputObserver: layerInputObserver,
                                         fieldValue: fieldValue,
                                         fieldCoordinate: fieldCoordinate,
                                         isCanvasItemSelected: isCanvasItemSelected,
                                         choices: nil,
                                         adjustmentBarSessionId: adjustmentBarSessionId,
                                         forPropertySidebar: forPropertySidebar,
                                         propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                         isFieldInMultifieldInput: isFieldInMultifieldInput,
                                         isForFlyout: isForFlyout,
                                         isSelectedInspectorRow: isSelectedInspectorRow,
                                         nodeKind: nodeKind)
                
            case .number:
                FieldValueNumberView(graph: graph,
                                     fieldViewModel: viewModel,
                                     layerInputObserver: layerInputObserver,
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
                                     isSelectedInspectorRow: isSelectedInspectorRow,
                                     nodeKind: nodeKind)
                
            case .layerDimension(let layerDimensionField):
                FieldValueNumberView(graph: graph,
                                     fieldViewModel: viewModel,
                                     layerInputObserver: layerInputObserver,
                                     fieldValue: fieldValue,
                                     fieldValueNumberType: layerDimensionField.fieldValueNumberType,
                                     fieldCoordinate: fieldCoordinate,
                                     rowObserverCoordinate: rowObserverId,
                                     isCanvasItemSelected: isCanvasItemSelected,
                                     // TODO: perf implications? split into separate view?
                                     choices: graph.getFilteredLayerDimensionChoices(nodeId: fieldCoordinate.rowId.nodeId,
                                                                                     nodeKind: nodeKind,
                                                                                     layerInputObserver: layerInputObserver)
                                        .map(\.rawValue),
                                     adjustmentBarSessionId: adjustmentBarSessionId,
                                     forPropertySidebar: forPropertySidebar,
                                     propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                     isFieldInMultifieldInput: isFieldInMultifieldInput,
                                     isForFlyout: isForFlyout,
                                     isSelectedInspectorRow: isSelectedInspectorRow,
                                     isForLayerDimensionField: true,
                                     nodeKind: nodeKind)
                
            case .spacing:
                FieldValueNumberView(graph: graph,
                                     fieldViewModel: viewModel,
                                     layerInputObserver: layerInputObserver,
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
                                     isForSpacingField: true,
                                     nodeKind: nodeKind)
                
            case .bool(let bool):
                BoolCheckboxView(id: rowObserverId,
                                 layerInputObserver: layerInputObserver,
                                 value: bool,
                                 isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                 isSelectedInspectorRow: isSelectedInspectorRow)
                
            case .dropdown(let choiceDisplay, let choices):
                DropDownChoiceView(id: rowObserverId,
                                   layerInputObserver: layerInputObserver,
                                   graph: graph,
                                   choiceDisplay: choiceDisplay,
                                   choices: choices,
                                   isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                   isSelectedInspectorRow: isSelectedInspectorRow)
                
            case .textFontDropdown(let stitchFont):
                StitchFontDropdown(input: rowObserverId,
                                   stitchFont: stitchFont, 
                                   layerInputObserver: layerInputObserver,
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
                    layerInputObserver: layerInputObserver,
                    isFieldInsideLayerInspector: viewModel.isFieldInsideLayerInspector,
                    isForPinTo: false,
                    isSelectedInspectorRow: isSelectedInspectorRow,
                    choices: graph
                        .layerDropdownChoices(isForNode: rowObserverId.nodeId,
                                              isForLayerGroup: false,
                                              isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                              isForPinTo: false))
                
            case .layerGroupOrientationDropdown(let x):
                LayerGroupOrientationDropDownChoiceView(
                    id: rowObserverId,
                    value: x,
                    layerInputObserver: layerInputObserver,
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector)
                
            case .pinTo(let pinToId):
                LayerNamesDropDownChoiceView(
                    graph: graph,
                    id: rowObserverId,
                    value: .pinTo(pinToId),
                    layerInputObserver: layerInputObserver,
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                    isForPinTo: true,
                    isSelectedInspectorRow: isSelectedInspectorRow,
                    choices: graph
                        .layerDropdownChoices(isForNode: rowObserverId.nodeId,
                                              isForLayerGroup: isForLayerGroup,
                                              isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                              isForPinTo: true))
                
            case .anchorPopover(let anchor):
                AnchorPopoverView(input: rowObserverId,
                                  selection: anchor,
                                  layerInputObserver: layerInputObserver,
                                  isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                  isSelectedInspectorRow: isSelectedInspectorRow)
                .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                       height: NODE_ROW_HEIGHT,
                       // Note: why are these reversed? Because we scaled the view down?
                       alignment: forPropertySidebar ? .leading : .trailing)
                .offset(x: forPropertySidebar ? -4 : 4)
                
                
            case .media(let media):
                MediaFieldValueView(inputCoordinate: rowObserverId,
                                    layerInputObserver: layerInputObserver,
                                    isUpstreamValue: isUpstreamValue,
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
                                        layerInputObserver: layerInputObserver,
                                        isForFlyout: isForFlyout,
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
}
