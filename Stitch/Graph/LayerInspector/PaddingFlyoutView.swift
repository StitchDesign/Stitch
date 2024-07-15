//
//  PaddingFlyoutView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/15/24.
//

import SwiftUI
import StitchSchemaKit

struct Field: Equatable, Identifiable {
    var id = UUID()
    let label: String
    let value: Double
}

struct PaddingFlyoutView: View {
    
    static let WIDTH = 256.0 // Per Figma
    
    // TODO: finalize this logic once
    
    @Bindable var graph: GraphState
    
    let rowObserver: NodeRowObserver
    
    // the fields of multifield PortValue like Padding (Point4D), Dropshadow etc.
    let fields: [Field] = [
        .init(label: "Top", value: 0),
        .init(label: "Right", value: 0),
        .init(label: "Bottom", value: 0),
        .init(label: "Left", value: 0),
//        .init(label: "Safe Area Top", value: 0),
//        .init(label: "Safe Area Bottom", value: 0)
    ]
    
    var body: some View {
        
        VStack(alignment: .leading) {
            
            HStack {
                Text("Padding").font(.title3)
                Spacer()
                Image(systemName: "xmark.circle.fill")
                    .onTapGesture {
                        withAnimation {
                            dispatch(FlyoutClosed())
                        }
                    }
            }
            
            // ForEach causes animation problems?
//            ForEach(fields) { field in
//                //                    Spacer()
//                HStack {
//                    Text(field.label)
//                    Spacer()
//                    // Ignores Spacer() if no width set
//                    TextField("", text: .constant(field.value.description))
//                        .frame(width: 30)
//                        .padding(.leading, 8)
//                        .background {
//                            Color.gray
//                                .cornerRadius(4)
//                        }
//                }
//            } // ForEach
//            .padding(.leading)
            
            inputOutputRow
                .border(.green)
        }
        .padding()
        .background(.gray)
        .cornerRadius(8)
        .frame(width: Self.WIDTH)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.frame(in: .named(NodesView.coordinateNameSpace)),
                              initial: true) { oldValue, newValue in
                        print("Flyout size: \(newValue.size)")
                        dispatch(UpdateFlyoutSize(size: newValue.size))
                    }
            }
        }
    }
    
    @ViewBuilder @MainActor
    var inputOutputRow: some View {
        ForEach(rowObserver.fieldValueTypes) { fieldGroupViewModel in
            NodeFieldsView(
                graph: graph,
                rowObserver: rowObserver,
                fieldGroupViewModel: fieldGroupViewModel,
                coordinate: rowObserver.id,
                nodeKind: rowObserver.nodeKind,
                nodeIO: .input,
                isCanvasItemSelected: true,
                hasIncomingEdge: false, // NA?
                adjustmentBarSessionId: graph.graphUI.adjustmentBarSessionId,
                forPropertySidebar: true,
                propertyIsAlreadyOnGraph: false // TODO: fix
            )
        }
    }
}

// Used by a given flyout view to update its read-height in state,
// for proper positioning.
struct UpdateFlyoutSize: GraphUIEvent {
    let size: CGSize
    
    func handle(state: GraphUIState) {
        state.propertySidebar.flyoutState?.flyoutSize = size
    }
}

struct FlyoutClosed: GraphUIEvent {
    func handle(state: GraphUIState) {
        state.closeFlyout()
    }
}

extension GraphUIState {
    func closeFlyout() {
        withAnimation {
            self.propertySidebar.flyoutState = nil
        }
    }
}

struct FlyoutOpened: GraphUIEvent {
    
    let flyoutInput: LayerInputType
    let flyoutNodeId: NodeId
    
    func handle(state: GraphUIState) {
        withAnimation {
            state.propertySidebar.flyoutState = .init(
                flyoutInput: flyoutInput,
                flyoutNode: flyoutNodeId)
        }
    }
}

struct LeftSidebarVisibilityStateChanged: GraphUIEvent {
    let status: NavigationSplitViewVisibility
    
    func handle(state: GraphUIState) {
        
        // Reset flyout
        state.closeFlyout()
        
        // Track in state whether left sidebar is open or not
        switch status {
        case .detailOnly:
            state.leftSidebarIsOpen = false
        case .all, .doubleColumn:
            state.leftSidebarIsOpen = true
        case .automatic: // Inaccurate?
            state.leftSidebarIsOpen = false
        default:
            state.leftSidebarIsOpen = false
        }
    }
}

//#Preview {
//    PaddingFlyoutView()
//}
