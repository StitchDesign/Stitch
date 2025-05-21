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
    
    // Abstracts over packed vs unpacked
    var fieldGroups: [FieldGroup] {
        layerInputObserver.fieldGroupsFromInspectorRowViewModels
    }
        
    var body: some View {
        VStack(alignment: .leading) {
            FlyoutHeader(flyoutTitle: layerInput.label(useShortLabel: true))
            // TODO: move to FlyoutHeader itself? individual fields need it but not full inputs like in ShadowFlyout ?
                .padding(.bottom)
            
            flyoutRows
        }
        .modifier(FlyoutBackgroundColorModifier(
            width: Self.DEFAULT_FLYOUT_WIDTH,
            height: self.$height))
    }
    
    @State var selectedFlyoutRow: Int? = nil
    
    @ViewBuilder @MainActor
    var flyoutRows: some View {
        // Assumes: all flyouts (besides shadow-flyout) have a single row which contains multiple fields
        ForEach(fieldGroups) { (fieldGroup: FieldGroup) in
            
            FieldGroupLabelView(fieldGroup: fieldGroup)
            
            VStack { // flyout fields always stacked vertically
                PotentiallyBlockedFieldsView(
                    fieldGroup: fieldGroup,
                    isMultifield: true, // generic flyout always multifield
                    blockedFields: layerInputObserver.blockedFields) { inputFieldViewModel, isMultifield, _ in
                        GenericFlyoutRowView(
                            graph: graph,
                            document: document,
                            viewModel: inputFieldViewModel,
                            rowViewModel: rowViewModel,
                            node: node,
                            layerInputObserver: layerInputObserver,
                            isMultifield: isMultifield)
                    }
            }
        }
    }
}

// Only actually for packed 3D Transform layer inputs?
struct FieldGroupLabelView: View {
    let fieldGroup: FieldGroup
    
    var body: some View {
        if let fieldGroupLabel = fieldGroup.groupLabel {
            HStack {
                LabelDisplayView(label: fieldGroupLabel,
                                 isLeftAligned: false,
                                 fontColor: STITCH_FONT_GRAY_COLOR,
                                 usesThemeColor: false)
                Spacer()
            }
        }
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
    var isSelectedInspectorRow: Bool {
        graph.propertySidebar.selectedProperty == layerInspectorRowId
    }
    
    var rowObserver: InputNodeRowObserver? {
        
        switch self.layerInputObserver.observerMode {
        
        case .packed(let inputLayerNodeRowData):
            return inputLayerNodeRowData.rowObserver
        
        case .unpacked(let layerInputUnpackedPortObserver):
            
            guard let unpackedObserver = layerInputUnpackedPortObserver.allPorts[safe: fieldIndex] else {
                fatalErrorIfDebug()
                return nil
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
                                        layerInputObserver: layerInputObserver,
                                        layerInspectorRowId: layerInspectorRowId,
                                        // For layer inspector row button, provide a NodeIOCoordinate that assumes unpacked + field index
                                        coordinate: InputCoordinate(portType: .keyPath(layerInputType),
                                                                    nodeId: node.id),
                                        packedInputCanvasItemId: canvasItemId,
                                        isHovered: isHovered,
                                        // use of color-theme on a flyout row is determined only by whether the row is selected,
                                        // since we cannot drag an edge to it
                                        usesThemeColor: isSelectedInspectorRow,
                                        disabledInputAnchorPreferenceTracking: true,
                                        fieldIndex: fieldIndex)
            }
                                    
            if let rowObserver = self.rowObserver {
                InputFieldView(graph: graph,
                               document: document,
                               inputField: viewModel,
                               node: node,
                               rowId: rowViewModel.id,
                               layerInputPort: rowViewModel.layerInput,
                               canvasItemId: nil,
                               
                               // For input editing, however, we need the proper packed vs unpacked state
                               rowObserver: rowObserver,
                               isCanvasItemSelected: false, // Always false
                               hasIncomingEdge: false,
                               isForLayerInspector: true,
                               isPackedLayerInputAlreadyOnCanvas: canvasItemId.isDefined,
                               isFieldInMultifieldInput: isMultifield,
                               isForFlyout: true,
                               // Always false for flyout row
                               isSelectedInspectorRow: false,
                               useIndividualFieldLabel: layerInputObserver.useIndividualFieldLabel(activeIndex:  document.activeIndex),
                               usesThemeColor: false)
            }
            
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
                        .onChange(of: geometry.frame(in: .named(NodesView.coordinateNamespace)),
                                  initial: true) { oldValue, newValue in
                            log("FlyoutBackgroundColorModifier size: \(newValue.size)")
                            self.height = newValue.size.height
                            dispatch(UpdateFlyoutSize(size: newValue.size))
                        }
                }
            }
    }
}
