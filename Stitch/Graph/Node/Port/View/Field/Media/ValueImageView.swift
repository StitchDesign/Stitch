//
//  ValueImageView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/16/22.
//

import SwiftUI
import StitchSchemaKit

let IMAGE_INLINE_DISPLAY_WIDTH: CGFloat = 30.0

// let it be a little higher than normal?
let IMAGE_INLINE_DISPLAY_HEIGHT: CGFloat = NODE_ROW_HEIGHT + 10

let IMAGE_INLINE_DISPLAY_SIZE = CGSize(
    width: IMAGE_INLINE_DISPLAY_WIDTH,
    height: IMAGE_INLINE_DISPLAY_HEIGHT)

let INLINE_IMAGE_DISPLAY_SIZE = ImageDisplaySize(IMAGE_INLINE_DISPLAY_SIZE)

let IMAGE_INLINE_DISPLAY_OPACITY: CGFloat = 1
let IMAGE_INLINE_DISPLAY_CLIPPED = false

// Inline image display; eg image seen
struct ValueImageView: View {

    let image: UIImage

    var body: some View {
        ImageDisplayView(
            image: image, 
            imageLayerSize: .init(INLINE_IMAGE_DISPLAY_SIZE.size),
            imageDisplaySize: INLINE_IMAGE_DISPLAY_SIZE,
            opacity: IMAGE_INLINE_DISPLAY_OPACITY,
            fitStyle: .fit,
            isClipped: IMAGE_INLINE_DISPLAY_CLIPPED)
            // white background for parts of display area not covered
            // due to image's aspect ratio.
            .background(.white)
    }
}

/// Wrapper view for `ValueImageView` that processes a `StitchImage` to optionally present a `NilImageView`.
struct ValueStitchImageView: View {
    let image: UIImage?

    var body: some View {
        if let uiImage = image {
            ValueImageView(image: uiImage)
        } else {
            NilImageView()
        }

    }
}

/// Wrapper view for video values to handle possible optional video.
struct ValueStitchVideoView: View {
    let thumbnail: UIImage?

    var body: some View {
        if let thumbnail = thumbnail {
            ValueImageView(image: thumbnail)
        } else {
            NilImageView()
        }
    }
}

//struct ValueImageView_Previews: PreviewProvider {
//    static var previews: some View {
//        ValueImageView(image: IMAGE_DEBUG)
//            .padding(2)
//            .scaleEffect(10)
//    }
//}
