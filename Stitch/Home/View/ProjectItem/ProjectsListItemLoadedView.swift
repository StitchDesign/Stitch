//
//  ProjectsListItemLoadedView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/24/22.
//

import SwiftUI
import StitchSchemaKit

struct ProjectThumbnailTextField: View {
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
                             isPhoneDevice: Bool,
                             loadedCallback: @MainActor @Sendable @escaping () -> ()) {
        Task { [weak projectLoader] in
            guard let projectLoader = projectLoader else { return }
            
            let documentViewModel = await StitchDocumentViewModel(
                from: document,
                isPhoneDevice: isPhoneDevice,
                projectLoader: projectLoader,
                store: self
            )
            
            // TODO: DEC 12: use with actual migration logic
            // documentViewModel?.migrateCanvasItemsPositionsForNewUIScrollViewGraph()
            
            await MainActor.run { [weak self, weak documentViewModel] in
                guard let documentViewModel = documentViewModel else {
                    return
                }
                
                self?.navPath = [documentViewModel]
                loadedCallback()
            }
        }
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func migrateCanvasItemsPositionsForNewUIScrollViewGraph() {
        
        self.graph.nodes.values.forEach({ (node: NodeViewModel) in
            
            node.getAllCanvasObservers().forEach { (canvasItem: CanvasItemViewModel) in
                
                log("handleProjectTapped: node.id: \(node.id)")
                log("handleProjectTapped: canvasItem.position was: \(canvasItem.position)")
                
                // TODO: do this for a layer node's on-canvas inputs as well
                canvasItem.position.x += WHOLE_GRAPH_LENGTH/2
                canvasItem.position.y += WHOLE_GRAPH_LENGTH/2
                canvasItem.previousPosition = canvasItem.position
                
                log("handleProjectTapped: canvasItem.position is now: \(canvasItem.position)")
            }
        })
    }
}


extension String {
    func validateProjectTitle() -> String {
        self.isEmpty ? STITCH_PROJECT_DEFAULT_NAME : self
    }
}
