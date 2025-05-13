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
                        CatalystNavBarButton(action: { [weak store] in
                            store?.createNewProjectSideEffect(isProjectImport: false)
                        },
                                             iconName: .sfSymbol(.NEW_PROJECT_SF_SYMBOL_NAME))
                        // Resolves issue where hover was still active after entering newly created project and then exiting
                        .id(UUID())
                        
                        CatalystNavBarButton(action: { [weak store] in
                            store?.conditionallToggleSampleProjectsModal()
                        },
                                             iconName: .sfSymbol(.OPEN_SAMPLE_PROJECTS_MODAL))
                        // Resolves issue where hover was still active after entering newly created project and then exiting
                        .id(UUID())
                        
                        TopBarFeedbackButtonsView(document: nil)
                        // Hides the little arrow on Catalyst
                            .menuIndicator(.hidden)
                            .buttonStyle(.borderless)
                            .id(UUID())
                        
                        CatalystNavBarButton(action: SHOW_APP_SETTINGS_ACTION,
                                             iconName: .sfSymbol(.SETTINGS_SF_SYMBOL_NAME))
                        .id(UUID())
                        
#else
                        iPadNavBarButton(action: { [weak store] in
                            store?.createNewProjectSideEffect(isProjectImport: false)
                        },
                                         iconName: NEW_PROJECT_ICON_NAME)
                        
                        iPadNavBarButton(action: { [weak store] in
                            store?.conditionallToggleSampleProjectsModal()
                        },
                                         iconName: .sfSymbol(.OPEN_SAMPLE_PROJECTS_MODAL))
                        
                        TopBarFeedbackButtonsView(document: nil,
                                                  showLabel: false)
                            .modifier(iPadTopBarButtonStyle())
                        
                        iPadNavBarButton(action: SHOW_APP_SETTINGS_ACTION,
                                         iconName: PROJECT_SETTINGS_ICON_NAME)
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
