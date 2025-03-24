//
//  ProjectDestructiveActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/26/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension StitchStore {
    // Called when user elects to remove project locally after it's been deleted elsewhere
    @MainActor
    func handleDeleteAndExitCurrentProject() {
        guard let document = self.currentDocument else {
            log("DeleteAndExitCurrentProject: current project was not found.")
            self.alertState.stitchFileError = .currentProjectNotFound
            return
        }

        self.navPath = []
        self.deleteProject(document: document.createSchema())
    }
}

extension StitchStore {
    @MainActor
    func deleteProject(document: StitchDocument) {
        let projectId = document.id

        switch StitchFileManager.removeStitchProject(
            url: document.rootUrl,
            projectId: projectId) {

        case .success:
            log("StitchStore: deleteProject: success")
            // If undo is called, re-import the project from recently deleted
            let undoEvents: [Action] = [UndoDeleteProject(projectId: projectId) ]
            let redoEvents: [Action] = [ProjectDeleted(document: document)]

            // Displays toast UI on projects screen
            
            // TODO: fix 'Undo Delete' on iPhone
            if !Stitch.isPhoneDevice {
                self.alertState.deletedProjectId = projectId
            }
            // self.alertState.deletedProjectId = projectId

            self.saveProjectDeletionUndoHistory(undoActions: undoEvents,
                                                redoActions: redoEvents)

        case .failure(let error):
            log("StitchStore: deleteProject: failure")
            self.alertState.stitchFileError = error
        }
    }

    /// Clears undo button toast UI on projects screen.
    @MainActor
    func projectDeleteToastExpired() {
        self.alertState.deletedProjectId = nil
    }
}

extension StitchStore {
    @MainActor
    func undoDeleteProject(projectId: ProjectId) {
        // Find URL from recently deleted
        let deletedProjectURL = StitchFileManager.recentlyDeletedURL
            .appendingStitchProjectDataPath("\(projectId)")

        // Reimports deleted project
        Task {
            do {
                let _ = try await StitchDocument
                    .openDocument(from: deletedProjectURL,
                                  isImport: true)
            } catch {
                await MainActor.run { [weak self] in
                    self?.alertState.stitchFileError = .projectWriteFailed
                }
            }

            await MainActor.run { [weak self] in
                // Remove toast on projects screen
                self?.alertState.deletedProjectId = nil
            }
        }
    }
}

extension StitchStore {
    @MainActor
    func deleteAllProjectsConfirmed() {
        self.alertState.showDeleteAllProjectsConfirmation = false

        if let contents = StitchFileManager.readDirectoryContents(StitchFileManager.documentsURL).value {
            contents.forEach { url in
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
