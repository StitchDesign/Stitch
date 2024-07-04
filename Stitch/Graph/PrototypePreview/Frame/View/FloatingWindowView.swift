//
//  FloatingWindowView.swift
//  prototype
//
//  Created by cjc on 12/14/20.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension CGFloat {
    static let FLOATING_WINDOW_HANDLE_LENGTH = 30.0
}

extension CGSize {
    static let FLOATING_WINDOW_HANDLE_SIZE = CGSize(
        width: .FLOATING_WINDOW_HANDLE_LENGTH,
        height: .FLOATING_WINDOW_HANDLE_LENGTH)

    static let FLOATING_WINDOW_HANDLE_HITBOX_SIZE_IPAD = CGSize(
        width: .FLOATING_WINDOW_HANDLE_LENGTH * 2.25,
        height: .FLOATING_WINDOW_HANDLE_LENGTH * 2.25)

    static let FLOATING_WINDOW_HANDLE_HITBOX_SIZE_MAC = CGSize(
        width: .FLOATING_WINDOW_HANDLE_LENGTH * 1.5,
        height: .FLOATING_WINDOW_HANDLE_LENGTH * 1.5)
}

struct FloatingWindowView: View {
    @Bindable var graph: GraphState

    // the screen size of the device that Stitch is running on (e.g. iPad screen or Catalyst window)
    let deviceScreenSize: CGSize

    let showPreviewWindow: Bool
    let namespace: Namespace.ID

    static let xOffset: Double = PREVIEW_WINDOW_PADDING

    // showPreview:         a boolean which controls animation for view
    // shouldRenderPreview: will only toggle after animation completes and is used for
    //                      controlling rendering of preview
    @State var shouldRenderPreview = true
    
    @ObservedObject var previewWindowSizing: PreviewWindowSizing

    var dimensions: CGSize {
        previewWindowSizing.dimensions
    }

    var projectId: ProjectId {
        graph.projectId
    }

    // the size of the device represented by the preview window
    // i.e. `pwDevice`
    var previewWindowSize: CGSize {
        graph.previewWindowSize
    }

    var body: some View {
        ZStack {
            if shouldRenderPreview {
                floatingWindowWithHandle
                    .matchedGeometryEffect(id: projectId, in: namespace)
                    .transition(.slideInAndOut)
            } else {
                EmptyView()
            }
        }
        .onChange(of: showPreviewWindow) { _showPreviewWindow in
            // When state changes to show preview window, change state
            // to trigger animation
            // TODO: debug why "show" animation is so much slower than "hide" animation when both use same duration
            withAnimation(.linear(duration: _showPreviewWindow ? 0.3 : 0.8)) {
                shouldRenderPreview = _showPreviewWindow
            }
        }
    }

    /*
     HACK:

     There is a bug, on iPad only, where `Spacer()` and/or `.overlay(<some alignment>)` with dynamically changing `dimensions` causes a drag gesture's onEnded to not be called. Hence on infinite loop and app-freezing.

     Interestingly, placing the handle (which has the drag gesture) outside of the Spacers() etc. works; we just have to manually position the handle then.
     */
    var floatingWindowWithHandle: some View {
        floatingWindow
            // Start the handle-circle at top-right corner ...
            // ... then manually move down and left by the scaled preview window's dimensions
            .background(alignment: .topTrailing) {
                floatingWindowHandle
                    .offset(x: -Self.xOffset)
            } // .background
            .offset(x: self.finalXOffset)
        
        // TODO: which animation most closely matches the Inspector? (without .animation, we jump when inspector opened or closed)
//            .animation(.linear, value: self.finalXOffset)
//            .animation(.easeOut, value: self.finalXOffset)
//            .animation(.easeInout, value: self.finalXOffset)
//            .animation(.spring, value: self.finalXOffset)
            .animation(.default, value: self.finalXOffset)
    }

    @State var isDragging: Bool = false

    func setSpecialCursor() {
        #if targetEnvironment(macCatalyst)
        if let iconImage = UIImage(named: "resizenortheastsouthwest") {
            NSCursor(image: iconImage,
                     // hotSpot: NSPoint(x: 8, y: 8)).push() // too far right and down
                     // hotSpot: .zero).push() // even further right and down!
                     hotSpot: NSPoint(x: 16, y: 16)).push() // perfect
        } else {
            NSCursor.crosshair.push()
        }
        #endif
    }

    func setNormalCursor() {
        #if targetEnvironment(macCatalyst)
        NSCursor.pop()
        #endif
    }

    var catalystFloatingWindowHandleView: some View {
        Circle()
            
//        #if DEV_DEBUG
//            .fill(Color.cyan.opacity(0.6)) // easier debug
//        #else
            // Note: cannot use .clear
            .fill(Color.PREVIEW_WINDOW_BORDER_COLOR.opacity(0.001))
//        #endif
            .onChange(of: self.isDragging) { _, newValue in
                log(".onChange(of: self.isDragging): newValue: \(newValue)")
                if newValue {
                    self.setSpecialCursor()
                } else {
                    self.setNormalCursor()
                }
            }
    }

    var floatingWindowHandlePlatformView: some View {
#if targetEnvironment(macCatalyst)
        catalystFloatingWindowHandleView
#else
        iPadFloatingWindowHandleView()
#endif
    }

    var floatingWindowHandle: some View {
        floatingWindowHandleHitbox
            .offset(x: -dimensions.width,
                    y: dimensions.height)
            .gesture(floatingWindowHandleDragGesture)
    }

    var floatingWindowHandleHitbox: some View {
        //        Color.HITBOX_COLOR
        floatingWindowHandlePlatformView
#if targetEnvironment(macCatalyst)
        // Mac only has cursor, and so can always use a more precise hitbox;
        // but we still expand the size a little bit
            .frame(.FLOATING_WINDOW_HANDLE_HITBOX_SIZE_MAC)
        
            .onHover { hovering in
                // log("onHover: hovering: \(hovering)")
                if hovering {
                    self.setSpecialCursor()
                } else {
                    self.setNormalCursor()
                }
            }
        
#else
        // TODO: on iPad, use UIKit to distinguish between a finger-on-screen touch (which needs extended hitbox) and a cursor touch (which doesn't)
            .frame(.FLOATING_WINDOW_HANDLE_HITBOX_SIZE_IPAD)
#endif
    }

    var floatingWindowHandleDragGesture: DragGestureTypeSignature {
        DragGesture()
            .onChanged { value in
                self.isDragging = true

                let (x, y) = aspectRatioAdjustedX(
                    translationHeight: value.translation.height,
                    pwDeviceSize: self.previewWindowSizing.previewWindowDeviceSize)

        //        self.activeAdjustedTranslation = .init(width: x, height: y)
                let suggested: CGSize = .init(width: x, height: y)
                
                if self.previewWindowSizing.getDimensions(suggested).height < 200 {
                    return // Do not let preview window get too small
                } else {
                    self.previewWindowSizing.activeAdjustedTranslation = suggested
                }
                
            }
            .onEnded({ _ in
                self.isDragging = false
                
                self.previewWindowSizing.accumulatedAdjustedTranslation.width += self.previewWindowSizing.activeAdjustedTranslation.width
                
                self.previewWindowSizing.accumulatedAdjustedTranslation.height += self.previewWindowSizing.activeAdjustedTranslation.height
                
                self.previewWindowSizing.activeAdjustedTranslation = .zero
            })
    }
    
    var finalXOffset: CGFloat {
        graph.graphUI.showsLayerInspector ? Self.xOffset - LayerInspectorView.LAYER_INSPECTOR_WIDTH : Self.xOffset
    }
    
    @ViewBuilder
    var floatingWindow: some View {
        VStack {
            HStack(spacing: .zero) {
                Spacer()
                PreviewContent(graph: graph,
                               isFullScreen: false,
                               previewWindowSizing: self.previewWindowSizing)
                .frame(self.previewWindowSizing.dimensions)
            }
            Spacer()
        }
        .padding(.top, PREVIEW_WINDOW_Y_PADDING)
    }
}

struct FloatingWindowView_Previews: PreviewProvider {

    @Namespace static var namespace

    static var previews: some View {
        FloatingWindowView(graph: .init(id: .init(), store: nil),
                           deviceScreenSize: DEFAULT_LANDSCAPE_SIZE,
                           showPreviewWindow: true,
                           namespace: namespace,
                           previewWindowSizing: .init())
    }
}

func aspectRatioAdjustedX(translationHeight: CGFloat,
                          pwDeviceSize: CGSize) -> (x: CGFloat, y: CGFloat) {
    /*
     Suppose ratio is height 2 : width 3,
     and translation is y = 6, x = 8,
     and we look only at `y`
     and we use min val, so `y`,
     and we want to figure out the corresponding x such that we stay in ratio.
     
     6/p = 2/3
     x = (6 * 3) / 2 = 18 / 2 = 9
     x = (translation.y * ratio.width) / ratio.height
     */
    let y = translationHeight // value.translation.height
    let x = (y * pwDeviceSize.width) / pwDeviceSize.height
    
//        log("drag: y: \(y)")
//        log("drag: x: \(x)")
    
    return (x, y)
}
