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
        insertNodeMenuState.shouldShowMenu(isLoadingAI: self.isLoadingAIRequest)
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
        guard isLoadingAIRequest else { return 0 }
        
        // Calculate visible height when collapsed (search bar + optional image thumbnail)
        let visibleHeight = INSERT_NODE_MENU_SEARCH_BAR_HEIGHT + 
                           (insertNodeMenuState.droppedImage != nil ? INSERT_NODE_MENU_IMAGE_THUMBNAIL_HEIGHT : 0)
        
        // Offset to keep visible content centered
        return -menuHeight/2 + visibleHeight/2
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
                
                // Padding from top, per Figma
                    .offset(y: 24)
                #if !targetEnvironment(macCatalyst)
                // Note: use to be full y position, not half; changed with different handling of safe areas on iPad OS 26
                    .offset(y: document.visibleGraph.graphYPosition / 2)
                #endif
                
                // Preserve position when we've collapsed the node menu body because of an active AI request
                // Alternatively?: use VStack { menu, Spacer }
                    .offset(y: menuYOffset)
            }
        }
    }
}

struct InsertNodeMenuOffsetModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.offset(y: 62)
        } else {
            content.offset(y: 8)
        }
    }
}
