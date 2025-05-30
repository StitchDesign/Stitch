//
//  StitchProjectView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/22/23.
//

import SwiftUI
import StitchSchemaKit

struct StitchProjectView: View {
    @Namespace var routerNamespace
    
    @Bindable var store: StitchStore
    @Bindable var document: StitchDocumentViewModel

    let alertState: ProjectAlertState

    // Re-render views in navigation bar.
    @State var isFullScreen = false
    
    var graphState: GraphState {
        self.document.graph
    }

    var activeIndex: ActiveIndex {
        document.activeIndex
    }

    var body: some View {
        ContentView(store: store,
                    document: document,
                    alertState: alertState,
                    routerNamespace: routerNamespace)
        
            #if !targetEnvironment(macCatalyst)
            // TODO: loses animation when exiting full screen mode
            // TODO: why, for iPad and iPhone, must be ignore the safe areas here, rather than further down in the hierarchy? ... perhaps connected with the hiding of the toolbar?
            .modifier(MaybeIgnoreSafeAreasModifier(hideAllSafeAreas: isFullScreen))

            //            // TODO: Why doesn't this work to ignore safe areas?
            //                            .ignoresSafeArea(isFullScreen ? [.all] : [])
            //                            .onChange(of: isFullScreen, { oldValue, newValue in
            //                                log("onChange of: isFullScreen: oldValue: \(oldValue)")
            //                                log("onChange of: isFullScreen: newValue: \(newValue)")
            //                            })
            #endif

            .modifier(ProjectToolbarViewModifier(document: document,
                                                 graph: graphState,
                                                 // In reality this won't be nil
                                                 projectName: graphState.name,
                                                 projectId: graphState.projectId,
                                                 isFullScreen: $isFullScreen))
            .onAppear {
                // Hide sample projects modal
                store.showsSampleProjectModal = false
            }
            .onDisappear {
                // Create new thumbnail image
                store.createThumbnail(from: document)
                
                // TODO: listen to presses of the NavigationStack's back button instead?
                dispatch(CloseGraph())
            }
    }
}

struct MaybeIgnoreSafeAreasModifier: ViewModifier {
    var hideAllSafeAreas: Bool = false

    func body(content: Content) -> some View {
        // logInView("MaybeIgnoreSafeAreasModifier: body: hideAllSafeAreas: \(hideAllSafeAreas)")

        if StitchDocumentViewModel.isPhoneDevice {
            // logInView("MaybeIgnoreSafeAreasModifier: on phone, ALWAYS ignore safe areas")
            return content.ignoresSafeArea(.all)
                .eraseToAnyView()
        }

        if hideAllSafeAreas {
            // logInView("MaybeIgnoreSafeAreasModifier: will ignore safe areas")
            return content.ignoresSafeArea(.all)
                .eraseToAnyView()
        } else {
            // logInView("MaybeIgnoreSafeAreasModifier: will NOT ignore safe areas")
            return content
                .eraseToAnyView()
        }

    }
}

