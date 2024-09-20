//
//  _SidebarFooterView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI
import StitchSchemaKit
import StitchViewKit

struct SidebarFooterView: View {

    static let SIDEBAR_FOOTER_HEIGHT: CGFloat = 64
    static let SIDEBAR_FOOTER_COLOR: Color = Color(.sideBarFooter)
    
    let groups: SidebarGroupsDict
    let selections: SidebarSelectionState
    let isBeingEdited: Bool
    let syncStatus: iCloudSyncStatus
    let layerNodes: LayerNodesForSidebarDict

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
        .animation(.default, value: selections)
        .animation(.default, value: groups)
        .animation(.default, value: layerNodes)
        .frame(maxWidth: .infinity)
        .height(Self.SIDEBAR_FOOTER_HEIGHT)
        .background(Self.SIDEBAR_FOOTER_COLOR.ignoresSafeArea())
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
            SidebarFooterButtonsView(groups: groups,
                                     selections: selections,
                                     isBeingEdited: isBeingEdited,
                                     layerNodes: layerNodes)
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

struct SidebarFooterButtonsView: View {
    
    let groups: SidebarGroupsDict
    let selections: SidebarSelectionState
    let isBeingEdited: Bool
    let layerNodes: LayerNodesForSidebarDict
    
    var body: some View {
        let allButtonsDisabled = selections.all.isEmpty
        
        let ungroupButtonEnabled = canUngroup(selections.primary,
                                              nodes: layerNodes)

        let groupButtonEnabled = selections
            .nonEmptyPrimary
            .map { canBeGrouped($0, groups: groups) } ?? false

        let duplicateButtonEnabled = canDuplicate(selections.primary)

//        return HStack(spacing: 10) {
        return Group {
//            Spacer()
            StitchButton {
                dispatch(SidebarGroupUncreated())
            } label: {
                Text("Ungroup")
                    .modifier(DisabledButtonModifier(buttonEnabled: ungroupButtonEnabled))
            }.disabled(!ungroupButtonEnabled)
            
            StitchButton {
                dispatch(SidebarGroupCreated())
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
