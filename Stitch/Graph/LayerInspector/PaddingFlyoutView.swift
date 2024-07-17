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
    
//    static let insertNodeMenuBackground
}

struct PaddingFlyoutView: View {
    
    static let PADDING_FLYOUT_WIDTH = 256.0 // Per Figma
    
    @Bindable var graph: GraphState
    let rowObserver: NodeRowObserver
 
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
            
            // TODO: finalize this logic once 
            inputOutputRow
        }
        .padding()
        .background(Color.SWIFTUI_LIST_BACKGROUND_COLOR)
        .cornerRadius(8)
        .frame(width: Self.PADDING_FLYOUT_WIDTH)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.frame(in: .named(NodesView.coordinateNameSpace)),
                              initial: true) { oldValue, newValue in
                        // log("Flyout size: \(newValue.size)")
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

extension LayerInputType {
    var usesFlyout: Bool {
        switch self {
        case .padding:
            return true
        default:
            return false
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

struct FlyoutToggled: GraphUIEvent {
    
    let flyoutInput: LayerInputType
    let flyoutNodeId: NodeId
    
    func handle(state: GraphUIState) {
        if let flyoutState = state.propertySidebar.flyoutState,
           flyoutState.flyoutInput == flyoutInput,
           flyoutState.flyoutNode == flyoutNodeId {
            state.closeFlyout()
        } else {
//            withAnimation {
                state.propertySidebar.flyoutState = .init(
                    flyoutInput: flyoutInput,
                    flyoutNode: flyoutNodeId)
//            }
        }
    }
}

struct LeftSidebarToggled: GraphUIEvent {
    
    func handle(state: GraphUIState) {
        // Reset flyout
        state.closeFlyout()
    }
}

//#Preview {
//    PaddingFlyoutView()
//}
