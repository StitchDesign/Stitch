//
//  ProjectsHomeView.swift
//  prototype
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
            return store.allProjectUrls
        } else {
            return store.allProjectUrls.filter { projectLoader in
                if case .loaded(let document) = projectLoader.loadingDocument {
                    return document.name.localizedCaseInsensitiveContains(searchQuery)
                }
                return false
            }
        }
    }

    @MainActor
    var alertState: ProjectAlertState {
        store.alertState
    }

    @MainActor
    private func undoToastTapped() {
        guard let deletedProjectId = self.alertState.deletedProjectId else {
            return
        }
        store.undoDeleteProject(projectId: deletedProjectId)
    }

    var body: some View {
        VStack {
            // Search Bar
#if DEV_DEBUG
            TextField("Search Projects...", text: $searchQuery)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
#endif

            // Undo button for debugging
            #if DEV_DEBUG
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
            #endif
            ProjectsListView(store: store, namespace: namespace, projects: filteredProjects)
        }
        .modifier(SampleAppsSheet(showSampleAppsSheet: alertState.showSampleAppsSheet,
                                  namespace: namespace))
        .modifier(LogShareViewModifier(logEntriesURL: alertState.logExport.logsURL))
        .modifier(LogExportLoadingView(preparingLogs: alertState.logExport.preparingLogs))
        // Shows undo delete toast when GraphUI state has recenetly deleted project ID
        // Should onExpireAction only fire an action if alertState.deletedProjectId still defined ?
        .toast(willShow: alertState.deletedProjectId.isDefined,
               messageLeft: "File Deleted",
               messageRight: "Undo",
               onTapAction: self.undoToastTapped,
               onExpireAction: store.projectDeleteToastExpired)
        .stitchSheet(isPresented: alertState.showAppSettings,
                     titleLabel: "Settings",
                     hideAction: store.hideProjectSettingsSheet) {
            AppSettingsView()
        }
        .onTapGesture {
            store.projectIdForTitleEdit = nil
        }
    }
}

extension ProjectId {
    static let mockProjectId = ProjectId()
}

// struct ProjectsList_Previews: PreviewProvider {

//     @Namespace static var mockNamespace

//     static let projectsDict: ProjectsDict = [
//         .mockProjectId: .loaded(ProjectSchema(
//                                     metadata: ProjectMetadata(name: "Test"),
//                                     schema: GraphSchema()))
//     ]

//     static let projectsState = StitchProjects(
//         projectsDict: projectsDict,
//         sortedProjectIds: [.mockProjectId])

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
