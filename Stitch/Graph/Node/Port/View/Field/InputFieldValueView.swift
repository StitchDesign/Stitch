//
//  InputFieldValueView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/29/25.
//

import SwiftUI

// fka `InputValueView`
struct InputFieldValueView: View {
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var inputField: InputFieldViewModel
    
    @Bindable var propertySidebar: PropertySidebarObserver
    
    let node: NodeViewModel
        
    let rowId: NodeRowViewModelId
    let layerInputPort: LayerInputPort?
    
    // only needs to be the id?
    let canvasItemId: CanvasItemId?
    
    let rowObserver: InputNodeRowObserver

    let isForLayerInspector: Bool
    let isPackedLayerInputAlreadyOnCanvas: Bool
    let isFieldInMultifieldInput: Bool
    let isForFlyout: Bool
    let isSelectedInspectorRow: Bool
    
    var hasIncomingEdge: Bool
    var isForLayerGroup: Bool
    
    var isUpstreamValue: Bool {
        hasIncomingEdge
    }
    
    @Binding var isButtonPressed: Bool
    
    var fieldCoordinate: FieldCoordinate {
        self.inputField.id
    }
    
    var fieldValue: FieldValue {
        inputField.fieldValue
    }
    
    // Which part of the port-value this value is for.
    // eg for a `.position3D` port-value:
    // field index 0 = x
    // field index 1 = y
    // field index 2 = z
    var fieldIndex: Int {
        inputField.fieldIndex
    }
    
    var nodeKind: NodeKind {
        self.node.kind
    }
    
    // TODO: is `InputFieldValueView` ever used in the layer inspector now? ... vs flyout?
    @MainActor
    var hasHeterogenousValues: Bool {
        guard isForLayerInspector,
              let layerInputPort = layerInputPort else {
            return false
        }
        
        return propertySidebar.heterogenousFieldsMap?
            .get(layerInputPort)?
            .contains(self.fieldIndex) ?? false
    }
    
    var body: some View {
        switch fieldValue {
        case .string:
            CommonEditingView(document: document,
                                     inputField: inputField,
                                     layerInput: layerInputPort,
                                     choices: nil,
                                     // TODO: was not being used?
                                     isLargeString: false,
                                     isForLayerInspector: isForLayerInspector,
                                     isPackedLayerInputAlreadyOnCanvas: isPackedLayerInputAlreadyOnCanvas,
                                     hasHeterogenousValues: hasHeterogenousValues,
                                     isFieldInMultifieldInput: isFieldInMultifieldInput,
                                     isForFlyout: isForFlyout,
                                     isSelectedInspectorRow: isSelectedInspectorRow,
                                     nodeKind: nodeKind)
            
        case .number:
            FieldValueNumberView(graph: graph,
                                 document: document,
                                 rowObserver: rowObserver,
                                 inputField: inputField,
                                 fieldValueNumberType: .number,
                                 layerInput: layerInputPort,
                                 choices: nil,
                                 isForLayerInspector: isForLayerInspector,
                                 hasHeterogenousValues: hasHeterogenousValues,
                                 isPackedLayerInputAlreadyOnCanvas: isPackedLayerInputAlreadyOnCanvas,
                                 isFieldInMultifieldInput: isFieldInMultifieldInput,
                                 isForFlyout: isForFlyout,
                                 isSelectedInspectorRow: isSelectedInspectorRow,
                                 nodeKind: nodeKind)
            
        case .layerDimension(let layerDimensionField):
            FieldValueNumberView(graph: graph,
                                 document: document,
                                 rowObserver: rowObserver,
                                 inputField: inputField,
                                 fieldValueNumberType: layerDimensionField.fieldValueNumberType,
                                 layerInput: layerInputPort,
                                 choices: graph.getFilteredLayerDimensionChoices(node: node,
                                                                                 layerInputPort: layerInputPort,
                                                                                 activeIndex: document.activeIndex)
                                    .map(\.rawValue),
                                 isForLayerInspector: isForLayerInspector,
                                 hasHeterogenousValues: hasHeterogenousValues,
                                 isPackedLayerInputAlreadyOnCanvas: isPackedLayerInputAlreadyOnCanvas,
                                 isFieldInMultifieldInput: isFieldInMultifieldInput,
                                 isForFlyout: isForFlyout,
                                 isSelectedInspectorRow: isSelectedInspectorRow,
                                 isForLayerDimensionField: true,
                                 nodeKind: nodeKind)
            
        case .spacing:
            FieldValueNumberView(graph: graph,
                                 document: document,
                                 rowObserver: rowObserver,
                                 inputField: inputField,
                                 fieldValueNumberType: .number,
                                 layerInput: layerInputPort,
                                 choices: StitchSpacing.choices,
                                 isForLayerInspector: isForLayerInspector,
                                 hasHeterogenousValues: hasHeterogenousValues,
                                 isPackedLayerInputAlreadyOnCanvas: isPackedLayerInputAlreadyOnCanvas,
                                 isFieldInMultifieldInput: isFieldInMultifieldInput,
                                 isForFlyout: isForFlyout,
                                 isSelectedInspectorRow: isSelectedInspectorRow,
                                 isForSpacingField: true,
                                 nodeKind: nodeKind)
            
        case .bool(let bool):
            BoolCheckboxView(rowObserver: rowObserver,
                             graph: graph,
                             document: document,
                             value: bool,
                             isFieldInsideLayerInspector: isForLayerInspector,
                             isSelectedInspectorRow: isSelectedInspectorRow,
                             isMultiselectInspectorInputWithHeterogenousValues: hasHeterogenousValues)
            
        case .dropdown(let choiceDisplay, let choices):
            DropDownChoiceView(rowObserver: rowObserver,
                               graph: graph,
                               choiceDisplay: choiceDisplay,
                               choices: choices,
                               isFieldInsideLayerInspector: isForLayerInspector,
                               isSelectedInspectorRow: isSelectedInspectorRow,
                               hasHeterogenousValues: hasHeterogenousValues,
                               activeIndex: document.activeIndex)
            
        case .textFontDropdown(let stitchFont):
            StitchFontDropdown(rowObserver: rowObserver,
                               graph: graph,
                               stitchFont: stitchFont,
                               isFieldInsideLayerInspector: isForLayerInspector,
                               isSelectedInspectorRow: isSelectedInspectorRow,
                               hasHeterogenousValues: hasHeterogenousValues,
                               activeIndex: document.activeIndex)
            // need enough width for font design + font weight name
            .frame(minWidth: TEXT_FONT_DROPDOWN_WIDTH,
                   alignment: isForLayerInspector ? .trailing : .leading)
            
        case .layerDropdown(let layerId):
            LayerNamesDropDownChoiceView(
                graph: graph,
                visibleNodes: graph.visibleNodesViewModel,
                rowObserver: rowObserver,
                value: .assignedLayer(layerId),
                isFieldInsideLayerInspector: isForLayerInspector,
                isForPinTo: false,
                isSelectedInspectorRow: isSelectedInspectorRow,
                choices: graph
                    .layerDropdownChoices(isForNode: node.id,
                                          isForLayerGroup: false,
                                          isFieldInsideLayerInspector: isForLayerInspector,
                                          isForPinTo: false),
                hasHeterogenousValues: hasHeterogenousValues,
                activeIndex: document.activeIndex)
            
        case .anchorEntity(let anchorEntityId):
            AnchorEntitiesDropdownView(rowObserver: rowObserver,
                                       graph: graph,
                                       value: .anchorEntity(anchorEntityId),
                                       isFieldInsideLayerInspector: isForLayerInspector,
                                       activeIndex: document.activeIndex)
            
        case .layerGroupOrientationDropdown(let x):
            LayerGroupOrientationDropDownChoiceView(
                rowObserver: rowObserver,
                graph: graph,
                value: x,
                isFieldInsideLayerInspector: isForLayerInspector,
                hasHeterogenousValues: hasHeterogenousValues,
                activeIndex: document.activeIndex)
            
        case .layerGroupAlignment(let x):
            
            // If this field is for a LayerGroup layer node,
            // and the layer node has a VStack or HStack layerGroupOrientation,
            // then use this special picker:
            if nodeKind.getLayer == .group,
               let orientation = node.layerNode?.orientationPort.getActiveValue(activeIndex: document.activeIndex).getOrientation {
                
                switch orientation {
                case .vertical:
                    // logInView("InputValueView: vertical")
                    LayerGroupHorizontalAlignmentPickerFieldValueView(
                        rowObserver: rowObserver,
                        graph: graph,
                        value: x,
                        isFieldInsideLayerInspector: isForLayerInspector,
                        hasHeterogenousValues: hasHeterogenousValues,
                        activeIndex: document.activeIndex)
                case .horizontal:
                    // logInView("InputValueView: vertical")
                    LayerGroupVerticalAlignmentPickerFieldValueView(
                        rowObserver: rowObserver,
                        graph: graph,
                        activeIndex: document.activeIndex,
                        value: x,
                        isFieldInsideLayerInspector: isForLayerInspector,
                        hasHeterogenousValues: hasHeterogenousValues)
                    
                case .grid, .none:
                    // Should never happen
                    // logInView("InputValueView: grid or none")
                    EmptyView()
                    
                } // switch orientation
                
            } else {
                EmptyView()
            }
            
        case .textAlignmentPicker(let x):
            SpecialPickerFieldValueView(
                currentChoice: .textAlignment(x),
                rowObserver: rowObserver,
                graph: graph,
                value: .textAlignment(x),
                choices: LayerTextAlignment.choices,
                isFieldInsideLayerInspector: isForLayerInspector,
                hasHeterogenousValues: hasHeterogenousValues,
                activeIndex: document.activeIndex)
            
        case .textVerticalAlignmentPicker(let x):
            SpecialPickerFieldValueView(
                currentChoice: .textVerticalAlignment(x),
                rowObserver: rowObserver,
                graph: graph,
                value: .textVerticalAlignment(x),
                choices: LayerTextVerticalAlignment.choices,
                isFieldInsideLayerInspector: isForLayerInspector,
                hasHeterogenousValues: hasHeterogenousValues,
                activeIndex: document.activeIndex)
            
        case .textDecoration(let x):
            SpecialPickerFieldValueView(
                currentChoice: .textDecoration(x),
                rowObserver: rowObserver,
                graph: graph,
                value: .textDecoration(x),
                choices: LayerTextDecoration.choices,
                isFieldInsideLayerInspector: isForLayerInspector,
                hasHeterogenousValues: hasHeterogenousValues,
                activeIndex: document.activeIndex)
            
        case .pinTo(let pinToId):
            LayerNamesDropDownChoiceView(
                graph: graph,
                visibleNodes: graph.visibleNodesViewModel,
                rowObserver: rowObserver,
                value: .pinTo(pinToId),
                isFieldInsideLayerInspector: isForLayerInspector,
                isForPinTo: true,
                isSelectedInspectorRow: isSelectedInspectorRow,
                choices: graph
                    .layerDropdownChoices(isForNode: node.id,
                                          isForLayerGroup: isForLayerGroup,
                                          isFieldInsideLayerInspector: isForLayerInspector,
                                          isForPinTo: true),
                hasHeterogenousValues: hasHeterogenousValues,
                activeIndex: document.activeIndex)
            
        case .anchorPopover(let anchor):
            AnchorPopoverView(rowObserver: rowObserver,
                              graph: graph,
                              document: document,
                              selection: anchor,
                              isFieldInsideLayerInspector: isForLayerInspector,
                              isSelectedInspectorRow: isSelectedInspectorRow,
                              hasHeterogenousValues: hasHeterogenousValues)
            .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                   height: NODE_ROW_HEIGHT,
                   // Note: why are these reversed? Because we scaled the view down?
                   alignment: isForLayerInspector ? .leading : .trailing)
            .offset(x: isForLayerInspector ? -4 : 4)
            
            
        case .media(let media):
            if let mediaType = self.nodeKind.mediaType(coordinate: rowObserver.id) {
                MediaInputFieldValueView(
                    viewModel: inputField,
                    rowObserver: rowObserver,
                    node: node,
                    isUpstreamValue: isUpstreamValue,
                    media: media,
                    mediaName: media.name,
                    nodeKind: nodeKind,
                    isInput: true,
                    fieldIndex: fieldIndex,
                    isFieldInsideLayerInspector: isForLayerInspector,
                    isSelectedInspectorRow: isSelectedInspectorRow,
                    isMultiselectInspectorInputWithHeterogenousValues: hasHeterogenousValues,
                    mediaType: mediaType,
                    graph: graph,
                    document: document)
            } else {
                Color.clear
                    .onAppear {
                        fatalErrorIfDebug()
                    }
            }
            
        case .color(let color):
            ColorOrbValueButtonView(fieldViewModel: inputField,
                                    rowObserver: rowObserver,
                                    rowId: rowId,
                                    isForLayerInspector: isForLayerInspector,
                                    isForFlyout: isForFlyout,
                                    currentColor: color,
                                    hasIncomingEdge: hasIncomingEdge,
                                    graph: graph,
                                    isMultiselectInspectorInputWithHeterogenousValues: hasHeterogenousValues,
                                    activeIndex: document.activeIndex)
            
        case .pulse(let pulseTime):
            PulseValueButtonView(graph: graph,
                                 rowObserver: rowObserver,
                                 canvasItemId: canvasItemId,
                                 pulseTime: pulseTime,
                                 hasIncomingEdge: hasIncomingEdge)
            
        case .json(let json):
            EditJSONEntry(graph: graph,
                          coordinate: fieldCoordinate,
                          rowObserver: rowObserver,
                          json: isButtonPressed ? json : nil,
                          isSelectedInspectorRow: isSelectedInspectorRow,
                          activeIndex: document.activeIndex,
                          isPressed: $isButtonPressed)
            
            // TODO: is this relevant for multiselect?
            // Note: can an input EVER really have a 'read-only' value? Isn't this fieldValue case just for outputs?
        case .readOnly(let string):
            ReadOnlyValueEntry(value: string,
                               alignment: .leading,
                               fontColor: STITCH_FONT_GRAY_COLOR,
                               isSelectedInspectorRow: isSelectedInspectorRow,
                               isForLayerInspector: isForLayerInspector,
                               isFieldInMultifieldInput: isFieldInMultifieldInput)
        }
    }
}
