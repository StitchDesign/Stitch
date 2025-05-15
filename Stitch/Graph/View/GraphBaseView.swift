//
//  GraphBase.swift
//  prototype
//
//  Created by Christian J Clampitt on 1/26/22.
//

import SwiftUI
import StitchSchemaKit

// Grid lines, cursor, selection box, patch and layer nodes
struct GraphBaseView: View {
    
    static let coordinateNamespace = "GRAPHBASEVIEW_NAMESPACE"
    
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    
    @Environment(\.safeAreaInsets) private var safeAreaInsets: SafeAreaInsets
    
    @State private var spaceHeld = false

    @Bindable var store: StitchStore
    @Bindable var document: StitchDocumentViewModel
    
    @MainActor
    var graph: GraphState {
        self.document.visibleGraph
    }

    var body: some View {
        // Our screen device measurements ignore the safe area,
        // so our touch-responsive interfaces must ignore them to.

        nodesAndCursor
            .onAppear {
                #if targetEnvironment(macCatalyst)
                if self.spaceHeld || document.keypressState.isSpacePressed {
                    NSCursor.openHand.push()
                }
                #endif
                dispatch(ColorSchemeReceived(colorScheme: colorScheme))
                dispatch(SafeAreaInsetsReceived(insets: safeAreaInsets))
            }
            .onChange(of: colorScheme) { _, color in
                //                log("GraphBaseView: onChange of ColorScheme")
                dispatch(ColorSchemeReceived(colorScheme: color))
            }
            .onChange(of: safeAreaInsets) { _, insets in
                //                log("GraphBaseView: onChange of safeAreaInsets")
                dispatch(SafeAreaInsetsReceived(insets: insets))
            }

        #if targetEnvironment(macCatalyst)
            .modifier(GraphHoverViewModifier(spaceHeld: self.$spaceHeld,
                                             document: document))
        #endif
    }

    @ViewBuilder @MainActor
    var nodesView: some View {
        NodesView(document: document,
                  graph: graph,
                  groupTraversedToChild: document.groupTraversedToChild)
        .overlay {
            // Show debug mode tip view
            if document.isDebugMode {
                VStack {
                    HStack {
                        DebugModePopover()
                        Spacer()
                    }
                    Spacer()
                }
            }
            
            if document.llmRecording.modal == .approveAndSubmit {
                VStack {
                    HStack {
                        LLMApprovalModalView(prompt: document.llmRecording.promptState.prompt)
                        Spacer()
                    }
                    Spacer()
                }
            }
            
            // Better to show modal here, so user can move around etc.
            if document.llmRecording.modal == .editBeforeSubmit {
                VStack {
                    HStack {
                        EditBeforeSubmitModalView(
                            document: document,
                            graph: graph)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder @MainActor
    var nodesAndCursor: some View {
//        ZStack {
        ZStack(alignment: .center) {
            
            // To cover top safe area that we don't ignore on iPad and that is gesture-inaccessbile
//            Stitch.APP_BACKGROUND_COLOR
//                .edgesIgnoringSafeArea(.all)
                // .zIndex(-10)
            
            #if DEV_DEBUG
            // Use `ZStack { ...` instead of `ZStack(alignment: .top) { ...`
            // to get in exact screen center.
            Circle().fill(.cyan.opacity(0.5))
                .frame(width: 60, height: 60)
            #endif

            
            // lets us draw edge over it, but canvas items also go over
//            Circle().fill(Stitch.APP_BACKGROUND_COLOR.opacity(0.001))
//                .frame(width: 1, height: 1)
//                .inspector(isPresented: $store.showsLayerInspector) {
//                    
//                    LayerInspectorView(graph: graph,
//                                       document: document)
//                        .inspectorColumnWidth(LayerInspectorView.LAYER_INSPECTOR_WIDTH)
//                }
            
            nodesView
                          
            // IMPORTANT: applying .inspector outside of this ZStack causes displacement of graph contents when graph zoom != 1
            Circle().fill(Stitch.APP_BACKGROUND_COLOR.opacity(0.001))
                .frame(width: 1, height: 1)
                .inspector(isPresented: $store.showsLayerInspector) {
                    
                    LayerInspectorView(graph: graph,
                                       document: document)
                        .inspectorColumnWidth(LayerInspectorView.LAYER_INSPECTOR_WIDTH)
                }
            
            // Added: place "actively dragged edge" view here, so we can sit above the inspector
            // NEED TO SCALE AND OFFSET THE DRAGGED
//            EdgeDrawingView(graph: graph,
//                            edgeDrawingObserver: graph.edgeDrawingObserver)
            
        } // ZStack
        
        .modifier(DetermineEligibleInspectorInputsAndFields(graph: graph,
                                                            scale: document.graphMovement.zoomData))
        
        .coordinateSpace(name: Self.coordinateNamespace)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.frame(in: .local), initial: true) { oldValue, newValue in
                        // log("SIZE READING: GraphBaseView: local frame: newValue: \(newValue)")
                        dispatch(SetDeviceScreenSize(frame: newValue))
                    }
                    .onChange(of: geometry.frame(in: .global), initial: true) { oldValue, newValue in
                        // log("SIZE READING: GraphBaseView: global frame: newValue: \(newValue)")
                        dispatch(SetGraphPosition(graphPosition: newValue.origin))
                        dispatch(SetSidebarWidth(frame: newValue))
                    }
            } // GeometryReader
        } // .background
    }
    
  
}


struct DetermineEligibleInspectorInputsAndFields: ViewModifier {
    
    @Bindable var graph: GraphState
    let scale: CGFloat
    
//    func intersectedWithSize() -> EmptyView {
//        if let nodeId = self.graph.layerNodes().first?.id {
//            DispatchQueue.main.async {
//                dispatch(LayerInputAddedToGraph(nodeId: nodeId, layerInput: .size))
//            }
//        }
//        return EmptyView()
//    }
    
    @MainActor
    func findEligibleInspectorFieldOrRow(_ drawingGesture: EdgeDrawingObserver,
                                         draggedOutputRect: CGRect,
                                         geometry: GeometryProxy,
                                         preferences: [EdgeDraggedToInspector: Anchor<CGRect>]) -> EmptyView {
        
        guard let dragLocation = drawingGesture.drawingGesture?.dragLocation else {
            return EmptyView()
        }
        
        var nearestInspectorInputs = [LayerInputType]()
        
        for preference in preferences {
            if case let .inspectorInputOrField(layerInputType) = preference.key,
               // Note: `areNear` *already* expands the 'hit area'
                areNear(geometry[preference.value].origin,
                        dragLocation) {
                
                log("WAS NEAR: layerInputType: \(layerInputType)")
                nearestInspectorInputs.append(layerInputType)
            }
        } // for preference in ...
        
        if nearestInspectorInputs.isEmpty {
            log("NO inspector inputs/fields")
            DispatchQueue.main.async {
                drawingGesture.nearestEligibleEdgeDestination = nil
            }
        } else if let nearestInspectorInput = nearestInspectorInputs.last {
            log("found inspector input/field: \(nearestInspectorInput)")
            DispatchQueue.main.async {
                drawingGesture.nearestEligibleEdgeDestination = .inspectorInputOrField(nearestInspectorInput)
            }
        }
        
        // Note: unlike `findEligibleCanvasInput`, we don't need to update the port color etc.
                
        return EmptyView()
    }
    
    @MainActor @ViewBuilder
    func body(content: Content) -> some View {
        // TODO: MAY 12: ONLY ACTIVE WHEN WE
        // this fires everytime we have a change ?
        
        // For perf reasons, do not render this view unless we are actively dragging an
//        if let drawingGesture = graph.edgeDrawingObserver.drawingGesture {
        content
            .overlayPreferenceValue(EdgeDraggedToInspectorPreferenceKey.self) { preferences in
                GeometryReader { geometry in
                    if let drawingGesture = graph.edgeDrawingObserver.drawingGesture,
                       let draggedOutputPref = preferences[.draggedOutput(drawingGesture.output.nodeIOCoordinate)] {
                        
                        // Location of dragged edge's end, i.e. user's cursor position
                        let draggedOutputRect: CGRect = geometry[draggedOutputPref]
                        
                        // Render the actively-drawn-edge
                        CurveLine(from: draggedOutputRect.mid,
                                  to: drawingGesture.dragLocation)
                        .stroke(.red,
                                style: StrokeStyle(
                                    // scale DOWN when we're zoomed out, i.e. simply apply the graph scale
                                    lineWidth: LINE_EDGE_WIDTH * scale, //* self.document.graphMovement.zoomData,
                                    lineCap: .round,
                                    lineJoin: .round))
                        
                        findEligibleInspectorFieldOrRow(
                            graph.edgeDrawingObserver,
                            draggedOutputRect: draggedOutputRect,
                            geometry: geometry,
                            preferences: preferences
                        )
                        
                    } // if let draggedOutputPref
                } // GeometryReader
            } // overlayPreferenceValue
//        }
//        
//        // i.e. not actively dragging a layer
//        else {
//            content
//        }
    } // body(content:)
}

/*
  
 logInView("preference: drawingGesture.dragLocation.x: \(drawingGesture.dragLocation.x)")
 logInView("preference: drawingGesture.dragLocation.y: \(drawingGesture.dragLocation.y)")
 
 logInView("preference: draggedOutput.mid.x: \(draggedOutput.mid.x)")
 logInView("preference: draggedOutput.mid.y: \(draggedOutput.mid.y)")
 logInView("preference: draggedOutput.size: \(draggedOutput.size)")
 
 logInView("preference: sizeInput.mid.x: \(sizeInput.mid.x)")
 logInView("preference: sizeInput.mid.y: \(sizeInput.mid.y)")
 logInView("preference: sizeInput.size: \(sizeInput.size)")
 
 logInView("preference: Intersection: \(intersects)")
 

 
 CurveLine(from: draggedOutput.mid,
           to: drawingGesture.dragLocation)
 .stroke(.red,
         style: StrokeStyle(
             // scale DOWN when we're zoomed out, i.e. simply apply the graph scale
             lineWidth: LINE_EDGE_WIDTH * self.document.graphMovement.zoomData,
             
             lineCap: .round,
             lineJoin: .round))
 */

struct GraphHoverViewModifier: ViewModifier {
    @Binding var spaceHeld: Bool
    @Bindable var document: StitchDocumentViewModel
    
    func body(content: Content) -> some View {
        content
#if targetEnvironment(macCatalyst)
            .onHover(perform: { hovering in
                
                // log("GraphBaseView: onHover: hovering: \(hovering)")
                // log("GraphBaseView: onHover: document.keypressState.isSpacePressed: \(document.keypressState.isSpacePressed)")
                // log("GraphBaseView: onHover: self.spaceHeld: \(self.spaceHeld)")
                
                if hovering, self.spaceHeld {
                    NSCursor.openHand.push()
                } else {
                    NSCursor.pop()
                }
            })
        
            .onChange(of: document.keypressState.isSpacePressed, initial: true) { _, newValue in
                // log("GraphBaseView: onChange: keypressState.isSpacePressed: oldValue: \(oldValue)")
                // log("GraphBaseView: onChange: keypressState.isSpacePressed: newValue: \(newValue)")
                
                if newValue {
                    NSCursor.openHand.push()
                } else {
                    NSCursor.pop()
                }
                
                if self.spaceHeld != newValue {
                    self.spaceHeld = newValue
                }
            }
#endif
    }
}
