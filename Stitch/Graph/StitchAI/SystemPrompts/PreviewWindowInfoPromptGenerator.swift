//
//  PreviewWindowInfoPromptGenerator.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/9/25.
//

import SwiftUI

extension StitchAIManager {
    static func previewWindowInfoPromptGenerator(previewWindowSize: CGSize,
                                                 previewWindowBackgroundColor: Color) -> String {
        """
        Your design MUST FIT WITHIN A SWIFTUI ZSTACK WHICH IS \(previewWindowSize.width) WIDE AND \(previewWindowSize.height) TALL, WITH A BACKGROUND COLOR OF \(previewWindowBackgroundColor.asHexDisplay). This is the "prototype window" or "screen". Avoid creating an explicit ZStack for the screen if possible. You can retrieve information about the screen's size using the "deviceInfo || Patch" patch node.
        """
    }
}

struct PreviewWindowInfoPromptGenerator: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    PreviewWindowInfoPromptGenerator()
}
