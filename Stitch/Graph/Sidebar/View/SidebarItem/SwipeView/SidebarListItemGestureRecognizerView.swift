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
struct SidebarListItemGestureRecognizerView<T: View,
                                            GestureViewModel: SidebarItemSwipable>: UIViewControllerRepresentable {
    @EnvironmentObject private var keyboardObserver: KeyboardObserver

    let view: T
    @Bindable var sidebarViewModel: GestureViewModel.SidebarViewModel
    @Bindable var gestureViewModel: GestureViewModel
    
    var instantDrag: Bool = false
    
    let graph: GraphState
    
    var itemId: GestureViewModel.ItemID {
        gestureViewModel.id
    }

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

        let tapGesture = UITapGestureRecognizer(
            target: delegate,
            action: #selector(delegate.tapInView))
        tapGesture.delegate = delegate
        vc.view.addGestureRecognizer(tapGesture)
        
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
        delegate.itemId = itemId
    }

    func makeCoordinator() -> SidebarListGestureRecognizer<GestureViewModel> {
        SidebarListGestureRecognizer<GestureViewModel>(
            gestureViewModel: gestureViewModel,
            sidebarViewModel: sidebarViewModel,
            keyboardObserver: keyboardObserver,
            instantDrag: instantDrag,
            graph: graph,
            itemId: itemId)
    }
}

final class SidebarListGestureRecognizer<GestureViewModel: SidebarItemSwipable>: NSObject, UIGestureRecognizerDelegate, UIContextMenuInteractionDelegate {
    // Handles:
    // - one finger on screen item-swiping
    // - two fingers on trackpad item-swiping
    // - click on trackpad item-dragging

    // Handled elsewhere:
    // - one finger long-press-drag item-dragging: see `SwiftUI .simultaneousGesture`
    // - two fingers on trackpad list scrolling
    
    var instantDrag: Bool
    
    var graph: GraphState
    var itemId: GestureViewModel.ItemID
    
    var shiftHeldDown = false
    var commandHeldDown = false

    weak var sidebarViewModel: GestureViewModel.SidebarViewModel?
    weak var gestureViewModel: GestureViewModel?
    weak var keyboardObserver: KeyboardObserver?

    init(gestureViewModel: GestureViewModel,
         sidebarViewModel: GestureViewModel.SidebarViewModel,
         keyboardObserver: KeyboardObserver,
         instantDrag: Bool,
         graph: GraphState,
         itemId: GestureViewModel.ItemID) {
        
        self.gestureViewModel = gestureViewModel
        self.keyboardObserver = keyboardObserver
        self.instantDrag = instantDrag
        
        self.graph = graph
        self.itemId = itemId
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                           shouldReceive event: UIEvent) -> Bool {
        if event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.alphaShift) {
            log("SHIFT DOWN")
            self.shiftHeldDown = true
        } else {
            log("SHIFT NOT DOWN")
            self.shiftHeldDown = false
        }
        
        if event.modifierFlags.contains(.command) {
            self.commandHeldDown = true
        } else {
            self.commandHeldDown = false
        }
        
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
      
    @objc func tapInView(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let sidebarViewModel = self.sidebarViewModel,
              let gestureViewModel = self.gestureViewModel else { return }
        
        if sidebarViewModel.isEditing || gestureViewModel.swipeSetting == .open {
            return
        }
        
        gestureViewModel.sidebarItemTapped(id: self.itemId,
                                           shiftHeld: self.shiftHeldDown,
                                           commandHeld: self.commandHeldDown)
    }
    
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
                    gestureViewModel?.onItemDragChanged(translation.toCGSize)
                }
                // let velocity = gestureRecognizer.velocity(in: gestureRecognizer.view)
                gestureViewModel?.onItemSwipeChanged(translation.x)
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
                    gestureViewModel?.onItemDragEnded()
                }
                gestureViewModel?.onItemSwipeEnded()
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
                gestureViewModel?.onItemSwipeChanged(translation.x)
                // let velocity = gestureRecognizer.velocity(in: gestureRecognizer.view)
            case .ended, .cancelled:
                gestureViewModel?.onItemSwipeEnded()
                gestureViewModel?.onItemDragEnded()
            default:
//                log("CustomListItemGestureRecognizerVC: touches 0: trackpadGestureHandler: default")
                break
            }
        }

        // `touches == 1` = click + drag
        else if gestureRecognizer.numberOfTouches == 1 {
            switch gestureRecognizer.state {
            case .changed:
                gestureViewModel?.onItemDragChanged(translation.toCGSize)
            default:
                // log("CustomListItemGestureRecognizerVC: trackpadGestureHandler: default")
                break
            }
        }
    } // trackpadGestureHandler
    
    // // NOTE: Not needed, since the required `contextMenuInteraction` delegate method is called every time the menu appears?
    //    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willDisplayMenuFor configuration: UIContextMenuConfiguration, animator: (any UIContextMenuInteractionAnimating)?) {
    //        log("UIContextMenuInteractionDelegate: contextMenuInteraction: WILL DISPLAY MENU")
    //    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        if let keyboardObserver = self.keyboardObserver {
            self.gestureViewModel?.contextMenuInteraction(itemId: self.itemId,
                                                          graph: self.graph,
                                                          keyboardObserver: keyboardObserver)
        }
    }
}

extension SidebarItemGestureViewModel {
    @MainActor
    func contextMenuInteraction(itemId: SidebarListItemId,
                                graph: GraphState,
                                keyboardObserver: KeyboardObserver) -> UIContextMenuConfiguration? {
        // log("UIContextMenuInteractionDelegate: contextMenuInteraction")
        
        guard let sidebarViewModel = self.sidebarDelegate else { return nil }
        let selections = sidebarViewModel.selectionState
                
        // Only select the layer if not already actively-selected; otherwise just open the menu
        if !selections.inspectorFocusedLayers.activelySelected.contains(itemId.asLayerNodeId) {
            
            let isShiftDown = keyboardObserver.keyboard?.keyboardInput?.isShiftPressed ?? false
            
            // Note: we do the selection logic in here so that
            self.sidebarItemTapped(
                id: itemId,
                shiftHeld: isShiftDown,
                commandHeld: graph.keypressState.isCommandPressed)
        }
                
//        let groups = sidebarViewModel.getSidebarGroupsDict()
//        let sidebarDeps = SidebarDeps(layerNodes: .fromLayerNodesDict( nodes: graph.layerNodes, orderedSidebarItems: graph.orderedSidebarLayers),
//        let sidebarDeps = SidebarDeps(groups: groups,
//                                      expandedItems: graph.getSidebarExpandedItems())
//        let layerNodes = sidebarDeps.layerNodes
        
        let primary = selections.primary
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
        
            var buttons: [UIMenuElement] = []
            
            if sidebarViewModel.canUngroup() {
                buttons.append(UIAction(title: "Ungroup", image: nil) { action in
                    // Handle action here
                    dispatch(SidebarGroupUncreated())
                })
            }
            
            let canGroup = primary.nonEmptyPrimary.map { sidebarViewModel.canBeGrouped() } ?? false
            if canGroup {
                buttons.append(UIAction(title: "Group", image: nil) { action in
                    sidebarViewModel.sidebarGroupCreated()
                })
            }
            
            if sidebarViewModel.canDuplicate() {
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

import GameController

// Note: a global GameController observer seems to be an accurate way to listen for Shift etc. key presses
// TODO: use this approach more widely?
class KeyboardObserver: ObservableObject {
    @Published var keyboard: GCKeyboard?
    
    var observer: Any? = nil
    
    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .GCKeyboardDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // TODO: warning about capture of `self` ?
            self?.keyboard = notification.object as? GCKeyboard
        }
    }
}
