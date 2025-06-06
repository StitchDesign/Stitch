//
//  InsertNodeMenuWrapper.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/19/24.
//

import Foundation
import SwiftUI

struct InsertNodeMenuWithModalBackground: View {
    static let menuWidth: CGFloat = INSERT_NODE_MENU_WIDTH
    
    @Bindable var document: StitchDocumentViewModel
    
    var insertNodeMenuState: InsertNodeMenuState {
        document.insertNodeMenuState
    }
    
    var menuHeight: CGFloat {
        document.nodeMenuHeight
    }
    
    static let shownMenuCornerRadius: CGFloat = 20 // per Figma
    
    var showMenu: Bool {
        insertNodeMenuState.show || self.isLoadingAIRequest
    }
    
    var menuView: some View {
        // InsertNodeMenu should NOT ignore the .keyboard and/or .bottom safe areas
        // however, GeometryReader (used for determining preview window size) SHOULD;
        // so, we need to apply the InsertNodeMenu SwiftUI .modifier after we've ignored safe areas.
        InsertNodeMenuView(
            document: document,
            insertNodeMenuState: insertNodeMenuState,
            isPortraitMode: document.previewWindowSize.isPortrait,
            showMenu: showMenu,
            menuHeight: menuHeight)
    }
    
    var isLoadingAIRequest: Bool {
        document.isLoadingAI
    }
    
    var menuYOffset: CGFloat {
        isLoadingAIRequest
        ? (-menuHeight/2 + INSERT_NODE_MENU_SEARCH_BAR_HEIGHT/2)
        : 0
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            ModalBackgroundGestureRecognizer(dismissalCallback: { dispatch(CloseAndResetInsertNodeMenu()) }) {
                Color.clear
            }
            // Disable gestures that would otherwise block graph interaction during an AI request
            .disabled(isLoadingAIRequest)
            
            // Insert Node Menu view
            if showMenu {
                
                menuView
                    .shadow(radius: 4)
                    .shadow(radius: 8, x: 4, y: 2)
                    .animation(.default, value: document.insertNodeMenuState.show)
                    .animation(.default, value: isLoadingAIRequest)
                    
                #if targetEnvironment(macCatalyst)
                // Padding from top, per Figma
                    .offset(y: 24)
                #else
                // TODO: why does this differ for Catalyst vs iPad ?
//                    .offset(y: 48)
//                    .offset(y: 12)
                    .offset(y: 8)
                    .offset(y: document.visibleGraph.graphYPosition)
                #endif
                
                // Preserve position when we've collapsed the node menu body because of an active AI request
                // Alternatively?: use VStack { menu, Spacer }
                    .offset(y: menuYOffset)
            }
        }
    }
}
