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

    var isSplitter: Bool {
        self.nodeKind == .patch(.splitter)
    }

    var activeValue: PortValue {
        self.rowData.activeValue
    }

    var body: some View {
        let coordinate = rowData.id
        HStack(spacing: NODE_COMMON_SPACING) {
            if forPropertySidebar {
                Image(systemName: "plus.circle")
                    .resizable()
                    .frame(width: 15, height: 15)
                    .onTapGesture {
                        if let layerInput = self.rowData.id.keyPath {
                            dispatch(LayerInputAddedToGraph(nodeId: self.node.id,
                                                            coordinate: layerInput))
                        } 
//                        else if let portId = self.rowData.id.portId {
//                            dispatch(LayerOutputAddedToGraph(nodeId: self.node.id,
//                                                            coordinate: .init()))
//                        }
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
                
                labelView
                inputOutputRow(coordinate: coordinate)

            case .output(let outputCoordinate):
                // Hide outputs for value node
                if !isSplitter {
                    inputOutputRow(coordinate: coordinate)
                }
                labelView
                if !forPropertySidebar {
                    NodeRowPortView(graph: graph,
                                    node: node,
                                    rowData: rowData,
                                    showPopover: $showPopover,
                                    coordinate: .output(outputCoordinate))
                }
            }
        }
        .frame(height: NODE_ROW_HEIGHT)
        .onChange(of: self.graphUI.activeIndex) {
            let oldViewValue = self.rowData.activeValue
            let newViewValue = self.rowData.getActiveValue(activeIndex: self.graphUI.activeIndex)
            self.rowData.activeValueChanged(oldValue: oldViewValue,
                                            newValue: newViewValue)
        }
    }
    
    var isLayer: Bool {
        self.nodeKind.isLayer
    }
            
    @ViewBuilder
    @MainActor
    var labelView: some View {
        LabelDisplayView(label: label,
                         isLeftAligned: false,
                         fontColor: STITCH_FONT_GRAY_COLOR)
    }

    @ViewBuilder
    @MainActor
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
