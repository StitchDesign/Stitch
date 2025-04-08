//
//  PreviewContent.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/6/22.
//

import SwiftUI
import StitchSchemaKit

extension Color {
    static let PREVIEW_WINDOW_BORDER_COLOR: Color = Color(uiColor: .systemGray3)
}

struct PreviewContent: View {
    static let prototypeCoordinateSpace = "STITCH_PROTOTYPE_COORDINATE"
    
    @Bindable var document: StitchDocumentViewModel
    let isFullScreen: Bool
    
    let showPreviewWindow: Bool
    
    var previewWindowSizing: PreviewWindowSizing {
        document.previewWindowSizingObserver
    }
    
    var previewDeviceWidth: CGFloat {
        previewWindowSizing.previewDeviceWidth
    }
    
    var previewDeviceHeight: CGFloat {
        previewWindowSizing.previewDeviceHeight
    }
    
    var previewBorderWidth: CGFloat {
        previewWindowSizing.previewBorderWidth
    }
        
    var previewContentScale: CGFloat {
        let _scale = (previewBorderWidth - (PREVIEW_WINDOW_BORDER_WIDTH * 2)) / previewDeviceWidth
        // log("redScale: _scale: \(_scale)")
        return _scale
    }
        
    var finalSize: CGSize {
        isFullScreen
        ? previewWindowSizing.previewWindowDeviceSize
        : .init(width: previewDeviceWidth, height: previewDeviceHeight)
    }
    
    var finalScale: CGFloat {
        isFullScreen
        ? previewWindowSizing.fullscreenPreviewWindowContentScale 
        : previewContentScale
    }
    
    // showPreview:         a boolean which controls animation for view
    // shouldRenderPreview: will only toggle after animation completes and is used for
    //                      controlling rendering of preview
    @State var shouldRenderPreview = true
    
    var inputTextFieldFocused: Bool {
        document.reduxFocusedField?.inputTextFieldWithNumberIsFocused(document.graph) ?? false
    }
    
    var body: some View {
    
        // TODO: still needed to contain gestures?
        // TODO: needed with `ignoresKeyCommands: false` to detect key presses for keyboard nodes
        // TODO: why is GeneratePreview wrappe in a UIHostingController? Better?: have some other view on the graph that listens for key presses
        // NOTE: `if swiftUIAnimatedVar { ... } else { ... }` seems to not work well when inside UIHostingController.
        Group {
            if shouldRenderPreview {
                UIKitWrapper(ignoresKeyCommands: false,
                             inputTextFieldFocused: inputTextFieldFocused,
                             name: .previewWindow) {
                    GeneratePreview(document: document)
                        .frame(finalSize)
                        .coordinateSpace(name: Self.prototypeCoordinateSpace)
                        .background(document.previewWindowBackgroundColor)
                        .contentShape(Rectangle())
                    // Keeps layers rendered within preview window
                        .clipped()
                    // Important: render preview window border BEFORE applying scale
                        .previewWindowBorder(showsBorder: !isFullScreen)
                        .scaleEffect(finalScale)
                }
            } else {
                UIKitWrapper(ignoresKeyCommands: false,
                             inputTextFieldFocused: inputTextFieldFocused,
                             name: .previewWindow) {
                    EmptyView()
                }
                             .allowsHitTesting(false)
            }
        } // Group
        .onChange(of: showPreviewWindow) { oldValue, newValue in
            log("FloatingWindowView: .onChange(of: showPreviewWindow): \(newValue)")
            // When state changes to show preview window, change state
            // to trigger animation
            // TODO: debug why "show" animation is so much slower than "hide" animation when both use same duration
            //            withAnimation(.linear(duration: newValue ? 0.3 : 0.8)) {
            // Note: shorter animation times avoids appearance of some preview window elements disappearing before others (e.g. material layer)
            withAnimation(.linear(duration: 0.05)) {
                shouldRenderPreview = newValue
            }
        }
    }
}

let PREVIEW_WINDOW_BORDER_WIDTH = 8.0

extension View {
    func previewWindowBorder(showsBorder: Bool) -> AnyView {
        if showsBorder {
            return self
                .padding(PREVIEW_WINDOW_BORDER_WIDTH - 0.4)
                .border(Color.PREVIEW_WINDOW_BORDER_COLOR,
                        width: PREVIEW_WINDOW_BORDER_WIDTH)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .eraseToAnyView()
        } else {
            return self.eraseToAnyView()
        }
    }
}
