//
//  ProjectsListItemBlurView.swift
//  prototype
//
//  Created by Elliot Boschwitz on 5/15/22.
//

import SwiftUI
import StitchSchemaKit

extension View {
    func projectItemBlur() -> some View {
        self.blur(radius: 3)
    }
}

struct ProjectsListItemErrorOverlayViewModifer: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay {
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
                    .scaledToFit()
                    .height(30)
            }
    }
}
