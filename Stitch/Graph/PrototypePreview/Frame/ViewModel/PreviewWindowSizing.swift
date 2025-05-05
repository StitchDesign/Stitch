//
//  PreviewWindowSizing.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI

@Observable
final class PreviewWindowSizing: Sendable {
    // Size of the device the preview window is emulating
    // i.e. the size of the device our prototype is for: e.g. iPhone 11 etc.
    @MainActor var previewWindowDeviceSize: CGSize = PreviewWindowDevice.DEFAULT_PREVIEW_SIZE
    
    // Size of the device on which Stitch is running, e.g. iPad Pro 11".
    // Changes when e.g. keyboard comes up or user's device rotates.
    @MainActor var userDeviceSize: CGSize = DEFAULT_LANDSCAPE_SIZE
    
    /// From user's manual drag of preview window handle. Reset when project clsoed.
    @MainActor var activeAdjustedTranslation: CGSize = .zero
    @MainActor var accumulatedAdjustedTranslation: CGSize = .zero
    
    init() { }
}

extension PreviewWindowSizing {
    /*
     Every property of the view window is derived from previewWindowDeviceSize and userDeviceSize,
     with adjusted-translations from user's manual dragging of the preview window handle.
     
     Note: do we need to
     */
        
    // Scaling the preview window to the user's device
    // NEVER CHANGES; BASED ON ELLIOT'S FORMULA;
    // fka `calcSmallPreviewWindowScale`
    @MainActor var previewWindowContentScale: CGFloat {
        let previewSize = previewWindowDeviceSize // PW device size, e.g. iPhone 14
        let deviceSize = userDeviceSize  // user's device e.g. the iPad
        
        let previewHeightRatio = previewSize.height / deviceSize.height
        let previewWidthRatio = previewSize.width / deviceSize.width
        let maxOffsetNeeded = max(previewHeightRatio / 0.66, previewWidthRatio / 0.25)
        let _scale = Double(1 / maxOffsetNeeded)
        // log("pwContentScale: scale: _scale: \(_scale)")
        return _scale
    }
    
    // fka `calcFullPreviewWindowScale`
    @MainActor var fullscreenPreviewWindowContentScale: CGFloat {
        let previewSize = previewWindowDeviceSize // PW device size, e.g. iPhone 14
        let deviceSize = userDeviceSize  // user's device e.g. the iPad
        
        let widthScale = deviceSize.width / previewSize.width
        let heightScale = deviceSize.height / previewSize.height
        let _scale = min(widthScale, heightScale)
        // log("fullscreenPWContentScale: scale: _scale: \(_scale)")
        return _scale
    }
    
    @MainActor var previewDeviceWidth: CGFloat {
        previewWindowDeviceSize.width
    }
            
    @MainActor var previewDeviceHeight: CGFloat {
        previewWindowDeviceSize.height
    }
    
    // fka `grayWidth`
    @MainActor var previewBorderWidth: CGFloat {
        dimensions.width + PREVIEW_WINDOW_BORDER_WIDTH * 2
    }
    
    // faka `grayHeight`
    @MainActor var previewBorderHeight: CGFloat {
        dimensions.height + PREVIEW_WINDOW_BORDER_WIDTH * 2
    }
    
    @MainActor func getDimensions(_ newActiveAdjustedTranslation: CGSize) -> CGSize {
        // Ratio of prototype's size vs device-running-stitch's size; applied to the content within the preview window
        let contentScale = previewWindowContentScale

        // We treat accumulated-translation as an addition to the preview window device size's own dimensions ...
        let width = (previewWindowDeviceSize.width + self.accumulatedAdjustedTranslation.width) * contentScale
        let height = (previewWindowDeviceSize.height + self.accumulatedAdjustedTranslation.height) * contentScale
        
        return CGSize(
            // ... But treat *active* translation gestures as fresh and outside of the established dimenions
            width: width + newActiveAdjustedTranslation.width,
            height: height + newActiveAdjustedTranslation.height
        )
    }
    
    @MainActor var dimensions: CGSize {
        getDimensions(self.activeAdjustedTranslation)
    }
}

