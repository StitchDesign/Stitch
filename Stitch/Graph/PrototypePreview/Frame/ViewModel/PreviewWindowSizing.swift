//
//  PreviewWindowSizing.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI

@Observable
final class PreviewWindowSizing {
    // Size of the device the preview window is emulating
    // i.e. the size of the device our prototype is for: e.g. iPhone 11 etc.
    var previewWindowDeviceSize: CGSize = PreviewWindowDevice.DEFAULT_PREVIEW_SIZE
    
    // Size of the device on which Stitch is running, e.g. iPad Pro 11".
    // Changes when e.g. keyboard comes up or user's device rotates.
    var userDeviceSize: CGSize = DEFAULT_LANDSCAPE_SIZE
    
    /// From user's manual drag of preview window handle. Reset when project clsoed.
    var activeAdjustedTranslation: CGSize = .zero
    var accumulatedAdjustedTranslation: CGSize = .zero
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
    var previewWindowContentScale: CGFloat {
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
    var fullscreenPreviewWindowContentScale: CGFloat {
        let previewSize = previewWindowDeviceSize // PW device size, e.g. iPhone 14
        let deviceSize = userDeviceSize  // user's device e.g. the iPad
        
        let widthScale = deviceSize.width / previewSize.width
        let heightScale = deviceSize.height / previewSize.height
        let _scale = min(widthScale, heightScale)
        // log("fullscreenPWContentScale: scale: _scale: \(_scale)")
        return _scale
    }
    
    var previewDeviceWidth: CGFloat {
        previewWindowDeviceSize.width
    }
            
    var previewDeviceHeight: CGFloat {
        previewWindowDeviceSize.height
    }
    
    // faka `grayWidth`
    var previewBorderWidth: CGFloat {
        dimensions.width + PREVIEW_WINDOW_BORDER_WIDTH * 2
    }
    
    // faka `grayHeight`
    var previewBorderHeight: CGFloat {
        dimensions.height + PREVIEW_WINDOW_BORDER_WIDTH * 2
    }
    
    func getDimensions(_ newActiveAdjustedTranslation: CGSize) -> CGSize {
        let fullWidth: Double = previewWindowDeviceSize.width * previewWindowContentScale
        let fullHeight: Double = previewWindowDeviceSize.height * previewWindowContentScale
   
        return CGSize(
            width: fullWidth
            + self.accumulatedAdjustedTranslation.width
            + newActiveAdjustedTranslation.width,
            
            height: fullHeight
            + self.accumulatedAdjustedTranslation.height
            + newActiveAdjustedTranslation.height
        )
    }
    
    var dimensions: CGSize {
        getDimensions(self.activeAdjustedTranslation)
    }
}

