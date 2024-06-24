//
//  ProjectsListView.swift
//  prototype
//
//  Created by Elliot Boschwitz on 5/19/22.
//

import SwiftUI
import StitchSchemaKit

let PROJECTS_LIST_VIEW_COLUMNS: [GridItem] = Array(
    repeating: .init(.adaptive(minimum: PROJECTSVIEW_ITEM_WIDTH),
                     spacing: 20),
    count: 1)

/// A `ViewBuilder` for displaying project thumbnails in a scroll view.
struct ProjectsScrollView<T: View>: View {
    @ViewBuilder var scrollView: () -> T

    var body: some View {
        ScrollView {
            LazyVGrid(columns: PROJECTS_LIST_VIEW_COLUMNS, alignment: .center) {
                scrollView()
            }
            .padding()
        }
    }
}

struct ProjectsListView: View {
    @Bindable var store: StitchStore

    let namespace: Namespace.ID

    var body: some View {
        ZStack {
            Stitch.APP_BACKGROUND_COLOR.zIndex(-1).edgesIgnoringSafeArea(.all)

            ProjectsScrollView {
                ForEach(store.allProjectUrls) { projectLoader in
                    ProjectsListItemView(projectLoader: projectLoader,
                                         documentLoader: store.documentLoader,
                                         namespace: namespace)
                }
            } // ProjectsScrollView
        }
        .refreshable {
            log("ProjectsListView .refreshable")
            store.directoryUpdated()
        }
    }
}
