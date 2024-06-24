//
//  ProjectsListItemView.swift
//  prototype
//
//  Created by Christian J Clampitt on 9/20/21.
//

import SwiftUI
import StitchSchemaKit

struct ProjectsListItemIconView: View {

    let projectThumbnail: UIImage?
    
    // Important: UIImage is a reference type, and the thummbnail URL itself never changes;
    // so we trigger reunder-upon-thumbnail-write by listening to ProjectLoader's modifiedDate
    var modifiedDate: Date? = nil // nil = project is loading, or failed to load
    
    var image: UIImage {
        if let projectThumbnail = projectThumbnail {
            return projectThumbnail
        } else {
            return UIImage(named: "defaultGraphView")!
        }
    }
        
    var body: some View {
        // TODO: why did AsyncImage cause problems even when modifiedDate is passed in?
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
        // The original ~size of the old project icon; needed for contentShape
        // TODO: will be updated after small redesign?
            .frame(width: PROJECTSVIEW_ITEM_WIDTH,
                   height: PROJECTSVIEW_ITEM_WIDTH - (PROJECTSVIEW_ITEM_WIDTH/3))
            .contentShape(Rectangle()) // for consistent tappable thumbnail area
    }
}

/// Helper view used by both loading and loaded project items.
struct ProjectsListItemThumbnailView<Thumbnail: View, Label: View>: View {
    @ViewBuilder var thumbnailView: () -> Thumbnail
    @ViewBuilder var labelView: () -> Label

    var body: some View {
        VStack(alignment: .leading) {
            thumbnailView()
            labelView()
                .frame(height: PROJECTSVIEW_ITEM_TEXT_HEIGHT,
                       alignment: .leading)
                .padding(PROJECTSVIEW_ITEM_TEXT_PADDING)
        }
        .modifier(ProjectListItemSizingModifier())
    }
}

struct ProjectsListItemView: View {
    
    @Environment(StitchStore.self) var store // added
    
    @Bindable var projectLoader: ProjectLoader
    let documentLoader: DocumentLoader
    let namespace: Namespace.ID

    var document: StitchDocument? {
        switch projectLoader.loadingDocument {
        case .loaded(let document):
            return document
        default:
            return nil
        }
    }

    var body: some View {
        ProjectsListItemThumbnailView {
            switch projectLoader.loadingDocument {
            case .initialized, .loading:
                ProjectThumbnailLoadingView()
            case .failed:
                ProjectsListItemIconView(projectThumbnail: nil)
                    .modifier(ProjectsListItemErrorOverlayViewModifer())
            case .loaded(let document):
                #if DEV_DEBUG
                logInView("LOADED: \(document.name) \(document.id)")
                #endif
                                
                ProjectsListItemIconView(
                    projectThumbnail: document.getProjectThumbnailImage(),
                    modifiedDate: projectLoader.modifiedDate)
                    .onTapGesture {
                        dispatch(ProjectTapped(documentURL: projectLoader.url))
                    }
                    .transition(.opacity)
            }
        } labelView: {
            switch projectLoader.loadingDocument {
            case .loaded(let document):
                ProjectThumbnailTextField(document: document,
                                          namespace: namespace)
            default:
                // Blank text view to copy height of loaded view
                Color.clear
            }
        }
        .onChange(of: projectLoader.loadingDocument, initial: true) {
            if self.projectLoader.loadingDocument == .initialized {
                projectLoader.loadingDocument = .loading
                
                Task.detached(priority: .background) {
                    await documentLoader.loadDocument(projectLoader)
                }
            }
        }
        .onDisappear {
            self.projectLoader.loadingDocument = .initialized
        }
        .projectContextMenu(document: document,
                            url: projectLoader.url)
        .animation(.stitchAnimation, value: projectLoader.loadingDocument)
    }
}

struct ProjectListItemSizingModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: PROJECTSVIEW_ITEM_WIDTH)
            .padding()
    }
}

struct ProjectThumbnailLoadingView: View {
    var body: some View {
        ProjectsListItemIconView(projectThumbnail: nil)
            .projectItemBlur()
            .overlay {
                ProgressView()
                    .progressViewStyle(.circular)
            }
    }
}

// struct ProjectView_Previews: PreviewProvider {
//    static var previews: some View {
//        ProjectView()
//    }
// }
