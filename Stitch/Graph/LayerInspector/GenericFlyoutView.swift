//
//  PaddingFlyoutView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/15/24.
//

import SwiftUI
import StitchSchemaKit

extension Color {
    static let SWIFTUI_LIST_BACKGROUND_COLOR = Color(uiColor: .secondarySystemBackground)
}

struct GenericFlyoutView: View {
    
    static let DEFAULT_FLYOUT_WIDTH = 256.0 // Per Figma
    
    // Note: added later, because a static height is required for UIKitWrapper (key press listening); may be able to replace
    //    static let PADDING_FLYOUT_HEIGHT = 170.0 // Calculated by Figma
    @State var height: CGFloat? = nil
    
    @Bindable var graph: GraphState
    
    // non-nil, because flyouts are always for inspector inputs
    let inputLayerNodeRowData: LayerInputObserver
    
    let layer: Layer
    var hasIncomingEdge: Bool = false
    let layerInput: LayerInputPort
    
    let nodeId: NodeId
    let nodeKind: NodeKind
    
    let fieldValueTypes: [FieldGroupTypeViewModel<InputNodeRowViewModel.FieldType>]
        
    var body: some View {
        
        VStack(alignment: .leading) {
            // TODO: need better padding here; but confounding factor is UIKitWrapper
            FlyoutHeader(flyoutTitle: layerInput.label(useShortLabel: true))
            
            // TODO: better keypress listening situation; want to define a keypress press once in the view hierarchy, not multiple places etc.
            // Note: keypress listener needed for TAB, but UIKitWrapper messes up view's height if specific height not provided
            
            // TODO: UIKitWrapper adds a bit of padding at the bottom?
            //            UIKitWrapper(ignoresKeyCommands: false,
            //                         name: "PaddingFlyout") {
            // TODO: finalize this logic once fields are in?
            flyoutRows
            //            }
        }
        .padding()
        .background(Color.WHITE_IN_LIGHT_MODE_BLACK_IN_DARK_MODE)
        .cornerRadius(8)
        .frame(width: Self.DEFAULT_FLYOUT_WIDTH,
               height: self.height)
        .background {
            // TODO: this isn't quite accurate; read-height doesn't seem tall enough?
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.frame(in: .named(NodesView.coordinateNameSpace)),
                              initial: true) { oldValue, newValue in
                        log("GenericFlyout size: \(newValue.size)")
                        dispatch(UpdateFlyoutSize(size: newValue.size))
                    }
            }
        }
    }
    
    @State var selectedFlyoutRow: Int? = nil
        
    // TODO: just use `NodeInputView` here ?
    @ViewBuilder @MainActor
    var flyoutRows: some View {
        // Assumes: all flyouts (besides shadow-flyout) have a single row which contains multiple fields
        FieldsListView<InputNodeRowViewModel, GenericFlyoutRowView>(
            graph: graph,
            fieldValueTypes: fieldValueTypes,
            nodeId: nodeId,
            isGroupNodeKind: false,
            forPropertySidebar: true,
            // fix this?
            propertyIsAlreadyOnGraph: false) { inputFieldViewModel, isMultifield in
                                
                let fieldIndex = inputFieldViewModel.fieldIndex
                
                  GenericFlyoutRowView(
                    graph: graph,
                    viewModel: inputFieldViewModel,
                    // coordinate: inputF // inputRowViewModel.rowDelegate?.id,
                    layerInputObserver: inputLayerNodeRowData,
                    layerInput: layerInput,
                    nodeId: nodeId,
                    fieldIndex: fieldIndex,
                    isMultifield: isMultifield,
                    nodeKind: nodeKind)
        }
        
    }
}

extension Int {
    var asUnpackedPortType: UnpackedPortType {
        switch self {
        case 0:
            return .port0
        case 1:
            return .port1
        case 2:
            return .port2
        case 3:
            return .port3
        default:
            fatalErrorIfDebug()
            return .port0
        }
    }
}

struct GenericFlyoutRowView: View {
    
    @Bindable var graph: GraphState
    let viewModel: InputFieldViewModel
        
    let layerInputObserver: LayerInputObserver
    
    let layerInput: LayerInputPort
    let nodeId: NodeId
    let fieldIndex: Int
    
    let isMultifield: Bool
    let nodeKind: NodeKind
    
    @State var isHovered: Bool = false
        
    var layerInputType: LayerInputType {
        .init(layerInput: layerInput,
              portType: .unpacked(fieldIndex.asUnpackedPortType))
    }
    
    var layerInspectorRowId: LayerInspectorRowId {
        .layerInput(layerInputType)
    }
    
    var coordinate: NodeIOCoordinate {
        .init(portType: .keyPath(layerInputType),
              nodeId: nodeId)
    }
    
    @MainActor
    var isSelectedRow: Bool {
        graph.graphUI.propertySidebar.selectedProperty == layerInspectorRowId
    }
    
    @MainActor
    var canvasItemId: CanvasItemId? {
        // Is this particular unpacked-port already on the canvas?
        layerInputObserver.getCanvasItem(for: fieldIndex)?.id
    }
    
    var body: some View {
        HStack {
            LayerInspectorRowButton(layerInputObserver: layerInputObserver,
                                    layerInspectorRowId: layerInspectorRowId,
                                    coordinate: coordinate,
                                    canvasItemId: canvasItemId,
                                    isPortSelected: isSelectedRow,
                                    isHovered: isHovered)
            
            InputValueEntry(graph: graph,
                            viewModel: viewModel,
                            inputLayerNodeRowData: layerInputObserver,
                            rowObserverId: coordinate,
                            nodeKind: nodeKind,
                            isCanvasItemSelected: false, // Always false
                            hasIncomingEdge: false,
                            forPropertySidebar: true,
                            propertyIsAlreadyOnGraph: canvasItemId.isDefined,
                            isFieldInMultifieldInput: isMultifield,
                            isForFlyout: true,
                            isSelectedInspectorRow: isSelectedRow)
        } // HStack
        .contentShape(Rectangle())
        .onHover(perform: { hovering in
            self.isHovered = hovering
        })
        .onTapGesture {
            graph.graphUI.onLayerPortRowTapped(
                layerInspectorRowId: layerInspectorRowId,
                 canvasItemId: canvasItemId)
        }
    }
}

struct  LayerInputFieldAddedToGraph: GraphEventWithResponse {
    
    let layerInput: LayerInputPort
    let nodeId: NodeId
    let fieldIndex: Int
    
    func handle(state: GraphState) -> GraphResponse {
        
        guard let node = state.getNode(nodeId),
              let layerNode = node.layerNode else {
            return .noChange
        }
        
        let portObserver: LayerInputObserver = layerNode[keyPath: layerInput.layerNodeKeyPath]
        
        if let unpackedPort: InputLayerNodeRowData = portObserver._unpackedData.allPorts[safe: fieldIndex] {
            
            let parentGroupNodeId = state.groupNodeFocused
            
            var unpackSchema = unpackedPort.createSchema()
            unpackSchema.canvasItem = .init(position: state.newLayerPropertyLocation,
                                            zIndex: state.highestZIndex + 1,
                                            parentGroupNodeId: parentGroupNodeId)

//            // TODO: SEPT 12
            let defaultValue = layerInput.getDefaultValue(for: layerNode.layer)
            let nodeRowType = defaultValue.getNodeRowType(nodeIO: .input)
            let unpackedPortParentFieldGroupType: FieldGroupType = nodeRowType.getFieldGroupTypeForLayerInput

            // In this case, we already have the fieldIndex as 0 or 1 ?
            let unpackedPortIndex: Int? = fieldIndex
            
            unpackedPort.update(from: unpackSchema,
                                layerInputType: unpackedPort.id,
                                layerNode: layerNode,
                                nodeId: nodeId,
                                unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                unpackedPortIndex: unpackedPortIndex,
                                nodeDelegate: node)
        }
        
        return .persistenceResponse
    }
}
