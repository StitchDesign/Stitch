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
    
    // Shown on both iPad and Catalyst but only if debug etc.
    var aiPreviewerButton: some View {
        CatalystNavBarButton("document.viewfinder.fill",
                             toolTip: "Open AI Preview") { [weak store] in
            guard let store = store else {
                return
            }
            let (document, encoder) = store.createAIDocumentPreviewer()
            if store.navPath.isEmpty {
                store.navPath = [.aiPreviewer(document, encoder)]
            } else {
                store.navPath = []
            }
            //                            store.showAIResponseViewer.toggle()
            
        }
        // Resolves issue where hover was still active after entering newly created project and then exiting
                             .id(UUID())
                
    }
    
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
                .padding(.horizontal)
                // Hack also works if we hide this view
                //                    .width(1).opacity(0)
            }
#endif
            
//            ToolbarItemGroup(placement: .navigationBarTrailing) {
            ToolbarItemGroup(placement: .primaryAction) {
                if isPhoneDevice {
                    iPadTopBarButton(
                        iconName: "gear",
                        tooltip: "Settings",
                        action: SHOW_APP_SETTINGS_ACTION)
                } else {

                    
#if DEV_DEBUG || STITCH_AI_TESTING
                    aiPreviewerButton
#endif
                    
                    
#if targetEnvironment(macCatalyst)
                    ControlGroup {
                        CatalystNavBarButton(.NEW_PROJECT_SF_SYMBOL_NAME,
                                             toolTip: "New Project") { [weak store] in
                            store?.createNewProjectSideEffect(isProjectImport: false)
                        }
                        // Resolves issue where hover was still active after entering newly created project and then exiting
                                             .id(UUID())
                        
                        CatalystNavBarButton(.OPEN_SAMPLE_PROJECTS_MODAL,
                                             toolTip: "Open Sample Projects") { [weak store] in
                            store?.conditionallToggleSampleProjectsModal()
                        }
                        // Resolves issue where hover was still active after entering newly created project and then exiting
                                             .id(UUID())
                        
                        TopBarFeedbackButtonsView(document: nil)
                        // Hides the little arrow on Catalyst
                            .menuIndicator(.hidden)
                            .buttonStyle(.borderless)
                            .id(UUID())
                        
                        CatalystNavBarButton(.SETTINGS_SF_SYMBOL_NAME,
                                             toolTip: "Open Settings") {
                            SHOW_APP_SETTINGS_ACTION()
                        }
                                             .id(UUID())
                    }
                    

                    
#else
                    
                    ControlGroup {
                        iPadNavBarButton(iconName: .NEW_PROJECT_SF_SYMBOL_NAME,
                                         tooltip: "New Project",
                                         action: { [weak store] in
                            store?.createNewProjectSideEffect(isProjectImport: false)
                        })
                        
                        iPadNavBarButton(iconName: .OPEN_SAMPLE_PROJECTS_MODAL,
                                         tooltip: "Open Sample Projects",
                                         action: { [weak store] in
                            store?.conditionallToggleSampleProjectsModal()
                        })
                        
                        TopBarFeedbackButtonsView(document: nil,
                                                  showLabel: false)
                        .modifier(iPadTopBarButtonStyle())
                        
                        iPadNavBarButton(iconName: .SETTINGS_SF_SYMBOL_NAME,
                                         tooltip: "Open Settings",
                                         action: SHOW_APP_SETTINGS_ACTION)
                    }
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
