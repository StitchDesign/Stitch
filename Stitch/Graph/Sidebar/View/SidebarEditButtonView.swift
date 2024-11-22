//
//  SidebarEditButtonView.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/21/22.
//

import SwiftUI
import StitchSchemaKit

extension EditMode {
    mutating func toggle() {
        if self.isEditing {
            self = .inactive
        } else {
            self = .active
        }
    }
}

struct SidebarEditButtonView: View {
    static let EDIT_BUTTON_COLOR: Color = Color(.editButton)

    @Binding var isEditing: Bool

    var body: some View {
        StitchButton {
            isEditing.toggle()
        } label: {
            Text(isEditing ? "Done" : "Edit")
        }
        .font(SwiftUI.Font.system(size: 18))
        .foregroundColor(Self.EDIT_BUTTON_COLOR)
    }
}

struct SidebarEditButtonView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarEditButtonView(isEditing: .constant(false))
    }
}
