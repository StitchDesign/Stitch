//
//  _SidebarListItemGestureRecognizerView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import Foundation
import SwiftUI
import UIKit
import GameController

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
                                            SidebarViewModel: ProjectSidebarObservable>: UIViewControllerRepresentable {
    private let keyboardObserver = GCKeyboard.coalesced

    let view: T
    @Bindable var sidebarViewModel: SidebarViewModel
    @Bindable var gestureViewModel: SidebarViewModel.ItemViewModel
    
    var instantDrag: Bool = false
    
    var itemId: SidebarViewModel.ItemID {
        gestureViewModel.id
    }

    func makeUIViewController(context: Context) -> GestureHostingController<T> {
        let vc = GestureHostingController(
            rootView: view,
            ignoresSafeArea: false,
            ignoreKeyCommands: true,
            inputTextFieldFocused: false, // N/A
            name: .sidebarListItem)

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
        delegate.gestureViewModel = gestureViewModel
        delegate.sidebarViewModel = sidebarViewModel
        delegate.itemId = itemId
    }

    func makeCoordinator() -> SidebarListGestureRecognizer<SidebarViewModel> {
        SidebarListGestureRecognizer<SidebarViewModel>(
            gestureViewModel: gestureViewModel,
            sidebarViewModel: sidebarViewModel,
            instantDrag: instantDrag,
            itemId: itemId)
    }
}

final class SidebarListGestureRecognizer<SidebarViewModel: ProjectSidebarObservable>: NSObject, UIGestureRecognizerDelegate, UIContextMenuInteractionDelegate {
    // Handles:
    // - one finger on screen item-swiping
    // - two fingers on trackpad item-swiping
    // - click on trackpad item-dragging

    // Handled elsewhere:
    // - one finger long-press-drag item-dragging: see `SwiftUI .simultaneousGesture`
    // - two fingers on trackpad list scrolling
    
    var instantDrag: Bool
    
    var itemId: SidebarViewModel.ItemID
    
    var shiftHeldDown = false
    var commandHeldDown = false

    weak var sidebarViewModel: SidebarViewModel?
    weak var gestureViewModel: SidebarViewModel.ItemViewModel?

    init(gestureViewModel: SidebarViewModel.ItemViewModel,
         sidebarViewModel: SidebarViewModel,
         instantDrag: Bool,
         itemId: SidebarViewModel.ItemID) {
        self.sidebarViewModel = sidebarViewModel
        self.gestureViewModel = gestureViewModel
        self.instantDrag = instantDrag
        self.itemId = itemId
    }
    
    var graph: GraphState? {
        self.sidebarViewModel?.graphDelegate
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                           shouldReceive event: UIEvent) -> Bool {
        if event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.alphaShift) {
            self.shiftHeldDown = true
        } else {
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
              let gestureViewModel = self.gestureViewModel,
              let graph = self.sidebarViewModel?.graphDelegate,
              let document = graph.documentDelegate else { return }
        
        if sidebarViewModel.isEditing || gestureViewModel.swipeSetting == .open {
            return
        }
        
        self.sidebarViewModel?.sidebarItemTapped(id: self.itemId,
                                                 shiftHeld: self.shiftHeldDown,
                                                 commandHeld: self.commandHeldDown,
                                                 graph: graph,
                                                 document: document)
    }
    
    // finger on screen
    @objc func screenGestureHandler(_ gestureRecognizer: UIPanGestureRecognizer) {
        
        guard let sidebar = self.sidebarViewModel else { return }

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
                    gestureViewModel?.onItemDragChanged(sidebar: sidebar)(translation.toCGSize)
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
                    gestureViewModel?.onItemDragEnded(sidebar: sidebar)()
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

        guard let sidebar = self.sidebarViewModel else { return }

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
                gestureViewModel?.onItemDragEnded(sidebar: sidebar)()
            default:
//                log("CustomListItemGestureRecognizerVC: touches 0: trackpadGestureHandler: default")
                break
            }
        }

        // `touches == 1` = click + drag
        else if gestureRecognizer.numberOfTouches == 1 {
            switch gestureRecognizer.state {
            case .changed:
                gestureViewModel?.onItemDragChanged(sidebar: sidebar)(translation.toCGSize)
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
        guard let graph = self.graph,
              let document = graph.documentDelegate else {
            return nil
        }
        return self.gestureViewModel?
            .contextMenuInteraction(itemId: self.itemId,
                                    graph: graph,
                                    document: document)
    }
}

extension SidebarItemGestureViewModel {
    @MainActor
    func contextMenuInteraction(itemId: SidebarListItemId,
                                graph: GraphState,
                                document: StitchDocumentViewModel) -> UIContextMenuConfiguration? {
        // log("UIContextMenuInteractionDelegate: contextMenuInteraction")
        
        guard let sidebarViewModel = self.sidebarDelegate else { return nil }
        let selections = sidebarViewModel.selectionState
        let keyboard = GCKeyboard.coalesced
                
        // Only select the layer if not already actively-selected; otherwise just open the menu
        if !selections.primary.contains(itemId) {
            
            let isShiftDown = keyboard?.keyboardInput?.isShiftPressed ?? false
            
            // Note: we do the selection logic in here so that
            self.sidebarDelegate?.sidebarItemTapped(
                id: itemId,
                shiftHeld: isShiftDown,
                commandHeld: document.keypressState.isCommandPressed,
                graph: graph,
                document: document)
        }
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak graph] _ in
            guard let graph = graph else { return UIMenu(title: "", children: []) }
            
            var buttons: [UIMenuElement] = []
            
            if sidebarViewModel.canUngroup() {
                buttons.append(UIAction(title: "Ungroup", image: nil) { action in
                    // Handle action here
                    self.sidebarDelegate?.sidebarGroupUncreated()
                })
            }
            
            if sidebarViewModel.canBeGrouped() {
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
            
            let activeSelections = graph.sidebarSelectionState.primary
            
            let atLeastOneSelected = !activeSelections.isEmpty
            
            if atLeastOneSelected {
                buttons.append(UIAction(title: "Delete", image: nil) { action in
                    dispatch(SidebarSelectedItemsDeleted())
                })
            }
                      
            let onlyOneSelected = activeSelections.count == 1
            
            if onlyOneSelected,
               let layerNodeId = selections.primary.first,
               let isVisible = graph.getLayerNode(id: layerNodeId)?.layerNode?.hasSidebarVisibility {
                
                buttons.append(UIAction(title: isVisible ? "Hide Layer" : "Unhide Layer", image: nil) { action in
                    dispatch(SidebarItemHiddenStatusToggled(clickedId: layerNodeId))
                })
            }
            
            if activeSelections.count > 1 {
                buttons.append(UIAction(title: "Hide Layers", image: nil) { action in
                    dispatch(SelectedLayersVisiblityUpdated(selectedLayers: selections.primary,
                                                            newVisibilityStatus: false))
                })
                
                buttons.append(UIAction(title: "Unhide Layers", image: nil) { action in
                    dispatch(SelectedLayersVisiblityUpdated(selectedLayers: selections.primary,
                                                            newVisibilityStatus: true))
                })
            }
            
            
            return UIMenu(title: "", children: buttons)
        }
    }
}
