//
//  ProjectsListItemLoadedView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/24/22.
//

import SwiftUI
import StitchSchemaKit

extension ProjectLoader {
    @MainActor
    var loadedDocument: (StitchDocument, UIImage?)? {
        switch self.loadingDocument {
        case .loaded(let doc, let image):
            return (doc, image)
        default:
            return nil
        }
    }
}

struct ProjectThumbnailTextField: View {
    @Environment(StitchStore.self) var store
    
    @FocusedValue(\.focusedField) private var focusedField
    @State private var contextMenuOpen: Bool = false
    @State private var projectName: String = ""
    @FocusState private var isFocused: Bool

    let document: StitchDocument
    let namespace: Namespace.ID

    var body: some View {
        editProjectName
            .contentShape(Rectangle()) // for larger tap hit area
    }
    
    @MainActor
    var editProjectName: some View {
        TextField("Project Title", text: $projectName) {
            validateProjectTitle()
        }
        .transition(.opacity)
        .onSubmit {
            var document = document
            document.graph.name = projectName

            // TODO: why wasn't the encodeDocument logic enough to trigger a view re-render? But also, it's better not to rely on a side-effect (encoding) to trigger a view re-render.
            // TODO: will this have properly updated the modified-date on the project?
            
            // Manually update the project's name in the state that other views (e.g. ProjectsListItemView) listen to.
            if let project: ProjectLoader = store.allProjectUrls?.first(where: { $0.loadedDocument?.0.id == document.id }),
               let index = store.allProjectUrls?.firstIndex(where: { $0.id == project.id }),
               let (loadedDocument, loadedImage) = project.loadedDocument {
                
                // Update the project's name
                var loadedDocument = loadedDocument
                loadedDocument.graph.name = projectName
                project.loadingDocument = .loaded(loadedDocument, loadedImage)
                
                // Place the project back in state
                store.allProjectUrls?[index] = project
            }
            
            Task(priority: .high) {
                do {
                    // Must write a version of the project with an updated name
                    try StitchDocument.encodeDocument(document)
                } catch {
                    log("editProjectName: onSubmit: error: \(error)")
                }
            }
        }
        .onChange(of: document.name, initial: true) {
            self.projectName = document.name
        }
        .focusedValue(\.focusedField, .projectTitle)
        .focused($isFocused)
        .font(STITCH_FONT)
        .lineLimit(1)
        .onChange(of: isFocused) {
            if !isFocused {
                validateProjectTitle()
            }
        }
    }

    @MainActor
    func validateProjectTitle() {
        self.projectName = self.projectName.validateProjectTitle()
    }
}

extension StitchStore {
    /// Async attempts to re-load document from URL in case migration is needed.
    /// We only encode and update the project if the user makes an edit, which helps control project sorting order
    /// so that opened projects only re-sort when edited.
    @MainActor
    func handleProjectTapped(projectLoader: ProjectLoader,
                             document: StitchDocument,
                             isDebugMode: Bool,
                             loadedCallback: @MainActor @Sendable @escaping () -> ()) {
        Task { [weak projectLoader] in
            guard let projectLoader = projectLoader else { return }
            
            let documentViewModel = await StitchDocumentViewModel(
                from: document,
                projectLoader: projectLoader,
                store: self,
                isDebugMode: isDebugMode
            )
            
            await MainActor.run { [weak self, weak documentViewModel, weak projectLoader] in
                guard let projectLoader = projectLoader,
                      let documentViewModel = documentViewModel else {
                    return
                }
                
                projectLoader.documentViewModel = documentViewModel
                self?.navPath = [.project(projectLoader)]
                loadedCallback()
            }
        }
    }
}

extension String {
    func validateProjectTitle() -> String {
        self.isEmpty ? STITCH_PROJECT_DEFAULT_NAME : self
    }
}
