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
    @Bindable var document: StitchDocumentViewModel
    
    let rowViewModel: InputNodeRowViewModel
    let node: NodeViewModel
    
    // non-nil, because flyouts are always for inspector inputs
    let layerInputObserver: LayerInputObserver
    
    let layer: Layer
    var hasIncomingEdge: Bool = false
    let layerInput: LayerInputPort
    
    var fieldValueTypes: [FieldGroupTypeData] {
        layerInputObserver.fieldValueTypes
    }
        
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
        LayerInputFieldsView(layerInputFieldType: .flyout,
                             document: document,
                             graph: graph,
                             node: node,
                             rowObserver: layerInputObserver.packedRowObserver,
                             rowViewModel: rowViewModel,
                             fieldValueTypes: fieldValueTypes,
                             layerInputObserver: layerInputObserver,
                             isNodeSelected: false)
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
        case 4:
            return .port4
        case 5:
            return .port5
        case 6:
            return .port6
        case 7:
            return .port7
        case 8:
            return .port8
        default:
            fatalErrorIfDebug()
            return .port0
        }
    }
}

extension LayerInputObserver {
    // Used with a specific flyout-row, to add the field of the canvas
    @MainActor
    func layerInputTypeForFieldIndex(_ fieldIndex: Int) -> LayerInputType {
        .init(layerInput: self.port,
                     portType: .unpacked(fieldIndex.asUnpackedPortType))
    }
}

struct GenericFlyoutRowView: View {
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    let viewModel: InputFieldViewModel
        
    let rowViewModel: InputNodeRowViewModel
    let node: NodeViewModel
    let layerInputObserver: LayerInputObserver
    
    let isMultifield: Bool
    
    @State var isHovered: Bool = false

    var fieldIndex: Int {
        viewModel.fieldIndex
    }
        
    var layerInputType: LayerInputType {
        layerInputObserver.layerInputTypeForFieldIndex(fieldIndex)
    }
    
    var layerInspectorRowId: LayerInspectorRowId {
        .layerInput(layerInputType)
    }
    
    @MainActor
    var canvasItemId: CanvasItemId? {
        // Is this particular unpacked-port already on the canvas?
        layerInputObserver.getCanvasItem(for: fieldIndex)?.id
    }
    
    @MainActor
    var isPropertyRowSelected: Bool {
        graph.propertySidebar.selectedProperty == layerInspectorRowId
    }
    
    var rowObserver: InputNodeRowObserver {
        switch self.layerInputObserver.observerMode {
        case .packed(let inputLayerNodeRowData):
            return inputLayerNodeRowData.rowObserver
        case .unpacked(let layerInputUnpackedPortObserver):
            guard let unpackedObserver = layerInputUnpackedPortObserver.allPorts[safe: fieldIndex] else {
                fatalErrorIfDebug()
                return self.layerInputObserver._packedData.rowObserver
            }
            
            return unpackedObserver.rowObserver
        }
    }
    
    var body: some View {
        
        HStack {
            
            // Note: ShadowFlyoutRow has its own LayerInspectorRowButton, so don't use one again here
            if !layerInputObserver.port.isShadowInput {
                // For the layer inspector row button, use a
                LayerInspectorRowButton(graph: graph,
                                        document: document,
                                        layerInputObserver: layerInputObserver,
                                        layerInspectorRowId: layerInspectorRowId,
                                        // For layer inspector row button, provide a NodeIOCoordinate that assumes unpacked + field index
                                        coordinate: InputCoordinate(portType: .keyPath(layerInputType),
                                                                    nodeId: node.id),
                                        canvasItemId: canvasItemId,
                                        isHovered: isHovered,
                                        fieldIndex: fieldIndex)
            }
                                    
            InputValueEntry(graph: graph,
                            document: document,
                            viewModel: viewModel,
                            node: node,
                            rowViewModel: rowViewModel,
                            canvasItem: nil,
                            // For input editing, however, we need the proper packed vs unpacked state
                            rowObserver: rowObserver,
                            isCanvasItemSelected: false, // Always false
                            hasIncomingEdge: false,
                            isForLayerInspector: true,
                            isPackedLayerInputAlreadyOnCanvas: canvasItemId.isDefined,
                            isFieldInMultifieldInput: isMultifield,
                            isForFlyout: true,
                            // Always false for flyout row
                            isSelectedInspectorRow: isPropertyRowSelected,
                            useIndividualFieldLabel: layerInputObserver.useIndividualFieldLabel(activeIndex: document.activeIndex))
        } // HStack
        .contentShape(Rectangle())
        .onHover(perform: { hovering in
            self.isHovered = hovering
        })
        .onTapGesture {
            document.onLayerPortRowTapped(
                layerInspectorRowId: layerInspectorRowId,
                canvasItemId: canvasItemId,
                graph: graph)
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


extension GraphState {
    @MainActor
    func addLayerFieldToGraph(layerInput: LayerInputPort,
                              nodeId: NodeId,
                              fieldIndex: Int,
                              groupNodeFocused: NodeId?) {
        
        guard let node = self.getNode(nodeId),
              let layerNode = node.layerNode,
              let document = self.documentDelegate else {
            log("LayerInputFieldAddedToGraph: no node, layer node and/or document")
            fatalErrorIfDebug()
            return
        }
        
        let portObserver: LayerInputObserver = layerNode[keyPath: layerInput.layerNodeKeyPath]
        
        let previousPackMode = portObserver.mode
        
        guard let unpackedPort: InputLayerNodeRowData = portObserver._unpackedData.allPorts[safe: fieldIndex] else {
            fatalErrorIfDebug("LayerInputFieldAddedToGraph: no unpacked port for fieldIndex \(fieldIndex)")
            return
        }
                
        var unpackSchema = unpackedPort.createSchema()
        unpackSchema.canvasItem = .init(position: document.newCanvasItemInsertionLocation,
                                        zIndex: self.highestZIndex + 1,
                                        parentGroupNodeId: groupNodeFocused)
        
        // MARK: first group type grabbed since layers don't have differing groups within one input
        guard let unpackedPortParentFieldGroupType: FieldGroupType = layerInput
            .getDefaultValue(for: layerNode.layer)
            .getNodeRowType(nodeIO: .input,
                            layerInputPort: layerInput,
                            isLayerInspector: true)
                .fieldGroupTypes
            .first else {
            
            fatalErrorIfDebug()
            return
        }
        
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
        
        let newPackMode = portObserver.mode
        if previousPackMode != newPackMode {
            portObserver.wasPackModeToggled()
        }
        
        self.resetLayerInputsCache(layerNode: layerNode)
    }
}

struct LayerInputFieldAddedToGraph: StitchDocumentEvent {
    
    let layerInput: LayerInputPort
    let nodeId: NodeId
    let fieldIndex: Int
    
    @MainActor
    func handle(state: StitchDocumentViewModel) {
        
        //        log("LayerInputFieldAddedToGraph: layerInput: \(layerInput)")
        //        log("LayerInputFieldAddedToGraph: nodeId: \(nodeId)")
        //        log("LayerInputFieldAddedToGraph: fieldIndex: \(fieldIndex)")
        
        let graph = state.visibleGraph
        
        let addLayerField = { (nodeId: NodeId) in
            graph.addLayerFieldToGraph(layerInput: layerInput,
                                       nodeId: nodeId,
                                       fieldIndex: fieldIndex,
                                       groupNodeFocused: state.groupNodeFocused?.groupNodeId)
        }
        
        if let multiselectInputs = graph.propertySidebar.inputsCommonToSelectedLayers,
           let layerMultiselectInput = multiselectInputs.first(where: { $0 == layerInput}) {
            
            layerMultiselectInput.multiselectObservers(graph).forEach { observer in
                addLayerField(observer.packedRowObserver.id.nodeId)
            }
        } else {
            addLayerField(nodeId)
        }
        
        state.encodeProjectInBackground()
    }
}
