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
    @Bindable var graphUI: GraphUIState

    let alertState: ProjectAlertState

    // Re-render views in navigation bar.
    @State var isFullScreen = false
    
    var graphState: GraphState {
        self.document.graph
    }

    var activeIndex: ActiveIndex {
        graphUI.activeIndex
    }

    var body: some View {
        projectLoadingView
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
                                                 graphUI: document.graphUI,
                                                 // In reality this won't be nil
                                                 projectName: graphState.name,
                                                 projectId: graphState.projectId,
                                                 isFullScreen: $isFullScreen))
            .onDisappear {
                // Create new thumbnail image
                store.createThumbnail(from: document)
                
                // TODO: listen to presses of the NavigationStack's back button instead?
                dispatch(CloseGraph())
            }
    }

    @ViewBuilder @MainActor
    var projectLoadingView: some View {
        // ZStack needed for animation
        ZStack {
            // Loading job kicked off in GraphState.init
            switch graphState.libraryLoadingStatus {
            case .loading:
                ProgressView()

            case .loaded:
                projectView()

            case .failed:
                // Graph did not load
                EmptyView()
                    .onAppear {
                        #if DEBUG
                        fatalError()
                        #endif

                        log("setCurrentProjectResult: had graph schema decoding error")
                        dispatch(CloseGraph())
                    }
            }
        }
    }

    @ViewBuilder @MainActor
    func projectView() -> some View {
        ContentView(store: store,
                    document: document,
                    graphUI: document.graphUI,
                    alertState: alertState,
                    routerNamespace: routerNamespace)
    }
}

struct MaybeIgnoreSafeAreasModifier: ViewModifier {
    var hideAllSafeAreas: Bool = false

    func body(content: Content) -> some View {
        // logInView("MaybeIgnoreSafeAreasModifier: body: hideAllSafeAreas: \(hideAllSafeAreas)")

        if GraphUIState.isPhoneDevice {
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

//#Preview("Project View") {
//    let graphState = GraphState(id: .mockProjectId,
//                                store: nil)
//    graphState.libraryLoadingStatus = .loading
//
//    return StitchProjectView(graphState: graphState,
//                             graphUI: graphState.graphUI,
//                             alertState: .init())
//}
