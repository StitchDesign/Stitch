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
    let isBeingEdited: Bool
    let syncStatus: iCloudSyncStatus
    let layerNodes: LayerNodesForSidebarDict

    var selections: SidebarViewModel.SidebarSelectionState {
        self.sidebarViewModel.selectionState
    }

    var groups: SidebarViewModel.SidebarGroupsDict {
        self.sidebarViewModel.getSidebarGroupsDict()
    }
    
    var groups: SidebarGroupsDict {
        graph.getSidebarGroupsDict()
    }
    
    var sidebarDeps: SidebarDeps {
        SidebarDeps(
//            layerNodes: .fromLayerNodesDict(
//                nodes: graph.layerNodes,
//                orderedSidebarItems: graph.orderedSidebarLayers),
            groups: groups,
            expandedItems: graph.getSidebarExpandedItems())
    }

//    var layerNodesForSidebarDict: LayerNodesForSidebarDict {
//        sidebarDeps.layerNodes
//    }

//    var masterList: SidebarListItemsCoordinator {
//        sidebarListState.masterList
//    }

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
        // NOTE: only listen for changes to expandedItems or sidebar-groups,
        // not the layerNodes, since layerNodes change constantly
        // when eg a Time Node is attached to a Text Layer.
        .onChange(of: sidebarDeps.expandedItems) {
            sidebarViewModel.activeSwipeId = nil
        }
        .onChange(of: sidebarDeps.groups) {
            sidebarViewModel.activeSwipeId = nil
        }
        .padding()
        .animation(.default, value: showEditModeFooter)
        .animation(.default, value: selections)
        .animation(.default, value: groups)
        .animation(.default, value: layerNodes)
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
                                     groups: groups,
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

struct SidebarFooterButtonsView<SidebarViewModel>: View where SidebarViewModel: ProjectSidebarObservable {
    @Bindable var sidebarViewModel: SidebarViewModel
    let groups: SidebarViewModel.SidebarGroupsDict
    let isBeingEdited: Bool
//    let layerNodes: LayerNodesForSidebarDict

    var selections: SidebarSelectionState {
        self.sidebarViewModel.selectionState
    }
    
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
