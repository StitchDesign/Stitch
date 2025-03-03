//
//  OpenFlyoutView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/8/24.
//

import SwiftUI
import Combine
import UIKit

struct OpenFlyoutView: View, KeyboardReadable {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    
    var body: some View {
        if let flyoutState = graph.propertySidebar.flyoutState,
           let node: NodeViewModel = graph.getNodeViewModel(flyoutState.flyoutNode),
           let layerNode: LayerNodeViewModel = node.layerNode,
           let entry = graph.propertySidebar.propertyRowOrigins.get(flyoutState.flyoutInput) {
            
            let flyoutSize = flyoutState.flyoutSize
            
            let portObserver: LayerInputObserver = layerNode[keyPath: flyoutState.flyoutInput.layerNodeKeyPath]
            
            // If pseudo-modal-background placed here,
            // then we disable scroll
            #if DEV_DEBUG || DEBUG
            let pseudoPopoverBackgroundOpacity = 0.1
            #else
            let pseudoPopoverBackgroundOpacity = 0.001
            #endif
            
            ModalBackgroundGestureRecognizer(dismissalCallback: { dispatch(FlyoutClosed()) }) {
                Color.blue.opacity(pseudoPopoverBackgroundOpacity)
            }
            
            let topPadding = graph.propertySidebar.safeAreaTopPadding
              
            // // Apaprently don't need to worry about bottom safe areas of UIKitWrapper ?
            // let bottomPadding = graphUI.propertySidebar.safeAreaBottomPadding
            
            // Place top edge of flyout at top of graph;
            // We subtract half the screen height because we use .offset modifier
            let start = -(document.frame.midY - flyoutSize.height/2)
                        
            // If the bottom edge of the flyout will go past the bottom edge of the screen,
            // move the flyout up a bit.
            let flyoutEndpoint = entry.y + flyoutSize.height // where the flyout's bottom edge would be
            let needsSafeAreaAdjustment = flyoutEndpoint > document.frame.maxY
            let safeAreaAdjustment = needsSafeAreaAdjustment
            ? ((flyoutEndpoint - document.frame.maxY) + FLYOUT_SAFE_AREA_BOTTOM_PADDING + topPadding) // +8 for padding from bottom
            : 0.0
            
            let keyboardAdjustment = (self.keyboardOpen && needsSafeAreaAdjustment) ? 64.0 : 0.0
            
            // Note: the graph's frame itself sits at a certain y-position
            let graphYPositionAdjustment = needsSafeAreaAdjustment ? .zero : graph.graphYPosition
            
            let flyoutPosition = start // move flyout's top edge to top of graph
            + entry.y // move flyout's top edge to row's height
            + topPadding // handle padding added by UIKit wrapper
            - safeAreaAdjustment // move flyout up if its bottom edge would go below graph's bottom edge
            - keyboardAdjustment // move flyout up a bit more if keyboard is open and we're near bottom
            - graphYPositionAdjustment
            
            let flyoutInput: LayerInputPort = flyoutState.flyoutInput
            
            HStack {
                Spacer()
                Group {
                    // Multiple single-field inputs presented in one flyout
                    if flyoutInput == SHADOW_FLYOUT_LAYER_INPUT_PROXY {
                       ShadowFlyoutView(node: node,
                                        layerNode: layerNode,
                                        graph: graph,
                                        graphUI: document)
                    } else if flyoutInput.usesColor {
                        ColorFlyoutView(graph: graph,
                                        rowObserver: portObserver.rowObserver,
                                        layerInputObserver: portObserver,
                                        activeIndex: document.activeIndex)
                    }
                    // One multifield input presented in separate rows in the flyout
                    else {                        
                        // The Flyout takes the whole input,
                        // and displays each field
                        GenericFlyoutView(graph: graph,
                                          graphUI: document,
                                          // packed data ok for for view purposes
                                          rowViewModel: portObserver._packedData.inspectorRowViewModel,
                                          node: node,
                                          layerInputObserver: portObserver,
                                          layer: layerNode.layer,
                                          layerInput: flyoutInput)
                    }
                }
                .offset(
                    x: -LayerInspectorView.LAYER_INSPECTOR_WIDTH // move left
                    - 8, // "padding"
                    
                    y: flyoutPosition
                )
                .onReceive(keyboardPublisher) { value in
                    withAnimation {
                        graph.propertySidebar.flyoutState?.keyboardIsOpen = value
                    }
                }
            }
        }
    }
    
    @MainActor
    var keyboardOpen: Bool {
        graph.propertySidebar.flyoutState?.keyboardIsOpen ?? false
    }
}


// TODO: add debouncer

/// Publisher to read keyboard changes.
protocol KeyboardReadable {
    @MainActor
    var keyboardPublisher: AnyPublisher<Bool, Never> { get }
}

extension KeyboardReadable {
    @MainActor
    var keyboardPublisher: AnyPublisher<Bool, Never> {
        Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .map { _ in
                    true
                },
            
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in
                    false
                }
        )
        .eraseToAnyPublisher()
    }
}

// TODO: consolidate with
struct ModalBackgroundGestureRecognizer<T: View>: UIViewControllerRepresentable {
    
    let dismissalCallback: () -> Void
    @ViewBuilder var view: () -> T

    func makeUIViewController(context: Context) -> GraphGestureBackgroundViewController<T> {
        let vc = GraphGestureBackgroundViewController(
            rootView: view(),
            ignoresSafeArea: true,
            ignoreKeyCommands: true,
            name: "_GraphGestureBackgroundView")

        let delegate = context.coordinator
        
        // Any trackpad or screen pan will close modal
        let screenPanGesture = UIPanGestureRecognizer(
            target: delegate,
            action: #selector(delegate.onGesture))
        screenPanGesture.allowedScrollTypesMask = [.continuous, .discrete]
        screenPanGesture.allowedTouchTypes = [SCREEN_TOUCH_ID, TRACKPAD_TOUCH_ID]
        screenPanGesture.delegate = delegate
        vc.view.addGestureRecognizer(screenPanGesture)
        
        // Tap closes modal
        let tapGesture = UITapGestureRecognizer(
            target: delegate,
            action: #selector(delegate.onGesture))
        tapGesture.delegate = delegate
        vc.view.addGestureRecognizer(tapGesture)
        
        // Pinch closes
        let pinchGesture = UIPinchGestureRecognizer(
            target: delegate,
            action: #selector(delegate.onGesture))
        pinchGesture.delegate = delegate
        vc.view.addGestureRecognizer(pinchGesture)

        return vc
    }

    func updateUIViewController(_ uiViewController: GraphGestureBackgroundViewController<T>, context: Context) {
        uiViewController.rootView = view()
    }

    func makeCoordinator() -> ModalBackgroundGestureDelegate {
        ModalBackgroundGestureDelegate(dismissalCallback: dismissalCallback)
    }
}

class ModalBackgroundGestureDelegate: NSObject, UIGestureRecognizerDelegate {
  
    var dismissalCallback: () -> Void

    init(dismissalCallback: @escaping () -> Void) {
        self.dismissalCallback = dismissalCallback
        super.init()
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
    
    @MainActor
    @objc func onGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        dismissalCallback()
    }
}
