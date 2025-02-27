//
//  InsertNodeMenuWrapper.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/19/24.
//

import Foundation
import SwiftUI

struct InsertNodeMenuWrapper: View {
    static let menuWidth: CGFloat = INSERT_NODE_MENU_WIDTH
    static let shownMenuScale: CGFloat = 1
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graphUI: GraphUIState
    
    var menuHeight: CGFloat {
        graphUI.nodeMenuHeight
    }
    
    var graphScale: CGFloat {
        graphMovement.zoomData
    }
    
    // menu and animating-node start in middle
    var menuOrigin: CGPoint {
        CGPoint(x: screenWidth/2,
                y: screenHeight/2)
    }
    
    var screenWidth: CGFloat {
        graphUI.frame.width
    }
    
    var screenHeight: CGFloat {
        graphUI.frame.height
    }
    
    private var graphMovement: GraphMovementObserver {
        self.document.graphMovement
    }
    
    // GraphUI properties
    var insertNodeMenuState: InsertNodeMenuState {
        graphUI.insertNodeMenuState
    }
    
    static let shownMenuCornerRadius: CGFloat = 16
    static let hiddenMenuCornerRadius: CGFloat = 60
    
    // We show the modal background when menu is toggled but node-animation has not yet started
    var showModalBackground: Bool {
        graphUI.insertNodeMenuState.show
    }
    
    var graphOffset: CGPoint {
        graphMovement.localPosition
    }
    
    // Used by node-view only
    func getAdjustedMenuOrigin() -> CGPoint {
        // When the menu is shown and the node is hidden,
        // the node needs to be positioned directly underneath the menu;
        // since the node (but not the menu) is affected by graph offset,
        // we need to factor graph offset out of the menuOrigin the node will be using.
        var d = menuOrigin
        d.x -= graphOffset.x
        d.y -= graphOffset.y
        return d
    }
    
    var menuView: some View {
        // InsertNodeMenu should NOT ignore the .keyboard and/or .bottom safe areas
        // however, GeometryReader (used for determining preview window size) SHOULD;
        // so, we need to apply the InsertNodeMenu SwiftUI .modifier after we've ignored safe areas.
        InsertNodeMenuView(
            document: document,
            insertNodeMenuState: insertNodeMenuState,
            isPortraitMode: document.previewWindowSize.isPortrait,
            showMenu: insertNodeMenuState.show,
            menuHeight: menuHeight)
    }
    
    var body: some View {
        ZStack {
            ModalBackgroundGestureRecognizer(dismissalCallback: { dispatch(CloseAndResetInsertNodeMenu()) }) {
                Color.clear
            }
            
            // Insert Node Menu view
            if graphUI.insertNodeMenuState.show {
                menuView
                    .shadow(radius: 4)
                    .shadow(radius: 8, x: 4, y: 2)
                    .animation(.default, value: graphUI.insertNodeMenuState.show)
            }
        }
    }
}
