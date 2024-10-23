//
//  SidebarEditButtonView.swift
//  Stitch
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

struct SidebarEditButtonView<SidebarViewModel>: View where SidebarViewModel: ProjectSidebarObservable {
    @Bindable var sidebarViewModel: SidebarViewModel

    var body: some View {
        StitchButton {
            sidebarViewModel.isEditing.toggle()
        } label: {
            Text(sidebarViewModel.isEditing ? "Done" : "Edit")
        }
        .font(SwiftUI.Font.system(size: 18))
        .foregroundColor(Color(.editButton))
    }
}

//struct SidebarEditButtonView_Previews: PreviewProvider {
//    static var previews: some View {
//        SidebarEditButtonView(isEditing: .constant(false))
//    }
//}
