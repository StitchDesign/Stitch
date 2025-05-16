//
//  ProjectsHomeViewWrapper.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/22/23.
//

import SwiftUI
import StitchSchemaKit

struct ProjectsHomeViewWrapper: View {

    @Environment(StitchStore.self) var store: StitchStore

    // TODO: remove for Catalyst
    @Namespace var routerNamespace

    var body: some View {
        ProjectsHomeView(store: store,
                         namespace: routerNamespace)

            #if !targetEnvironment(macCatalyst)
            .navigationTitle("Stitch Projects")
            .navigationBarTitleDisplayMode(.inline)
            #endif

            .toolbar {

                #if targetEnvironment(macCatalyst)
                // HACK: places an item in center of toolbar, so that trailing buttons stay on right-side even when nav bar title removed
                ToolbarItem(placement: .secondaryAction) {
                    StitchTextView(string: "Stitch Projects",
                                   font: WINDOW_NAVBAR_FONT)
                    // Hack also works if we hide this view
                    //                    .width(1).opacity(0)
                }
                #endif

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isPhoneDevice {
                        iPadTopBarButton(
                            action: SHOW_APP_SETTINGS_ACTION,
                            iconName: APP_SETTINGS_ICON_NAME)
                    } else {
#if targetEnvironment(macCatalyst)
                        CatalystNavBarButton("New Project", systemIconName: .NEW_PROJECT_SF_SYMBOL_NAME) { [weak store] in
                               store?.createNewProjectSideEffect(isProjectImport: false)
                        }
                        // Resolves issue where hover was still active after entering newly created project and then exiting
                        .id(UUID())
                        
                        CatalystNavBarButton("Open Sample Project", systemIconName: .OPEN_SAMPLE_PROJECTS_MODAL) { [weak store] in
                            store?.conditionallToggleSampleProjectsModal()
                        }
                        // Resolves issue where hover was still active after entering newly created project and then exiting
                        .id(UUID())
                        
                        CatalystNavBarButton("Settings", systemIconName: .SETTINGS_SF_SYMBOL_NAME, tooltip: "Open Settings", SHOW_APP_SETTINGS_ACTION)
                        .id(UUID())
                        
#else
                        iPadNavBarButton(title: "New Project", iconName: NEW_PROJECT_ICON_NAME) { [weak store] in
                            store?.createNewProjectSideEffect(isProjectImport: false)
                        }
                        
                        iPadNavBarButton(title: "Open Sample Project", iconName: .sfSymbol(.OPEN_SAMPLE_PROJECTS_MODAL)) { [weak store] in
                            store?.conditionallToggleSampleProjectsModal()
                        }
                        
                        // TODO: disabling feedback button on home screen for consistency with Catalyst due to color issue
//                        TopBarFeedbackButtonsView(showLabel: false)
//                            .modifier(iPadTopBarButtonStyle())
                        
                        iPadNavBarButton(title: "Settings", iconName: PROJECT_SETTINGS_ICON_NAME, tooltip: "Open Settings", action: SHOW_APP_SETTINGS_ACTION)
#endif
                        
                    }
                }
            }
    }
}

// struct CatalystProjectsView_Previews: PreviewProvider {
//    static var previews: some View {
//        CatalystProjectsListView()
//    }
// }
