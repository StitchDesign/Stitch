//
//  ProjectToolbar.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/2/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

#if targetEnvironment(macCatalyst)
let isCatalyst = true
#else
let isCatalyst = false
#endif

struct ProjectToolbarViewModifier: ViewModifier {
    @Environment(StitchStore.self) private var store
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    let projectName: String
    let projectId: GraphId
    @Binding var isFullScreen: Bool
    
    // Note: Do NOT hide toolbar in Catalyst full screen mode
    @MainActor
    var hideToolbar: Bool {
        StitchDocumentViewModel.isPhoneDevice || (!isCatalyst && document.isFullScreenMode)
    }
    
    var hasActiveGroupFocused: Bool {
        document.groupNodeFocused.isDefined
    }
    
    var isFullscreen: Bool {
        document.isFullScreenMode
    }
    
    var isPreviewWindowShown: Bool {
        document.showPreviewWindow
    }
    
    var restartPrototypeWindowIconRotationZ: CGFloat {
        document.restartPrototypeWindowIconRotationZ
    }
    
    func body(content: Content) -> some View {
        content
            .onChange(of: self.document.isLoadingAI) { oldValue, newValue in
                let didCompleteAIRequest = oldValue != newValue && !newValue
                if didCompleteAIRequest {
                    StitchAITrainingTip.hasCompletedOpenAIRequest = true
                }
            }
            .onChange(of: document.isFullScreenMode) { _, newValue in
                isFullScreen = newValue
            }
            .toolbarRole(.editor) // no "Back" text on back button
        
#if !targetEnvironment(macCatalyst)
            .navigationTitle(self.$graph.name)
            .navigationBarTitleDisplayMode(.inline)
        
        // Note: an empty string hides .navigationTitle
        //                        .navigationTitle(focusMode ? .constant("") : self.$projectTitleString)
        
        // Note: native .navigationTitle editing only triggers this onChange *when we submit the change*
        // So this is actually an `.onSubmit` for .navigationTitle
            .onChange(of: self.graph.name) { _, newValue in
                log(".onChange(of: graph.projectName): newValue: \(newValue)")
                // Encode name changes to disk
                graph.encodeProjectInBackground()
            }
        
        // TODO: build out further when we can share, duplicate projects etc. from within the graph
        //            .toolbarTitleMenu {
        //            // TODO: why no pencil icon like Freeform?
        //            RenameButton()
        //            .simultaneousGesture(TapGesture().onEnded {
        //            log("simultaneous tapped")
        //            dispatch(ReduxFieldFocused(focusedField: .projectTitle))
        //            })
        //
        //            //                Button(action: {
        //            //                }) {
        //            //                    Label("Duplicate", systemImage: "doc.badge.plus")
        //            //                }
        //            //
        //            //                Button(action: {}, label: {
        //            //                    Label("Share", systemImage: "square.and.arrow.up")
        //            //                })
        //            } // .toolbarTitleMenu
#endif
        
            .toolbar {
                
#if !targetEnvironment(macCatalyst)
                
                // TODO: put these into a smaller subview; but tricky because `ToolbarItemGroup` expects to be within a .toolbar closure; use one `.toolbar` for iPad, another for Mac Catalyst ?
                
                // Ideally we use separate placements for smaller groupings and thus less intrusive liquid glass menu effects.
                // `.topBarLeading` places the tab picker to the left of the project title
                // `.navigation` makes it disappear
                
                // On iPad: left side grouping, but still to the right of the project title etc.
                // MARK: KEEP IN SEPARATE GROUP BECAUSE OTHERWISE THE MENU-COLLAPSE-EFFECT IS TOO JARRING
                ToolbarItemGroup(placement: .secondaryAction, content: {
                    //                    ControlGroup {
                    Picker("", selection: $document.selectedTab) {
                        ForEach(ProjectTab.allCases) { projectTab in
                            Image(systemName: projectTab.systemIcon)
                                .tag(projectTab)
                        }
                    }
                    .pickerStyle(.segmented)
                    //                    }
                    
#if DEV_DEBUG || STITCH_AI_TESTING
                    OpenAIConfigurationPicker(document: document)
#endif
                })
                
                
                // TODO: A SINGLE TOOLBAR ITEM CAN BE USED TO CREATE A SEPARATE ELEMENT ?
//                ToolbarItem(placement: .primaryAction) {
//                    // refresh prototype
//                    iPadNavBarButton(iconName: .RESTART_PROTOTYPE_SF_SYMBOL_NAME,
//                                     tooltip: "Restart Prototype",
//                                     action: RESTART_PROTOTYPE_ACTION,
//                                     rotationZ: .zero)
//                }
                
                // TODO: CAN YOU GET THESE AS SEPARATE GROUPINGS SO THAT MENU IS NOT AS 'DESTRUCTIVE' ?
                ToolbarItemGroup(placement: .primaryAction) {
                    
                    // go up a traversal level
                    iPadNavBarButton(iconName: .GO_UP_ONE_TRAVERSAL_LEVEL_SF_SYMBOL_NAME,
                                     tooltip: "Go up one traversal level",
                                     action: { dispatch(GoUpOneTraversalLevel()) })
                    .disabled(hasActiveGroupFocused ? false : true)
                    
                    // Magic AI 'create node'
                    iPadTopBarButtonWithMenu(iconName: .AI_MAGIC_TEMP_MENU_SF_SYMBOL_NAME,
                                             tooltip: "Create with AI") {
                        StitchButton {
                            dispatch(ShowAINodePromptEntryModal())
                        } label: {
                            Label(String.CREATE_CUSTOM_NODE_WITH_AI,
                                  systemImage: "rectangle")
                        }
                        StitchButton {
                            dispatch(ToggleInsertNodeMenu())
                        } label: {
                            Label("Add Nodes",
                                  systemImage: "rectangle.on.rectangle")
                        }
                    }
                    
                    iPadNavBarButton(iconName: .ADD_NODE_SF_SYMBOL_NAME,
                                     tooltip: "Add Node",
                                     action: { dispatch(ToggleInsertNodeMenu()) })
                }
                
                // on iPad: Right-side grouping
                ToolbarItemGroup(placement: .primaryAction) {
                    
                    // toggle preview window
                    iPadNavBarButton(
                        iconName: isPreviewWindowShown ? .HIDE_PREVIEW_WINDOW_SF_SYMBOL_NAME : .SHOW_PREVIEW_WINDOW_SF_SYMBOL_NAME,
                        tooltip: "Toggle Prototype Window",
                        action: PREVIEW_SHOW_TOGGLE_ACTION)
                    //                    }
                    
                    // refresh prototype
                    iPadNavBarButton(iconName: .RESTART_PROTOTYPE_SF_SYMBOL_NAME,
                                     tooltip: "Restart Prototype",
                                     action: RESTART_PROTOTYPE_ACTION,
                                     rotationZ: .zero)
                    
                    // full screen
                    iPadNavBarButton(
                        iconName: isFullscreen ? .SHRINK_FROM_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME : .EXPAND_TO_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME,
                        tooltip: "Toggle Fullscreen",
                        action: PREVIEW_FULL_SCREEN_ACTION)
                    
                    // misc menu
                    iPadGraphTopBarMiscMenu(document: document)
                }
                
#else
                // on Mac, show project title name
                ToolbarItem(placement: .navigationBarLeading) {
                    CatalystNavBarProjectTitleDisplayView(graph: graph)
                }
                
                // Catalyst and iPad have same button layout,
                // but use slightly different buttons:
                // .primaryAction = right side
                // .secondaryAction = center
                
                /*
                 On Catalyst:
                 - only .primaryAction = buttons on left
                 - only .secondaryAction = buttons in center
                 - both = .primaryAction buttons on the right, .secondaryAction buttons in center
                 
                 Note: .navigationBarTrailing on Catalyst is apparently broken, always placed items on left-side ?
                 */
                
                // Hack view to get proper placement
                ToolbarItem(placement: .secondaryAction) {
                    Text("")
                }
                
                ToolbarItemGroup(placement: .primaryAction) {
                    ControlGroup {
                        CatalystTopBarGraphButtons(
                            document: document,
                            isDebugMode: document.isDebugMode,
                            hasActiveGroupFocused: document.groupNodeFocused.isDefined,
                            isFullscreen: document.isFullScreenMode,
                            isPreviewWindowShown: document.showPreviewWindow
                        )
                    }
                }
#endif
                
            }
            .animation(.spring, value: document.restartPrototypeWindowIconRotationZ) // .animation modifier must be placed here
            .toolbarBackground(.visible, for: .automatic)
            .toolbar(hideToolbar ? .hidden : .automatic)
    }
}
