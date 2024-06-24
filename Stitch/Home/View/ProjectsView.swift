//
//  ProjectsView.swift
//  prototype
//
//  Created by Elliot Boschwitz on 8/18/21.
//

import SwiftUI
import ReSwift

let PROJECTSVIEW_ITEM_WIDTH: CGFloat = 200

struct ProjectsView: View {

    let projects: [ProjectSchema]
    let documentsURL: DocumentsURL
    let projectIdForTitleEdit: ProjectId.Id?
    let namespace: Namespace.ID

    var body: some View {
        ProjectsListView(projectsInfos: projects,
                         documentsURL: documentsURL,
                         projectIdForTitleEdit: projectIdForTitleEdit,
                         namespace: namespace)
    }
}
