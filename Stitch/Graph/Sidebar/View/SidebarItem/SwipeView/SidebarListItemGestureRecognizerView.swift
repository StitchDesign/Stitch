//
//  _SidebarListItemGestureRecognizerView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import Foundation
import SwiftUI
import UIKit

// CGFloat: height if for item-drag; width if for item-swipe
typealias OnDragChangedHandler = (CGFloat) -> Void
typealias OnDragChangedWithVelocityHandler = (CGFloat, CGPoint) -> Void

typealias OnDragEndedHandler = () -> Void

// dragging an item is both vertical and horizontal,
// so need to pass in CGSize
typealias OnItemDragChangedHandler = (CGSize) -> Void

// Gesture Recognizer attached to the Item itself,
// to detect trackpad 2-finger pans (for swipe)
// or trackpad click + drag (for immediate item dragging)

// a gesture recognizer for the item in the custom list itself
struct SidebarListItemGestureRecognizerView<T: View>: UIViewControllerRepresentable {
    let view: T
    @ObservedObject var gestureViewModel: SidebarItemGestureViewModel

    var instantDrag: Bool = false
    
    var graph: GraphState
    var layerNodeId: LayerNodeId

    func makeUIViewController(context: Context) -> GestureHostingController<T> {
        let vc = GestureHostingController(
            rootView: view,
            ignoresSafeArea: false,
            ignoreKeyCommands: true,
            name: "SidebarListItemGestureRecognizerView")

        let delegate = context.coordinator

        let screenTouch = NSNumber(value: UITouch.TouchType.direct.rawValue)
        let trackpadTouch = NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)

        let screenPanGesture = UIPanGestureRecognizer(
            target: delegate,
            action: #selector(delegate.screenGestureHandler))
        screenPanGesture.allowedScrollTypesMask = [.continuous, .discrete]
        // uses screen; ignore trackpad
        screenPanGesture.allowedTouchTypes = [screenTouch]
        screenPanGesture.delegate = delegate
        vc.view.addGestureRecognizer(screenPanGesture)

        let trackpadPanGesture = UIPanGestureRecognizer(
            target: delegate,
            action: #selector(delegate.trackpadGestureHandler))
        trackpadPanGesture.allowedScrollTypesMask = [.continuous, .discrete]
        // ignore screen; uses trackpad
        trackpadPanGesture.allowedTouchTypes = [trackpadTouch]
        trackpadPanGesture.delegate = delegate
        vc.view.addGestureRecognizer(trackpadPanGesture)

        // Use a UIKit UIContextMenuInteraction so that we can detect when contextMenu opens
        #if targetEnvironment(macCatalyst)
        // We define the
        let interaction = UIContextMenuInteraction(delegate: delegate)
        vc.view.addInteraction(interaction)
        #endif
        
        vc.delegate = delegate
        return vc
    }

    func updateUIViewController(_ uiViewController: GestureHostingController<T>, context: Context) {
        let delegate = context.coordinator
        uiViewController.rootView = view

        delegate.instantDrag = instantDrag
        
        delegate.graph = graph
        delegate.layerNodeId = layerNodeId
    }

    func makeCoordinator() -> SidebarListGestureRecognizer {
        SidebarListGestureRecognizer(
            gestureViewModel: gestureViewModel,
            instantDrag: instantDrag,
            graph: graph,
            layerNodeId: layerNodeId)
    }
}
//
//
//// THIS IS NOT FOR A RIGHT CLICK VIA TRACKPAD
////class RightClickGestureRecognizer: UIGestureRecognizer {
//extension UIGestureRecognizer {
//    func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
//        log("UIGestureRecognizer: touchesBegan CALLED")
//        if let touch = touches.first,
//            touch.type == .indirectPointer {
//            // Handle right-click or secondary click here
//            if touch.tapCount == 1 && touch.phase == .began {
//                print("Right click detected!")
//            }
//        }
//    }
//}


final class SidebarListGestureRecognizer: NSObject, UIGestureRecognizerDelegate {
    // Handles:
    // - one finger on screen item-swiping
    // - two fingers on trackpad item-swiping
    // - click on trackpad item-dragging

    // Handled elsewhere:
    // - one finger long-press-drag item-dragging: see `SwiftUI .simultaneousGesture`
    // - two fingers on trackpad list scrolling

    let gestureViewModel: SidebarItemGestureViewModel

    var instantDrag: Bool
    
    var graph: GraphState
    var layerNodeId: LayerNodeId

    init(gestureViewModel: SidebarItemGestureViewModel,
         instantDrag: Bool,
         graph: GraphState,
         layerNodeId: LayerNodeId) {
        
        self.gestureViewModel = gestureViewModel
        self.instantDrag = instantDrag
        
        self.graph = graph
        self.layerNodeId = layerNodeId
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
    
//    func touchesBegan

    // finger on screen
    @objc func screenGestureHandler(_ gestureRecognizer: UIPanGestureRecognizer) {

        // for finger on screen, we'll still use long press + drag for item-dragging;
        // so we'll still use a SwiftUI long-press-drag gesture
        // (unless we accidentally trigger both, via trackpad?)

        let translation = gestureRecognizer.translation(in: gestureRecognizer.view)

        // one finger on screen: can be item-drag or item-swipe;
        // since SwiftUI was doing both via simultaneous gestures,
        // just call both handlers here

        if gestureRecognizer.numberOfTouches == 1 {
            switch gestureRecognizer.state {
            case .changed:

                if instantDrag {
                    gestureViewModel.onItemDragChanged(translation.toCGSize)
                }
                let velocity = gestureRecognizer.velocity(in: gestureRecognizer.view)
                gestureViewModel.onItemSwipeChanged(translation.x)
            default:
                break // do nothing
            }
        }

        // When the finger-on-the-screen gesture is ended or cancelled, touches=0
        else if gestureRecognizer.numberOfTouches == 0 {
            //            log("CustomListItemGestureRecognizerVC: screenGestureHandler: 0 touches ")
            switch gestureRecognizer.state {
            case .ended, .cancelled:
                if instantDrag {
                    gestureViewModel.onItemDragEnded()
                }
                gestureViewModel.onItemSwipeEnded()
            default:
                break
            }
        }
        //        else {
        //            log("CustomListItemGestureRecognizerVC: screenGestureHandler: incorrect number of touches; will do nothing")
        //        }

    } // screenGestureHandler
    
    @objc func trackpadGestureHandler(_ gestureRecognizer: UIPanGestureRecognizer) {

        //        log("CustomListItemGestureRecognizerVC: trackpadGestureHandler: gestureRecognizer.numberOfTouches:  \(gestureRecognizer.numberOfTouches)")

        let translation = gestureRecognizer.translation(in: gestureRecognizer.view)

        // when we have clicked+dragged, and then let up our finger,
        // is that a touches=0 gesture?

        // `touches == 0` = running our fingers on trackpad, but no click
        if gestureRecognizer.numberOfTouches == 0 {
            
                        
            switch gestureRecognizer.state {
            case .changed:
                gestureViewModel.onItemSwipeChanged(translation.x)
                let velocity = gestureRecognizer.velocity(in: gestureRecognizer.view)
            case .ended, .cancelled:
                gestureViewModel.onItemSwipeEnded()
                gestureViewModel.onItemDragEnded()
            default:
//                log("CustomListItemGestureRecognizerVC: touches 0: trackpadGestureHandler: default")
                break
            }
        }

        // `touches == 1` = click + drag
        else if gestureRecognizer.numberOfTouches == 1 {
            switch gestureRecognizer.state {
            case .changed:
                gestureViewModel.onItemDragChanged(translation.toCGSize)
            default:
                // log("CustomListItemGestureRecognizerVC: trackpadGestureHandler: default")
                break
            }
        }
    } // trackpadGestureHandler
}



extension SidebarListGestureRecognizer: UIContextMenuInteractionDelegate {
        
    // // Not needed, since the required `contextMenuInteraction` delegate method is called every time the menu appears?
    //    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willDisplayMenuFor configuration: UIContextMenuConfiguration, animator: (any UIContextMenuInteractionAnimating)?) {
    //        log("UIContextMenuInteractionDelegate: contextMenuInteraction: WILL DISPLAY MENU")
    //    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, 
                                configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        log("UIContextMenuInteractionDelegate: contextMenuInteraction")
        
        // Do the selection action in here
        
        // Only select the layer if not already actively-selected; otherwise just open the menu
//        if !self.graph.sidebarSelectionState.inspectorFocusedLayers.activelySelected.contains(self.layerNodeId) {
//            
//            self.graph.sidebarItemTapped(
//                id: self.layerNodeId,
//                // TODO: SEPT 20: PASS THIS DOWN
//                shiftHeld: false)
//        }
//                
        let selections = self.graph.sidebarSelectionState
        let groups = self.graph.getSidebarGroupsDict()
        let sidebarDeps =  SidebarDeps(layerNodes: .fromLayerNodesDict( nodes: self.graph.layerNodes, orderedSidebarItems: self.graph.orderedSidebarLayers),
                                       groups: groups,
                                       expandedItems: self.graph.getSidebarExpandedItems())
        let layerNodes = sidebarDeps.layerNodes
        
        let primary = selections.primary
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
        
            var buttons: [UIMenuElement] = []
            
            if canUngroup(primary, nodes: layerNodes) {
                buttons.append(UIAction(title: "Ungroup", image: nil) { action in
                    // Handle action here
                    dispatch(SidebarGroupUncreated())
                })
            }
            
            let canGroup = primary.nonEmptyPrimary.map { canBeGrouped($0, groups: groups) } ?? false
            if canGroup {
                buttons.append(UIAction(title: "Group", image: nil) { action in
                    dispatch(SidebarGroupCreated())
                })
            }
            
            if canDuplicate(primary) {
                let groupButton = UIAction(title: "Duplicate", image: nil) { action in
                    dispatch(SidebarSelectedItemsDuplicated())
                }
                buttons.append(groupButton)
            }
            
            if !selections.all.isEmpty {
                buttons.append(UIAction(title: "Delete", image: nil) { action in
                    dispatch(SidebarSelectedItemsDeleted())
                })
            }
                        
            return UIMenu(title: "", children: buttons)
        }
    }
}
