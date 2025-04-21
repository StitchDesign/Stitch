//
//  _SidebarFooterView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI
import StitchSchemaKit
import StitchViewKit

struct SidebarFooterView<SidebarViewModel: ProjectSidebarObservable>: View {

    private let SIDEBAR_FOOTER_HEIGHT: CGFloat = 64
    private let SIDEBAR_FOOTER_COLOR: Color = Color(.sideBarFooter)
    
    @Bindable var sidebarViewModel: SidebarViewModel
    let syncStatus: iCloudSyncStatus

    var isBeingEdited: Bool {
        self.sidebarViewModel.isEditing
    }
    
    var selections: SidebarViewModel.SidebarSelectionState {
        self.sidebarViewModel.selectionState
    }
    
    var showEditModeFooter: Bool {
        #if targetEnvironment(macCatalyst)
        // on Catalyst, show edit mode footer if we're in edit-mode or have at least one edit-mode-selection
        return !selections.primary.isEmpty
        #else
        // on iPad, only show edit mode footer in edit-mode
        return isBeingEdited
        #endif
    }
    
    var body: some View {
        HStack {
            if showEditModeFooter {
                editModeFooter
                    .animation(.default, value: isBeingEdited)
            } else {
                normalFooter
                    .animation(.default, value: isBeingEdited)
            }
        }
        .padding()
        .animation(.default, value: showEditModeFooter)
        .animation(.default, value: selections.primary)
        .frame(maxWidth: .infinity)
        .height(self.SIDEBAR_FOOTER_HEIGHT)
        .background(self.SIDEBAR_FOOTER_COLOR.ignoresSafeArea())
    }

    var normalFooter: some View {
        HStack {
            Text("iCloud Sync")
            Image(systemName: syncStatus.sfSymbol)
        }
    }
    
    @MainActor
    var editModeFooter: some View {
        HStack(spacing: 10) {
            Spacer()
            SidebarFooterButtonsView(sidebarViewModel: sidebarViewModel,
                                     isBeingEdited: isBeingEdited)
        }
    } // editModeFooter
}

// TODO: apply `.foregroundColor(Color(.titleFont))` in `StitchButton` messes with SwiftUI's native gray-out of disabled buttons?
struct DisabledButtonModifier: ViewModifier {
    let buttonEnabled: Bool
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(buttonEnabled ? Color(.titleFont) : Color.gray.opacity(0.8))
    }
}

struct SidebarFooterButtonsView<SidebarViewModel>: View where SidebarViewModel: ProjectSidebarObservable {
    @Bindable var sidebarViewModel: SidebarViewModel
    let isBeingEdited: Bool

    var selections: SidebarViewModel.SidebarSelectionState {
        self.sidebarViewModel.selectionState
    }
    
    var body: some View {
        let allButtonsDisabled = selections.all.isEmpty
        let ungroupButtonEnabled = sidebarViewModel.canUngroup()
        let groupButtonEnabled = sidebarViewModel.canBeGrouped()
        let duplicateButtonEnabled = sidebarViewModel.canDuplicate()

//        return HStack(spacing: 10) {
        return Group {
//            Spacer()
            StitchButton {
                self.sidebarViewModel.sidebarGroupUncreated()
            } label: {
                Text("Ungroup")
                    .modifier(DisabledButtonModifier(buttonEnabled: ungroupButtonEnabled))
            }.disabled(!ungroupButtonEnabled)
            
            StitchButton {
                sidebarViewModel.sidebarGroupCreated()
            } label: {
                Text("Group")
                    .modifier(DisabledButtonModifier(buttonEnabled: groupButtonEnabled))
            }
            .disabled(!groupButtonEnabled)
            
            StitchButton {
                log("SidebarFooterView duplicate tapped")
                dispatch(SidebarSelectedItemsDuplicated())
            } label: {
                Text("Duplicate")
                    .modifier(DisabledButtonModifier(buttonEnabled: duplicateButtonEnabled))
            }.disabled(!duplicateButtonEnabled)
            
            StitchButton {
                log("SidebarFooterView delete tapped")
                dispatch(SidebarSelectedItemsDeleted())
            } label: {
                Text("Delete")
                    .modifier(DisabledButtonModifier(buttonEnabled: !allButtonsDisabled))
            }.disabled(allButtonsDisabled)
        }
    }
}
