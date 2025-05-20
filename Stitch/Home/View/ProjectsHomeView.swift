//
//  ProjectsHomeView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/20/21.
//

import SwiftUI
import StitchSchemaKit

let PROJECTSVIEW_ITEM_WIDTH: CGFloat = 200

/// Wrapper view for projects scroll view that also includes toolbar.
/// Used by both Catalyst and iPad.
struct ProjectsHomeView: View {
    
    @Bindable var store: StitchStore
    let namespace: Namespace.ID
    @State private var searchQuery: String = ""

    var filteredProjects: [ProjectLoader] {
        if searchQuery.isEmpty {
            return store.allProjectUrls ?? []
        } else {
            return store.allProjectUrls?.filter { projectLoader in
                if case .loaded(let document, _) = projectLoader.loadingDocument {
                    return document.name.localizedCaseInsensitiveContains(searchQuery)
                }
                return false
            } ?? []
        }
    }

    @MainActor
    var alertState: ProjectAlertState {
        store.alertState
    }

    @MainActor
    private func undoToastTapped() {
        guard let deletedGraphId = self.alertState.deletedGraphId else {
            return
        }
        store.undoDeleteProject(projectId: deletedGraphId)
    }
    
    var showWelcomeExperience: Bool {
        // Only show welcome UX once we confirm user has no projects
        guard let allProjectUrls = store.allProjectUrls else {
            return false
        }
        
        return !isPhoneDevice && allProjectUrls.isEmpty
    }

    var body: some View {
        ZStack {
            VStack {
                
#if DEV_DEBUG
                debugView
#endif
                
                ProjectsListView(store: store, namespace: namespace, projects: filteredProjects)
            }

            if showWelcomeExperience {
                SampleProjectsView(store: store)
                    .transition(.opacity)
            }
        }
        
        // Shows undo delete toast when GraphUI state has recenetly deleted project ID
        // Should onExpireAction only fire an action if alertState.deletedGraphId still defined ?
        .toast(willShow: alertState.deletedGraphId.isDefined,
               messageLeft: "File Deleted",
               messageRight: "Undo",
               onTapAction: self.undoToastTapped,
               onExpireAction: store.projectDeleteToastExpired)
        .stitchSheet(isPresented: alertState.showAppSettings,
                     titleLabel: "Settings",
                     hideAction: store.hideAppSettingsSheet,
                     sheetBody: {
            AppSettingsView(isOptionRequiredForShortcut: store.isOptionRequiredForShortcut)
        })
        .stitchSheet(isPresented: store.showsSampleProjectModal,
                     titleLabel: "Sample Projects",
                     hideAction: { store.showsSampleProjectModal = false }) {
            SampleProjectsList(store: store)
        }
        .onTapGesture {
            store.projectIdForTitleEdit = nil
        }
        .animation(.stitchAnimation, value: showWelcomeExperience)
    }
    
    @ViewBuilder
    var debugView: some View {
        // Search Bar
        TextField("Search Projects...", text: $searchQuery)
            .padding()
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.horizontal)
        
        HStack {
            
            let activelySelectingProjects = store.homescreenProjectSelectionState.isSelecting
            let selectedProjectCount = store.homescreenProjectSelectionState.selections.count
            
            Button {
                dispatch(HomescreenProjectSelectionToggled())
            } label: {
                Text(store.homescreenProjectSelectionState.isSelecting ? "Stop Selecting" : "Select Projects")
            }
            
            Button {
                dispatch(DeleteHomescreenSelectedProjects())
            } label: {
                Text("Delete \(selectedProjectCount) selected projected")
            }
            .opacity(activelySelectingProjects ? 1 : 0)


            // Some spacing
            Rectangle().fill(.clear).frame(width: 32, height: 8)
            
            // Undo and Redo buttons
            
            Button {
                UNDO_ACTION()
            } label: {
                Text("Undo")
            }
            Button {
                REDO_ACTION()
            } label: {
                Text("Redo")
            }
        }
    }
}

extension GraphId {
    static let mockGraphId = GraphId()
}

// struct ProjectsList_Previews: PreviewProvider {

//     @Namespace static var mockNamespace

//     static let projectsDict: ProjectsDict = [
//         .mockGraphId: .loaded(ProjectSchema(
//                                     metadata: ProjectMetadata(name: "Test"),
//                                     schema: GraphSchema()))
//     ]

//     static let projectsState = StitchProjects(
//         projectsDict: projectsDict,
//         sortedGraphIds: [.mockGraphId])

//     static var previews: some View {
//         projectsHomeView
//             .previewDevice(IPAD_PREVIEW_DEVICE_NAME)

//         projectsHomeView
//             .previewDevice(IPHONE_PREVIEW_DEVICE_NAME)
//     }

//     static var projectsHomeView: some View {
//         ProjectsHomeView(projectsState: projectsState,
//                          projectIdForTitleEdit: nil,
//                          alertState: ProjectAlertState(),
//                          namespace: mockNamespace,
//                          homeId: UUID())
//     }
// }
