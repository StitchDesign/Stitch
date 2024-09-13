//
//  ProjectsListItemLoadedView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/24/22.
//

import SwiftUI
import StitchSchemaKit

struct ProjectThumbnailTextField: View {
    @Environment(StitchStore.self) var store
    @FocusedValue(\.focusedField) private var focusedField

    let document: StitchDocument
    let namespace: Namespace.ID

    @State private var contextMenuOpen: Bool = false
    @State private var projectName: String = ""
    @FocusState private var isFocused: Bool

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
            Task(priority: .background) { [weak store] in
                do {
                    var doc = document
                    doc.name = projectName
                    // Must write a version of the project with an updated name
                    try await store?.documentLoader.encodeVersionedContents(document: doc)
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

struct ProjectTapped: StitchStoreEvent {
    let documentURL: URL
    
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        store.handleProjectTapped(documentURL: documentURL)
        return .noChange
    }
}

extension StitchStore {
    /// Async attempts to re-load document from URL in case migration is needed.
    /// We only encode and update the project if the user makes an edit, which helps control project sorting order
    /// so that opened projects only re-sort when edited.
    func handleProjectTapped(documentURL: URL) {
        // TODO: loading state needed
        Task(priority: .userInitiated) {
            do {
                guard let document = try await StitchDocument.openDocument(from: documentURL) else {
                    await MainActor.run { [weak self] in
                        self?.displayError(error: .projectSchemaNotFound)
                    }
                    return
                }
                
                await MainActor.run { [weak self] in
                    guard let store = self else {
                        fatalErrorIfDebug()
                        return
                    }
                    
                    log("handleProjectTapped: about to set \(document.projectId)")
                    let document = StitchDocumentViewModel(from: document,
                                                           store: store)
                    store.navPath = [document]
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.displayError(error: .projectSchemaNotFound)
                }
            }
        }
    }
}

extension String {
    func validateProjectTitle() -> String {
        self.isEmpty ? STITCH_PROJECT_DEFAULT_NAME : self
    }
}
