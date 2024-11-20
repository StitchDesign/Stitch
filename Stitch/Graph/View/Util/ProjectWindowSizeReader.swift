//
//  ProjectWindowSizeReader.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/1/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit


struct NodeMenuHeightSet: GraphUIEvent {
    let newHeight: CGFloat
    
    func handle(state: GraphUIState) {
        state.nodeMenuHeight = newHeight
    }
}

import GameController

/// Uses `GeometryReader` to process screen size changes for the prototype preview window.
struct ProjectWindowSizeReader: View {
    let previewWindowSizing: PreviewWindowSizing
    let previewWindowSize: CGSize
    let isFullScreen: Bool
    @Binding var showFullScreenAnimateCompleted: Bool
    let showFullScreenObserver: AnimatableBool

//    @Binding var menuHeight: CGFloat
    let menuHeight: CGFloat
//    @Binding var screenSize: CGSize

    let menuAnimatingToNode: Bool

    @State private var defaultLandscapeSize: CGSize?

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear {

                    // log("SIZE READING: ProjectWindowSizeReader: onAppear: geometry.size: \(geometry.size)")

//                    screenSize = geometry.size

                    if geometry.size.isLandscape {
                        self.defaultLandscapeSize = geometry.size
                    }

                    self.previewWindowSizing.previewWindowDeviceSize = previewWindowSize
                    self.previewWindowSizing.userDeviceSize = geometry.size

                    // Creates full screen animation effect for iPhone experience
                    if isFullScreen {
                        showFullScreenAnimateCompleted = false
                        withAnimation(.stitchAnimation) {
                            showFullScreenObserver.update(true)
                        }
                    }
                }

                // TODO: if we want to resize the prototype window when Mac app window or iOS device orientation changes, decide how to coorindate that with user's manual-drag changes of prototype window size.
                // Listener here needed for repainting the view after a device orientation change
                .onChange(of: geometry.size) { oldValue, newValue in

                    //// log("ProjectWindowSizeReader: onChange of: geometry.size: \(geometry.size)")
                    // log("SIZE READING: ProjectWindowSizeReader: onChange of: oldValue: \(oldValue)")
                    // log("SIZE READING: ProjectWindowSizeReader: onChange of: newValue: \(newValue)")

                    if isFullScreen {
                        // log("ProjectWindowSizeReader: onChange of: geometry.size: we are fullscreen, so will update previewWindowSizing")
                        self.previewWindowSizing.userDeviceSize = geometry.size
                    }

                    // TODO: not necessary?
                    if menuAnimatingToNode {
                        // log("ProjectWindowSizeReader: animating to node; will not change size")
                        return
                    }

                    // TODO: ignore geometry changes when magic keyboard attached, so that we don't "slightly move up" the insert node menu?
//                    screenSize = geometry.size

                    if !self.defaultLandscapeSize.isDefined,
                       geometry.size.isLandscape {
                        self.defaultLandscapeSize = geometry.size
                    }

                    // If we're in landscape mode,
                    // and we're less than our defaultSize.height,
                    // then we use the MINIMUM HEIGHT for the node menu,
                    if geometry.size.isLandscape,
                       let defaultLandscapeSize = self.defaultLandscapeSize,
                       // TODO: figure out how to ignore the small change from magic keyboard ?
                       geometry.size.height < defaultLandscapeSize.height {

                        // log("ProjectWindowSizeReader: onChange of: geometry.size: setting min height: geometry.size.height: \(geometry.size.height)")

                        // log("ProjectWindowSizeReader: onChange of: geometry.size: setting min height: defaultLandscapeSize.height: \(defaultLandscapeSize.height)")

                        let heightDiff = defaultLandscapeSize.height - geometry.size.height

                        // log("ProjectWindowSizeReader: onChange of: geometry.size: setting min height: heightDiff: \(heightDiff)")

                        /*
                         EXAMPLE:

                         Default landscape height on an 11” iPad Pro = 834

                         Height when Full screen KB = 332
                         So diff = 834 - 332 = 502

                         Height when non-FS KB = 740
                         So diff = 834 - 740 = 94

                         Height when Magic Keyboard attached = 691
                         So diff = 834 - 691 = 143
                         */
                        // TODO: test on iPad Mini etc.
                        // TODO: why were we getting 299 vs 300 vs ... ?
                        //                        if heightDiff.magnitude > 300 {
                        
                        let heightDiffMag = heightDiff.magnitude
                        
                        if heightDiff.magnitude > 295 {
                             // log("ProjectWindowSizeReader: onChange of: geometry.size: setting to min height")
                            //menuHeight = INSERT_NODE_MENU_MIN_HEIGHT
                            dispatch(NodeMenuHeightSet(newHeight: INSERT_NODE_MENU_MIN_HEIGHT))

                            // TODO: only adjust screen size if geometry changed enough to change the menu's height? Be careful about e.g. maybe us wanting to move up the menu when in portrait mode.
                            // screenHeight = geometry.size.height

                        } else {
                             // log("ProjectWindowSizeReader: onChange of: geometry.size: diff not big enough")
                            //menuHeight = INSERT_NODE_MENU_MAX_HEIGHT
                            dispatch(NodeMenuHeightSet(newHeight: INSERT_NODE_MENU_MAX_HEIGHT))
                        }
                    }

                    // Needed when e.g. keyboard dimissed?
                    // or we rotate the device, e.g. into portrait mode?
                    else {
                         // log("ProjectWindowSizeReader: onChange of: geometry.size: setting to max height again")
//                        menuHeight = INSERT_NODE_MENU_MAX_HEIGHT
                        dispatch(NodeMenuHeightSet(newHeight: INSERT_NODE_MENU_MAX_HEIGHT))
                    }
                }
            // TODO: why does this logic live here? we're changing some ephemeral parts of preview-window data (size etc.) in a reader that's mostly about user-device-screen changes (e.g. keyboard, rotation) ?
                // i.e. when user changes preview window size via settings menu
                .onChange(of: previewWindowSize) { (newWindowSize: CGSize) in
                    
                    self.previewWindowSizing.previewWindowDeviceSize = newWindowSize
                    
                    // Reset accumulated drag
                    self.previewWindowSizing.accumulatedAdjustedTranslation = .zero
                    self.previewWindowSizing.activeAdjustedTranslation = .zero
                }
            
                .onChange(of: isFullScreen) { isFullScreenUpdate in

                    showFullScreenAnimateCompleted = false
                    withAnimation(.stitchAnimation) {
                        if isFullScreenUpdate {
                            self.previewWindowSizing.userDeviceSize = geometry.size
                        }
                        showFullScreenObserver.update(isFullScreenUpdate)
                    }
                }
        }
    }

    @State var parentSizeBeforeFullscreen: CGSize = .zero
}

extension CGSize {
    var isLandscape: Bool {
        self.width > self.height
    }

    var isPortrait: Bool {
        self.height > self.width
    }
}
