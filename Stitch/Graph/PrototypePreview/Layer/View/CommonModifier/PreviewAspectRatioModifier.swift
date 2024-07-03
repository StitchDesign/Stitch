//
//  PreviewAspectRatioModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/3/24.
//

import SwiftUI

struct PreviewAspectRatioModifier: ViewModifier {
    
    let data: AspectRatioData?
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if let data = data {
            // Note: `.aspectRatio` along a dimension only works if that dimension is unspecified;
            // e.g. `.frame(height:)` means `.aspectRatio(CGSize(height:))` will be ignored.
            content.aspectRatio(CGSize(width: data.widthAxis,
                                       height: data.heightAxis),
                                contentMode: data.contentMode)
        } else {
            content
        }
    }
}


//#Preview {
//    PreviewAspectRatioModifier()
//}
