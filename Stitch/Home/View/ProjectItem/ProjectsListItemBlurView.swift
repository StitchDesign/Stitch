//
//  ProjectsListItemBlurView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/15/22.
//

import SwiftUI
import StitchSchemaKit

extension View {
    func projectItemBlur(willBlur: Bool = true) -> some View {
        self.blur(radius: willBlur ? 3 : 0)
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
