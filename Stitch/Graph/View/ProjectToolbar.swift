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

                // Catalyst and iPad have same button layout,
                // but use slightly different buttons:

                // .primaryAction = right side
                // .secondaryAction = center
                ToolbarItemGroup(placement: .primaryAction) {
                    iPadGraphTopBarButtons(
                        document: document,
                        isDebugMode: document.isDebugMode,
                        hasActiveGroupFocused: document.groupNodeFocused.isDefined,
                        isFullscreen: document.isFullScreenMode,
                        isPreviewWindowShown: document.showPreviewWindow,
                        restartPrototypeWindowIconRotationZ: document.restartPrototypeWindowIconRotationZ)
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
                    CatalystTopBarGraphButtons(
                        document: document,
                        isDebugMode: document.isDebugMode,
                        hasActiveGroupFocused: document.groupNodeFocused.isDefined,
                        isFullscreen: document.isFullScreenMode,
                        isPreviewWindowShown: document.showPreviewWindow
                    )
                }
                #endif

            }
            .animation(.spring, value: document.restartPrototypeWindowIconRotationZ) // .animation modifier must be placed here
           .toolbarBackground(.visible, for: .automatic)
           .toolbar(hideToolbar ? .hidden : .automatic)
    }
}
