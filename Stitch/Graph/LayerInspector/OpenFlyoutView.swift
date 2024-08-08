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
    @Bindable var graph: GraphState
    
    var body: some View {
        if let flyoutState = graph.graphUI.propertySidebar.flyoutState,
           let node = graph.getNodeViewModel(flyoutState.input.nodeId),
           let layerNode = node.layerNode,
           let entry = graph.graphUI.propertySidebar.propertyRowOrigins.get(flyoutState.flyoutInput) {
            
            let flyoutSize = flyoutState.flyoutSize
            let inputData = layerNode[keyPath: flyoutState.flyoutInput.layerNodeKeyPath]
            
            // If pseudo-modal-background placed here,
            // then we disable scroll
            #if DEV_DEBUG || DEBUG
            let pseudoPopoverBackgroundOpacity = 0.1
            #else
            let pseudoPopoverBackgroundOpacity = 0.001
            #endif
            
            Color.blue.opacity(pseudoPopoverBackgroundOpacity)
            // SwiftUI native .popover disables scroll; probably best solution here.
            // .offset(x: -LayerInspectorView.LAYER_INSPECTOR_WIDTH)
                .onTapGesture {
                    dispatch(FlyoutClosed())
                }
            
            let topPadding = graph.graphUI.propertySidebar.safeAreaTopPadding
              
            // // Apaprently don't need to worry about bottom safe areas of UIKitWrapper ?
            // let bottomPadding = graph.graphUI.propertySidebar.safeAreaBottomPadding
            
            // Place top edge of flyout at top of graph;
            // We subtract half the screen height because we use .offset modifier
            let start = -(graph.graphUI.frame.midY - flyoutSize.height/2)
                        
            // If the bottom edge of the flyout will go past the bottom edge of the screen,
            // move the flyout up a bit.
            let flyoutEndpoint = entry.y + flyoutSize.height // where the flyout's bottom edge would be
            let needsSafeAreaAdjustment = flyoutEndpoint > graph.graphUI.frame.maxY
            let safeAreaAdjustment = needsSafeAreaAdjustment
            ? ((flyoutEndpoint - graph.graphUI.frame.maxY) + FLYOUT_SAFE_AREA_BOTTOM_PADDING + topPadding) // +8 for padding from bottom
            : 0.0
            
            let keyboardAdjustment = (self.keyboardOpen && needsSafeAreaAdjustment) ? 64.0 : 0.0
            
            let flyoutPosition = start // move flyout's top edge to top of graph
            + entry.y // move flyout's top edge to row's height
            + topPadding // handle padding added by UIKit wrapper
            - safeAreaAdjustment // move flyout up if its bottom edge would go below graph's bottom edge
            - keyboardAdjustment // move flyout up a bit more if keyboard is open and we're near bottom
            
            HStack {
                Spacer()
                Group {
                    if flyoutState.flyoutInput == .padding {
                        PaddingFlyoutView(graph: graph,
                                          rowViewModel: inputData.inspectorRowViewModel,
                                          layer: layerNode.layer,
                                          hasIncomingEdge: inputData.rowObserver.containsUpstreamConnection)
                    } else if flyoutState.flyoutInput == SHADOW_FLYOUT_LAYER_INPUT_PROXY {
                        ShadowFlyoutView(node: node,
                                         layerNode: layerNode,
                                         graph: graph)
                    }
                }
                .offset(
                    x: -LayerInspectorView.LAYER_INSPECTOR_WIDTH // move left
                    - 8, // "padding"
                    
                    y: flyoutPosition
                )
                .onReceive(keyboardPublisher) { value in
                    withAnimation {
                        graph.graphUI.propertySidebar.flyoutState?.keyboardIsOpen = value
                    }
                }
            }
        }
    }
    
    @MainActor
    var keyboardOpen: Bool {
        graph.graphUI.propertySidebar.flyoutState?.keyboardIsOpen ?? false
    }
}



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
