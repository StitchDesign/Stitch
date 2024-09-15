//
//  PreviewContent.swift
//  prototype
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
    
    var body: some View {
        
        let generatedPreview = GeneratePreview(document: document)
        
        UIKitWrapper(ignoresKeyCommands: false, name: "PreviewContent") {
            generatedPreview
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
