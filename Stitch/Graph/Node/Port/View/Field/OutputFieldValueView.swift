//
//  OutputValueView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/28/24.
//

import SwiftUI
import StitchSchemaKit

// fka `OutputValueView`
struct OutputFieldValueView: View {
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var outputField: OutputFieldViewModel
    
    // TODO: can be replaced by rowObserver.coordinate ? or tricky for group node outputs ?
    let rowViewModel: OutputNodeRowViewModel
    
    let rowObserver: OutputNodeRowObserver
    
    let node: NodeViewModel
        
    let isForLayerInspector: Bool
    let isFieldInMultifieldInput: Bool
    
    // Note: only the CanvasSketch and TextField layers have outputs (Image, Text respectively),
    // so the vast majority of outputs *cannot* be 'selected in the inspector'
    let isSelectedInspectorRow: Bool
    
    @Binding var isButtonPressed: Bool

    var fieldValue: FieldValue {
        outputField.fieldValue
    }

    // Which part of the port-value this value is for.
    // eg for a `.position3D` port-value:
    // field index 0 = x
    // field index 1 = y
    // field index 2 = z
    var fieldIndex: Int {
        outputField.fieldIndex
    }

    // Are the values left- or right-aligned?
    // Left-aligned when:
    // - input or,
    // - field within a multifield output
    var outputAlignment: Alignment {
        if isForLayerInspector {
            return .leading
        } else {
            return isFieldInMultifieldInput ? .leading : .trailing
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
            let displayName = graph.getNode(anchorEntityId ?? .init())?.getDisplayTitle() ?? AnchorDropdownChoice.noneDisplayName
            readOnlyView(displayName)
            
        // TODO: what are other "input only" types of FieldValues ? We should debug-crash on those if we
        case .layerGroupAlignment:
            EmptyView()
                .onAppear {
                    fatalErrorIfDebug()
                }
            
        case .media:
            MediaFieldLabelView(viewModel: outputField,
                                inputType: outputField.id.rowId.portType,
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
                                 canvasItemId: nil,
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
               let name = self.graph.getNode(layerNodeId.asNodeId)?
                .getDisplayTitle() {
                readOnlyView(name)
            } else {
                readOnlyView("None")
            }
            
        default:
            readOnlyView(self.fieldValue.stringValue)
        }
    }
    
    // TODO: implement "extended view on hover" for individual output fields
    @State var isHovering: Bool = false
        
    var hoveringAdjustment: CGFloat {
        isHovering ? .EXTENDED_FIELD_LENGTH : 0
    }

    var isCanvas: Bool {
        self.rowViewModel.id.graphItemType.isCanvas
    }
    
    @ViewBuilder func readOnlyView(_ displayName: String) -> some View {
        ReadOnlyValueEntry(value: displayName,
                           alignment: outputAlignment,
                           fontColor: STITCH_FONT_GRAY_COLOR,
                           isSelectedInspectorRow: isSelectedInspectorRow,
                           isForLayerInspector: isForLayerInspector,
                           isFieldInMultifieldInput: isFieldInMultifieldInput)
        
        .overlay(content: {
            
            if isHovering {
                StitchTextView(string: displayName,
                               fontColor: STITCH_FONT_GRAY_COLOR)
                    .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH + hoveringAdjustment,
                           alignment: .leading) // Always leading
                    .padding([.leading, .top, .bottom], 2)

                    .background {
                        // Why is `RoundedRectangle.fill` so much lighter than `RoundedRectangle.background` ?
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isHovering ? Color.EXTENDED_FIELD_BACKGROUND_COLOR : Color.clear)
                    }
                     .offset(x: hoveringAdjustment / 2)
            }
        })
        .onHover { isHovering in
            if isCanvas {
                self.isHovering = isHovering
            }
            
        }
    }
}
