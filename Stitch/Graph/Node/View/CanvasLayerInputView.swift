//
//  CanvasLayerInputView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/10/25.
//

import SwiftUI


// used `NodeTypeView`
// see `LayerNodeInputView`
struct CanvasLayerInputView: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var canvasNode: CanvasItemViewModel
    let layerInputObserver: LayerInputObserver
    let inputRowObserver: InputNodeRowObserver
    let inputRowViewModel: InputNodeRowViewModel

    var overallLabel: String {
        layerInputObserver
            .overallPortLabel(usesShortLabel: false,
                              node: node,
                              graph: graph)
    }
                
    @ViewBuilder @MainActor
    func valueEntryView(portViewModel: InputFieldViewModel,
                        isMultiField: Bool) -> CanvasLayerInputValueView {
        CanvasLayerInputValueView(graph: graph,
                                  graphUI: document,
                                  viewModel: portViewModel,
                                  canvasNode: canvasNode,
                                  node: node,
                                  layerInputObserver: layerInputObserver,
                                  inputRowObserver: inputRowObserver,
                                  inputRowViewModel: inputRowViewModel)
    }
    
    var port: LayerInputPort {
        layerInputObserver.port
    }
    
    
    var body: some View {
        HStack {
            
//            if layerInputObserver.port == .transform3D,
//               layerInputObserver.mode == .unpacked {
//                
//                // here, we're not iterating through all the fieldGroupings -- we probably have just one?
//                logInView("CanvasLayerInputView: port \(port)")
//                logInView("CanvasLayerInputView: inputRowObserver.id \(inputRowObserver.id)")
//                logInView("CanvasLayerInputView: inputRowViewModel.id \(inputRowViewModel.id)")
//                logInView("CanvasLayerInputView: inputRowViewModel.id \(inputRowViewModel.id)")
//                
//                
//                
//                // some possibilities: packed or unpacked
//                
//                // if packed, show overall label but nothing else
//                // if unpacked, show overall label + row label + individual field label
//                LabelDisplayView(label: overallLabel,
//                                 isLeftAligned: false,
//                                 fontColor: STITCH_FONT_GRAY_COLOR,
//                                 isSelectedInspectorRow: false)
//                .border(.green)
//                
//                // The individual row or port that we have ... will be for an unpacked
//                ForEach(inputRowViewModel.fieldValueTypes) { fieldGrouping in
//                    
//                    // When unpacked, groupLabel is nil here?
//                    
//                    Text("FieldGroup Label: \(fieldGrouping.groupLabel)")
//                        .border(.yellow)
//                    
//                    if port == .transform3D,
//                       layerInputObserver.mode == .unpacked,
//                        let rowLabel = inputRowObserver.id.keyPath?.getUnpackedPortType?.fieldGroupLabelForUnpacked3DTransformInput {
//                        Text("\(rowLabel)")
//                            .border(.pink)
//                    }
//                    
//                    // self.rowObserver.id.keyPath?.getUnpackedPortType?.fieldGroupLabelForUnpacked3DTransformInput
//                    
//                    ForEach(fieldGrouping.fieldObservers) { fieldObserver in
//                        Text("FieldObserver Label: \(fieldObserver.fieldLabel)")
//                            .border(.blue)
//                    }
//                }
//                
//            } else {
                
    //            if layerInputObserver.port.showsLabelForInspector {
    //
    //            }
    //
    //            if layerInputObserver.port != .transform3D,
    //               layerInputObserver.port != .size3D {
                    
                // The overall label
                    LabelDisplayView(label: overallLabel,
                                     isLeftAligned: false,
                                     fontColor: STITCH_FONT_GRAY_COLOR,
                                     isSelectedInspectorRow: false)
                    .border(.green)
    //            }
                
//                Spacer()
                
                if layerInputObserver.port == .transform3D,
                   layerInputObserver.mode == .unpacked,
                    let rowLabel = inputRowObserver.id.keyPath?.getUnpackedPortType?.fieldGroupLabelForUnpacked3DTransformInput {
                    
                    LabelDisplayView(label: rowLabel,
                                     isLeftAligned: false,
                                     fontColor: STITCH_FONT_GRAY_COLOR,
                                     isSelectedInspectorRow: false)
                }
                            
                CanvasLayerInputFieldsView(fieldValueTypes: inputRowViewModel.fieldValueTypes,
                                           layerInputObserver: layerInputObserver,
                                           valueEntryView: valueEntryView)
//            } // else
       
        }
    }
}

struct CanvasLayerInputValueView: View {
    
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    
    @Bindable var viewModel: InputFieldViewModel

    let canvasNode: CanvasItemViewModel
    let node: NodeViewModel
    let layerInputObserver: LayerInputObserver
    let inputRowObserver: InputNodeRowObserver
    let inputRowViewModel: InputNodeRowViewModel
    
    
    @State private var isButtonPressed = false
    
    // On the canvas, we always show overall label and individual field labels
    var body: some View {
        
        LabelDisplayView(label: self.viewModel.fieldLabel,
                         isLeftAligned: true,
                         fontColor: STITCH_FONT_GRAY_COLOR,
                         isSelectedInspectorRow: false)
        .border(.brown)
        
        valueDisplay
    }
    
    var hasIncomingEdge: Bool {
        inputRowObserver.upstreamOutputCoordinate.isDefined
    }
    
    @MainActor
    var valueDisplay: some View {
        InputFieldValueView(graph: graph,
                            graphUI: graphUI,
                            viewModel: viewModel,
                            propertySidebar: graph.propertySidebar,
                            node: node,
                            rowViewModel: inputRowViewModel,
                            canvasItem: canvasNode,
                            rowObserver: inputRowObserver,
                            
                            // TODO: MARCH 10: remove and pack up these inspector-specific params?
                            isCanvasItemSelected: false,
                            forPropertySidebar: false,
                            propertyIsAlreadyOnGraph: true, //false, // inspector only
                            isFieldInMultifieldInput: true, // inspector only
                            isForFlyout: false,
                            isSelectedInspectorRow: false,
                            
                            // Only for pulse button and color orb;
                            // Always false for inspector-rows
                            hasIncomingEdge: hasIncomingEdge,
                            isForLayerGroup: node.kind.getLayer == .group,
                            // This is same as `hasIncomingEdge` ? a check on whether rowDelegate has a defined upstream output (coordinate vs observer should not matter?)
                            isUpstreamValue: hasIncomingEdge,
                            isButtonPressed: $isButtonPressed)
        .font(STITCH_FONT)
        // Monospacing prevents jittery node widths if values change on graphstep
        .monospacedDigit()
        .lineLimit(1)
    }
    
}

struct CanvasLayerInputFieldsView<ValueEntry>: View where ValueEntry: View {
    typealias ValueEntryViewBuilder = (InputFieldViewModel, Bool) -> ValueEntry
    
    let fieldValueTypes: [FieldGroupTypeData<InputNodeRowViewModel.FieldType>]
    let layerInputObserver: LayerInputObserver
    @ViewBuilder var valueEntryView: ValueEntryViewBuilder
    
    
    var isMultifield: Bool {
        layerInputObserver.usesMultifields || fieldValueTypes.count > 1
    }
    
    var blockedFields: LayerPortTypeSet? {
        layerInputObserver.blockedFields
    }
    
    var body: some View {
        ForEach(fieldValueTypes) { (fieldGrouping: FieldGroupTypeData<InputFieldViewModel>) in
            
            let multipleFieldsPerGroup = fieldGrouping.fieldObservers.count > 1
            
            //            // Note: "multifield" is more complicated for layer inputs, since `fieldObservers.count` is now inaccurate for an unpacked port
            let _isMultifield = isMultifield || multipleFieldsPerGroup
            
            if !self.isAllFieldsBlockedOut(fieldGroupViewModel: fieldGrouping) {
                
                // `NodeFieldsView` displays fieldGrouping's label,
                NodeFieldsView(fieldGroupViewModel: fieldGrouping,
                               valueEntryView: valueEntryView) {
                    
                    HStack {
                        ForEach(fieldGrouping.fieldObservers) { fieldViewModel in
                            let isBlocked = self.blockedFields.map { fieldViewModel.isBlocked($0) } ?? false
                            if !isBlocked {
                                self.valueEntryView(fieldViewModel,
                                                    _isMultifield)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func isAllFieldsBlockedOut(fieldGroupViewModel: FieldGroupTypeData<InputFieldViewModel>) -> Bool {
        if let blockedFields = blockedFields {
            return fieldGroupViewModel.fieldObservers.allSatisfy {
                $0.isBlocked(blockedFields)
            }
        }
        return false
    }
}
