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
    @Bindable var document: StitchDocumentViewModel
    @Bindable var viewModel: OutputFieldViewModel

    let rowViewModel: OutputNodeRowViewModel
    let rowObserver: OutputNodeRowObserver
    let node: NodeViewModel
    let canvasItem: CanvasItemViewModel?
    let isMultiField: Bool
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
                        document: document,
                        viewModel: viewModel,
                        rowViewModel: rowViewModel,
                        rowObserver: rowObserver,
                        node: node,
                        canvasItem: canvasItem,
                        isMultiField: isMultiField,
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
    @Bindable var document: StitchDocumentViewModel
    @Bindable var viewModel: OutputFieldViewModel
    
    let rowViewModel: OutputNodeRowViewModel
    let rowObserver: OutputNodeRowObserver
    let node: NodeViewModel
    let canvasItem: CanvasItemViewModel?
    let isMultiField: Bool
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
        switch fieldValue {
        case .bool(let bool):
            BoolCheckboxView(rowObserver: nil,
                             graph: graph,
                             document: document,
                             value: bool,
                             isFieldInsideLayerInspector: false,
                             isSelectedInspectorRow: isSelectedInspectorRow,
                             isMultiselectInspectorInputWithHeterogenousValues: false)
            
        case .dropdown(let choiceDisplay, _):
            // Values that use dropdowns for their inputs use instead a display-only view for their outputs
            readOnlyView(choiceDisplay)
            
        case .anchorEntity(let anchorEntityId):
            let displayName = graph.getNodeViewModel(anchorEntityId ?? .init())?.getDisplayTitle() ?? AnchorDropdownChoice.noneDisplayName
            readOnlyView(displayName)
            
        case .layerGroupAlignment:
            EmptyView() // Can't really happen
            
        case .media:
            MediaFieldLabelView(viewModel: viewModel,
                                inputType: viewModel.id.rowId.portType,
                                node: node,
                                graph: graph,
                                document: document,
                                coordinate: rowObserver.id,
                                isInput: false,
                                fieldIndex: fieldIndex,
                                isMultiselectInspectorInputWithHeterogenousValues: false)
            
        case .color(let color):
            StitchColorPickerOrb(chosenColor: color,
                                 isMultiselectInspectorInputWithHeterogenousValues: false)
            
        case .pulse(let pulseTime):
            PulseValueButtonView(graph: graph,
                                 rowObserver: nil,
                                 canvasItem: canvasItem,
                                 pulseTime: pulseTime,
                                 hasIncomingEdge: false)
            
        case .json(let json):
            ValueJSONView(coordinate: rowViewModel.id.asNodeIOCoordinate,
                          json: isButtonPressed ? json : nil,
                          isSelectedInspectorRow: isSelectedInspectorRow,
                          isPressed: $isButtonPressed)
            
        case .anchorPopover(let anchor):
            AnchorPopoverView(rowObserver: rowObserver,
                              graph: graph,
                              document: document,
                              selection: anchor,
                              isFieldInsideLayerInspector: false,
                              isSelectedInspectorRow: isSelectedInspectorRow,
                              hasHeterogenousValues: false)
            .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                   height: NODE_ROW_HEIGHT,
                   // Note: why are these reversed? Because we scaled the view down?
                   alignment: .leading)
            .offset(x: -4)
            .disabled(true)
            
        case .layerDropdown(let layerNodeId):
            // Cannot use default readOnly logic due to logic needed to fetch selected node
            if let layerNodeId = layerNodeId,
               let name = self.graph.getNodeViewModel(layerNodeId.asNodeId)?
                .getDisplayTitle() {
                readOnlyView(name)
            } else {
                readOnlyView("None")
            }
            
        default:
            readOnlyView(self.fieldValue.stringValue)
        }
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
