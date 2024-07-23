//
//  NodeInputView.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

struct NodeInputOutputView: View {
    @State private var showPopover: Bool = false
    
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var rowData: NodeRowObserver
    let coordinateType: PortViewType
    let nodeKind: NodeKind
    let isCanvasItemSelected: Bool
    let adjustmentBarSessionId: AdjustmentBarSessionId

    var forPropertySidebar: Bool = false
    var propertyIsSelected: Bool = false
    var propertyIsAlreadyOnGraph: Bool = false
    
    @MainActor
    private var graphUI: GraphUIState {
        self.graph.graphUI
    }

    @MainActor
    var label: String {
        self.rowData.label(forPropertySidebar)
    }

    var nodeId: NodeId {
        self.rowData.id.nodeId
    }
    
    var isSplitter: Bool {
        self.nodeKind == .patch(.splitter)
    }

    var activeValue: PortValue {
        self.rowData.activeValue
    }
    
    var isLayer: Bool {
        self.nodeKind.isLayer
    }

    var body: some View {
        let coordinate = rowData.id
//        HStack(spacing: NODE_COMMON_SPACING) {
        HStack(alignment: .firstTextBaseline, spacing: NODE_COMMON_SPACING) {
            if forPropertySidebar {
                Image(systemName: "plus.circle")
                    .resizable()
                    .frame(width: 15, height: 15)
                    .onTapGesture {
                        if let layerInput = self.rowData.id.keyPath {
                            dispatch(LayerInputAddedToGraph(
                                nodeId: nodeId,
                                coordinate: layerInput))
                        } else if let portId = self.rowData.id.portId {
                            dispatch(LayerOutputAddedToGraph(
                                nodeId: nodeId,
                                coordinate: .init(portId: portId,
                                                  nodeId: nodeId)))
                        }
                    }
                    .opacity(propertyIsSelected ? 1 : 0)
            }
            
            // Fields and port ordering depending on input/output
            switch coordinateType {
            case .input(let inputCoordinate):
                if !forPropertySidebar {
                    NodeRowPortView(graph: graph,
                                    node: node,
                                    rowData: rowData,
                                    showPopover: $showPopover,
                                    coordinate: .input(inputCoordinate))
                }
                
                let isPaddingLayerInputRow = rowData.id.keyPath == .padding
                let hidePaddingFieldsOnPropertySidebar = isPaddingLayerInputRow && forPropertySidebar
                
                if hidePaddingFieldsOnPropertySidebar {
                    
                    Group {
                        labelView
                        
                        Spacer()
                        
                        // Want to just display the values; so need a new kind of `display only` view
                        ForEach(rowData.fieldValueTypes) { fieldGroupViewModel in
                            
                            ForEach(fieldGroupViewModel.fieldObservers)  { (fieldViewModel: FieldViewModel) in
                                
                                StitchTextView(string: fieldViewModel.fieldValue.stringValue,
                                               fontColor: STITCH_FONT_GRAY_COLOR)
                                // Monospacing prevents jittery node widths if values change on graphstep
                                .monospacedDigit()
                                // TODO: what is best width? Needs to be large enough for 3-digit values?
                                .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH - 12)
                                .background {
                                    INPUT_FIELD_BACKGROUND.cornerRadius(4)
                                }
                            }
                            
                        } // Group
                        
                        // Tap on the read-only fields to open padding flyout
                        .onTapGesture {
                            dispatch(FlyoutToggled(flyoutInput: .padding,
                                                   flyoutNodeId: inputCoordinate.nodeId))
                        }
                    }
                    
                    
                } else {
                    labelView
                    inputOutputRow(coordinate: coordinate)
                }
                
            case .output(let outputCoordinate):
                
                // Property sidebar always shows labels on left side, never right
                if forPropertySidebar {
                    labelView
                    
                    // TODO: fields in layer-inspector flush with right screen edge?
                    //                    Spacer()
                }
                
                // Hide outputs for value node
                if !isSplitter {
                    inputOutputRow(coordinate: coordinate)
                }
                                
                if !forPropertySidebar {
                    labelView
                    NodeRowPortView(graph: graph,
                                    node: node,
                                    rowData: rowData,
                                    showPopover: $showPopover,
                                    coordinate: .output(outputCoordinate))
                }
            }
        }
//        .frame(height: NODE_ROW_HEIGHT)
        
        // Don't specify height for layer inspector property row, so that multifields can be shown vertically
        .frame(height: forPropertySidebar ? nil : NODE_ROW_HEIGHT)
        
        .padding([.top, .bottom], forPropertySidebar ? 8 : 0)
        
        .onChange(of: self.graphUI.activeIndex) {
            let oldViewValue = self.rowData.activeValue
            let newViewValue = self.rowData.getActiveValue(activeIndex: self.graphUI.activeIndex)
            self.rowData.activeValueChanged(oldValue: oldViewValue,
                                            newValue: newViewValue)
        }
        .modifier(EdgeEditModeViewModifier(graphState: graph,
                                           portId: coordinate.portId,
                                           nodeId: coordinate.nodeId,
                                           nodeIOType: self.rowData.nodeIOType,
                                           forPropertySidebar: forPropertySidebar))
    }
   
    @ViewBuilder @MainActor
    var labelView: some View {
        LabelDisplayView(label: label,
                         isLeftAligned: false,
                         fontColor: STITCH_FONT_GRAY_COLOR)
    }

    @ViewBuilder @MainActor
    func inputOutputRow(coordinate: NodeIOCoordinate) -> some View {
        ForEach(rowData.fieldValueTypes) { fieldGroupViewModel in
            NodeFieldsView(
                graph: graph,
                rowObserver: rowData,
                fieldGroupViewModel: fieldGroupViewModel,
                coordinate: coordinate,
                nodeKind: nodeKind,
                nodeIO: coordinateType.nodeIO,
                isCanvasItemSelected: isCanvasItemSelected,
                hasIncomingEdge: rowData.upstreamOutputCoordinate.isDefined,
                adjustmentBarSessionId: adjustmentBarSessionId,
                forPropertySidebar: forPropertySidebar,
                propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph
            )
        }
    }
}

struct NodeRowPortView: View {
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var rowData: NodeRowObserver

    @Binding var showPopover: Bool
    let coordinate: PortViewType

    @MainActor
    var hasIncomingEdge: Bool {
        self.rowData.upstreamOutputObserver.isDefined
    }

    var nodeIO: NodeIO {
        self.rowData.nodeIOType
    }
    
    var nodeDelegate: NodeDelegate? {
        let isSplitterRowAndInvisible = node.kind.isGroup && rowData.nodeDelegate?.id != node.id
        
        // Use passed-in group node so we can obtain view-pertinent information for splitters.
        // Fixes issue where output splitters use wrong node delegate.
        if isSplitterRowAndInvisible {
            return node
        }
        
        return rowData.nodeDelegate
    }

    var body: some View {
        PortEntryView(rowObserver: rowData,
                      graph: graph,
                      coordinate: coordinate,
                      color: self.rowData.portColor, 
                      nodeDelegate: nodeDelegate)
        /*
         In practice, seems okay; e.g. Loop node changing from 3 to 1 disables the tap, and changing from 1 to 3 enables the tap.
         */
        .onTapGesture {
            // Do nothing when input/output doesn't contain a loop
            if rowData.hasLoopedValues {
                self.showPopover.toggle()
            } else {
                // If input/output count is no longer a loop,
                // any tap should just close the popover.
                self.showPopover = false
            }
        }
        // TODO: get popover to work with all values
        .popover(isPresented: $showPopover) {
            // Conditional is a hack that cuts down on perf
            if showPopover {
                PortValuesPreviewView(data: rowData,
                                      coordinate: self.rowData.id,
                                      nodeIO: nodeIO)
            }
        }
    }
}

//#Preview {
//    NodeInputOutputView(graph: <#T##GraphState#>,
//                        node: <#T##NodeViewModel#>, 
//                        rowData: <#T##NodeRowObserver#>,
//                        coordinateType: <#T##PortViewType#>,
//                        nodeKind: <#T##NodeKind#>,
//                        isNodeSelected: <#T##Bool#>, 
//                        adjustmentBarSessionId: <#T##AdjustmentBarSessionId#>)
//}

// struct SpecNodeInputView_Previews: PreviewProvider {
//    static var previews: some View {
//        let coordinate = Coordinate.input(InputCoordinate(portId: 0, nodeId: .init()))
//
//        NodeInputOutputView(valueObserver: .init(initialValue: .number(999),
//                                                 coordinate: coordinate,
//                                                 valuesCount: 1,
//                                                 isInFrame: true),
//                            valuesObserver: .init([.number(999)], coordinate),
//                            isInput: true,
//                            label: "",
//                            nodeKind: .patch(.add),
//                            focusedField: nil,
//                            layerNames: .init(),
//                            broadcastChoices: .init(),
//                            edges: .init(),
//                            selectedEdges: nil,
//                            nearestEligibleInput: nil,
//                            edgeDrawingGesture: .none)
//            .previewDevice(IPAD_PREVIEW_DEVICE_NAME)
//    }
// }
