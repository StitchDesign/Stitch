//
//  ProjectsListItemView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/20/21.
//

import SwiftUI
import StitchSchemaKit

extension Color {
    var isDarkBackground: Bool {
        let color = self
        var r, g, b, a: CGFloat
        (r, g, b, a) = (0, 0, 0, 0)
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return  luminance < 0.50
    }
}

struct ProjectsListItemIconView: View {

    let projectThumbnail: UIImage?
    
    let previewWindowBackgroundColor: Color?
    
    // Important: UIImage is a reference type, and the thummbnail URL itself never changes;
    // so we trigger reunder-upon-thumbnail-write by listening to ProjectLoader's modifiedDate
    var modifiedDate: Date? = nil // nil = project is loading, or failed to load
    
    var isLoading: Bool = false
    
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
            .padding([.top, .bottom], 8)
            .frame(width: PROJECTSVIEW_ITEM_WIDTH,
                   height: PROJECTSVIEW_ITEM_WIDTH - (PROJECTSVIEW_ITEM_WIDTH/3))
             .background {
                 if projectThumbnail.isDefined,
                    let previewWindowBackgroundColor = previewWindowBackgroundColor {
                     previewWindowBackgroundColor.overlay {
                         (previewWindowBackgroundColor.isDarkBackground ? Color.white : .black).opacity(0.2)
                     }
                }
            }
             .cornerRadius(8)
             .contentShape(Rectangle()) // for consistent tappable thumbnail area
             .projectItemBlur(willBlur: isLoading)
             .overlay {
                 if isLoading {
                     ProgressView()
                         .progressViewStyle(.circular)
                 }
             }
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
        }
        .modifier(ProjectListItemSizingModifier())
    }
}

struct ProjectsListItemView: View {
    
    @Environment(StitchStore.self) var store
    @State private var isLoadingForPresentation = false // displays loading screen when tapped
    
    @Bindable var projectLoader: ProjectLoader
    let documentLoader: DocumentLoader
    let namespace: Namespace.ID

    var document: StitchDocument? {
        switch projectLoader.loadingDocument {
        case .loaded(let data, _):
            return data
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
                ProjectsListItemIconView(projectThumbnail: nil,
                                         previewWindowBackgroundColor: nil)
                    .modifier(ProjectsListItemErrorOverlayViewModifer())
            case .loaded(let document, let thumbnail):
                #if DEV_DEBUG
                logInView("LOADED: \(document.name) \(document.id)")
                #endif
                ProjectsListItemIconView(
                    projectThumbnail: thumbnail,
                    previewWindowBackgroundColor: document.previewWindowBackgroundColor,
                    modifiedDate: projectLoader.modifiedDate,
                    isLoading: self.isLoadingForPresentation)
                    .onTapGesture {
                        self.isLoadingForPresentation = true
                        
                        store.handleProjectTapped(projectLoader: self.projectLoader,
                                                  isPhoneDevice: GraphUIState.isPhoneDevice) {
                            self.isLoadingForPresentation = false
                        }
                    }
                    .transition(.opacity)
            }
        } labelView: {
            switch projectLoader.loadingDocument {
            case .loaded(let document, _):
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
                
                Task.detached(priority: .background) { [weak documentLoader, weak projectLoader] in
                    if let projectLoader = projectLoader {
                        await documentLoader?.loadDocument(projectLoader)                        
                    }
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
        ProjectsListItemIconView(projectThumbnail: nil,
                                 previewWindowBackgroundColor: nil)
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
