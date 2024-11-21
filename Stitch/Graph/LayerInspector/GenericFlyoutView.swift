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

struct FlyoutHeader: View {
    
    let flyoutTitle: String
    
    var body: some View {
        HStack {
            StitchTextView(string: flyoutTitle).font(.title3)
            Spacer()
            Image(systemName: "xmark.circle.fill")
                .onTapGesture {
                    withAnimation {
                        dispatch(FlyoutClosed())
                    }
                }
        }
    }
}

struct GenericFlyoutView: View {
    
    static let DEFAULT_FLYOUT_WIDTH: CGFloat = 256.0 // Per Figma
    
    // Note: added later, because a static height is required for UIKitWrapper (key press listening); may be able to replace
    //    static let PADDING_FLYOUT_HEIGHT = 170.0 // Calculated by Figma
    @State var height: CGFloat? = nil
    
    @Bindable var graph: GraphState
    
    // non-nil, because flyouts are always for inspector inputs
    let layerInputObserver: LayerInputObserver
    
    let layer: Layer
    var hasIncomingEdge: Bool = false
    let layerInput: LayerInputPort
    
    let nodeId: NodeId
    let nodeKind: NodeKind
    
    let fieldValueTypes: [FieldGroupTypeViewModel<InputNodeRowViewModel.FieldType>]
        
    var body: some View {
        VStack(alignment: .leading) {
            FlyoutHeader(flyoutTitle: layerInput.label(useShortLabel: true))
            flyoutRows
        }
        .modifier(FlyoutBackgroundColorModifier(
            width: Self.DEFAULT_FLYOUT_WIDTH,
            height: self.$height))
    }
    
    @State var selectedFlyoutRow: Int? = nil
        
    // TODO: just use `NodeInputView` here ? Or keep this view separate and compose views ?
    @ViewBuilder @MainActor
    var flyoutRows: some View {
        // Assumes: all flyouts (besides shadow-flyout) have a single row which contains multiple fields
        FieldsListView<InputNodeRowViewModel, GenericFlyoutRowView>(
            graph: graph,
            fieldValueTypes: fieldValueTypes,
            nodeId: nodeId,
            forPropertySidebar: true,
            forFlyout: true,
            blockedFields: layerInputObserver.blockedFields) { inputFieldViewModel, isMultifield in
                GenericFlyoutRowView(
                    graph: graph,
                    viewModel: inputFieldViewModel,
                    layerInputObserver: layerInputObserver,
                    nodeId: nodeId,
                    fieldIndex: inputFieldViewModel.fieldIndex,
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

extension LayerInputObserver {
    // Used with a specific flyout-row, to add the field of the canvas
    func layerInputTypeForFieldIndex(_ fieldIndex: Int) -> LayerInputType {
        .init(layerInput: self.port,
                     portType: .unpacked(fieldIndex.asUnpackedPortType))
    }
}

struct GenericFlyoutRowView: View {
    
    @Bindable var graph: GraphState
    let viewModel: InputFieldViewModel
        
    let layerInputObserver: LayerInputObserver
    
    let nodeId: NodeId
    let fieldIndex: Int
    
    let isMultifield: Bool
    let nodeKind: NodeKind
    
    @State var isHovered: Bool = false
    
    var layerInput: LayerInputPort {
        layerInputObserver.port
    }
    
    var layerInputType: LayerInputType {
        layerInputObserver.layerInputTypeForFieldIndex(fieldIndex)
    }
    
    var layerInspectorRowId: LayerInspectorRowId {
        .layerInput(layerInputType)
    }
    
    // Coordinate is used for editing, which needs to know the
    var coordinate: NodeIOCoordinate {
        .init(portType: .keyPath(layerInputType),
              nodeId: nodeId)
    }
        
    @MainActor
    var canvasItemId: CanvasItemId? {
        // Is this particular unpacked-port already on the canvas?
        layerInputObserver.getCanvasItem(for: fieldIndex)?.id
    }
    
    @MainActor
    var propertyRowIsSelected: Bool {
        graph.graphUI.propertySidebar.selectedProperty == layerInspectorRowId
    }
    
    var body: some View {
        
        //        logInView("GenericFlyoutRowView: layerInputType: \(layerInputType)")
        //        logInView("GenericFlyoutRowView: coordinate: \(coordinate)")
        //        logInView("GenericFlyoutRowView: viewModel.rowViewModelDelegate?.activeValue: \(viewModel.rowViewModelDelegate?.activeValue)")
        //        logInView("GenericFlyoutRowView: viewModel.fieldValue: \(viewModel.fieldValue)")
        //
        
        HStack {
            LayerInspectorRowButton(layerInputObserver: layerInputObserver,
                                    layerInspectorRowId: layerInspectorRowId,
                                    coordinate: coordinate,
                                    canvasItemId: canvasItemId,
                                    isPortSelected: propertyRowIsSelected,
                                    isHovered: isHovered,
                                    fieldIndex: fieldIndex)
            
            InputValueEntry(graph: graph,
                            viewModel: viewModel,
                            layerInputObserver: layerInputObserver,
                            rowObserverId: coordinate,
                            nodeKind: nodeKind,
                            isCanvasItemSelected: false, // Always false
                            hasIncomingEdge: false,
                            forPropertySidebar: true,
                            propertyIsAlreadyOnGraph: canvasItemId.isDefined,
                            isFieldInMultifieldInput: isMultifield,
                            isForFlyout: true,
                            // Always false for flyout row
                            isSelectedInspectorRow: propertyRowIsSelected)
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

struct FlyoutBackgroundColorModifier: ViewModifier {
    
    let width: CGFloat?
    @Binding var height: CGFloat?
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.WHITE_IN_LIGHT_MODE_BLACK_IN_DARK_MODE)
            .cornerRadius(8)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                // TODO: better gray?
                    .stroke(Color(.stepScaleButtonHighlighted), //.gray,
                            lineWidth: 1)
            }
            .frame(width: width, height: height)
            .background {
                // TODO: this isn't quite accurate; read-height doesn't seem tall enough?
                GeometryReader { geometry in
                    Color.clear
                        .onChange(of: geometry.frame(in: .named(NodesView.coordinateNameSpace)),
                                  initial: true) { oldValue, newValue in
                            log("FlyoutBackgroundColorModifier size: \(newValue.size)")
                            self.height = newValue.size.height
                            dispatch(UpdateFlyoutSize(size: newValue.size))
                        }
                }
            }
    }
}


struct LayerInputFieldAddedToGraph: GraphEventWithResponse {
    
    let layerInput: LayerInputPort
    let nodeId: NodeId
    let fieldIndex: Int
    
    @MainActor
    func handle(state: GraphState) -> GraphResponse {
        
        //        log("LayerInputFieldAddedToGraph: layerInput: \(layerInput)")
        //        log("LayerInputFieldAddedToGraph: nodeId: \(nodeId)")
        //        log("LayerInputFieldAddedToGraph: fieldIndex: \(fieldIndex)")
        
        guard let node = state.getNode(nodeId),
              let layerNode = node.layerNode,
              let document = state.documentDelegate else {
            log("LayerInputFieldAddedToGraph: no node, layer node and/or document")
            return .noChange
        }
        
        let portObserver: LayerInputObserver = layerNode[keyPath: layerInput.layerNodeKeyPath]
        
        if let unpackedPort: InputLayerNodeRowData = portObserver._unpackedData.allPorts[safe: fieldIndex] {
            
            let parentGroupNodeId = state.groupNodeFocused
            
            var unpackSchema = unpackedPort.createSchema()
            unpackSchema.canvasItem = .init(position: document.newLayerPropertyLocation,
                                            zIndex: state.highestZIndex + 1,
                                            parentGroupNodeId: parentGroupNodeId)

            let unpackedPortParentFieldGroupType: FieldGroupType = layerInput
                .getDefaultValue(for: layerNode.layer)
                .getNodeRowType(nodeIO: .input)
                .getFieldGroupTypeForLayerInput
            
            unpackedPort.update(from: unpackSchema,
                                layerInputType: unpackedPort.id,
                                layerNode: layerNode,
                                nodeId: nodeId,
                                unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                unpackedPortIndex: fieldIndex)
            
            unpackedPort.canvasObserver?.initializeDelegate(
                node,
                unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                unpackedPortIndex: fieldIndex)
            
            state.resetLayerInputsCache(layerNode: layerNode)
        } else {
            fatalErrorIfDebug("LayerInputFieldAddedToGraph: no unpacked port for fieldIndex \(fieldIndex)")
        }
                
        return .persistenceResponse
    }
}
