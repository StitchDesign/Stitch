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

struct PaddingFlyoutView: View {
    
    static let PADDING_FLYOUT_WIDTH = 256.0 // Per Figma
    
    // Note: added later, because a static height is required for UIKitWrapper (key press listening); may be able to replace 
    static let PADDING_FLYOUT_HEIGHT = 170.0 // Calculated by Figma
        
    @Bindable var graph: GraphState
    let rowViewModel: InputNodeRowViewModel
    let layer: Layer
    let hasIncomingEdge: Bool
     
    var body: some View {
        
        VStack(alignment: .leading) {
            FlyoutHeader(flyoutTitle: "Padding")
                        
            // TODO: better keypress listening situation; want to define a keypress press once in the view hierarchy, not multiple places etc.
            // Note: keypress listener needed for TAB, but UIKitWrapper messes up view's height if specific height not provided
            
            // TODO: UIKitWrapper adds a bit of padding at the bottom?
            UIKitWrapper(ignoresKeyCommands: false,
                         name: "PaddingFlyout") {
                // TODO: finalize this logic once fields are in?
                inputOutputRow
            }
        }
        .padding()
        .background(Color.SWIFTUI_LIST_BACKGROUND_COLOR)
        .cornerRadius(8)
        .frame(width: Self.PADDING_FLYOUT_WIDTH, height: Self.PADDING_FLYOUT_HEIGHT)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.frame(in: .named(NodesView.coordinateNameSpace)),
                              initial: true) { oldValue, newValue in
                        log("Padding flyout size: \(newValue.size)")
                        dispatch(UpdateFlyoutSize(size: newValue.size))
                    }
            }
        }
    }
    
    @ViewBuilder @MainActor
    var inputOutputRow: some View {
        FieldsListView(graph: graph,
                       rowViewModel: rowViewModel,
                       nodeId: rowViewModel.id.nodeId,
                       isGroupNodeKind: rowViewModel.nodeKind.isGroup,
                       forPropertySidebar: true,
                       // TODO: fix
                       propertyIsAlreadyOnGraph: false) { portViewModel, isMultiField in
            
            if let coordinate = rowViewModel.rowDelegate?.id {
                InputValueEntry(graph: graph,
                                rowViewModel: rowViewModel,
                                viewModel: portViewModel,
                                rowObserverId: coordinate,
                                nodeKind: .layer(layer),
                                isCanvasItemSelected: false,
                                hasIncomingEdge: hasIncomingEdge,
                                forPropertySidebar: true,
                                // TODO: fix
                                propertyIsAlreadyOnGraph: false)
            } else {
                Color.clear
                    .onAppear {
                        fatalErrorIfDebug()
                    }
            }
        }
    }
}

//#Preview {
//    PaddingFlyoutView()
//}

struct PaddingReadOnlyView: View {
    
    @Bindable var rowObserver: InputNodeRowObserver
    @Bindable var rowData: InputNodeRowObserver.RowViewModelType
    let labelView: LabelDisplayView
    
    @State var hoveredFieldIndex: Int? = nil
    
    var nodeId: NodeId {
        self.rowObserver.id.nodeId
    }
    
    var body: some View {
        Group {
            labelView
            
            Spacer()
            
            // Want to just display the values; so need a new kind of `display only` view
            ForEach(rowData.fieldValueTypes) { fieldGroupViewModel in
                
                ForEach(fieldGroupViewModel.fieldObservers)  { (fieldViewModel: InputFieldViewModel) in
                    
                    let fieldIndex = fieldViewModel.fieldIndex
                    
                    StitchTextView(string: fieldViewModel.fieldValue.stringValue,
                                   fontColor: STITCH_FONT_GRAY_COLOR)
                    
                    // Monospacing prevents jittery node widths if values change on graphstep
                    .monospacedDigit()
                    // TODO: what is best width? Needs to be large enough for 3-digit values?
                    .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH - 12)
                    .background {
                        if self.hoveredFieldIndex == fieldViewModel.fieldIndex {
                            INPUT_FIELD_BACKGROUND.cornerRadius(4)
                        }
                    }
                    .onHover { hovering in
                        withAnimation {
                            if hovering {
                                self.hoveredFieldIndex = fieldIndex
                            } else if self.hoveredFieldIndex == fieldIndex {
                                self.hoveredFieldIndex = nil
                            }
                        }
                    }
                } // ForEach
                
            } // Group
            
            // Tap on the read-only fields to open padding flyout
            .onTapGesture {
                dispatch(FlyoutToggled(flyoutInput: .padding,
                                       flyoutNodeId: nodeId))
            }
        }
    }
}
