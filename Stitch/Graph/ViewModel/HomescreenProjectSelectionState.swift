//
//  HomescreenProjectSelectionState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/14/25.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct HomescreenProjectSelectionState: Equatable, Codable, Hashable {
    var isSelecting = false
    var selections: Set<ProjectId> = .init()
}

struct HomescreenProjectSelectionToggled: StitchStoreEvent {

    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        withAnimation(.linear(duration: 0.2)) {
            store.homescreenProjectSelectionState.isSelecting.toggle()
            if !store.homescreenProjectSelectionState.isSelecting {
                // wipe selections
                store.homescreenProjectSelectionState.selections = .init()
            }
        }
        return .noChange
    }
}

struct ProjectTappedDuringHomescreenSelection:  StitchStoreEvent {
    let projectId: ProjectId
    
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        withAnimation(.linear(duration: 0.2)) {
            if store.homescreenProjectSelectionState.selections.contains(projectId) {
                store.homescreenProjectSelectionState.selections.remove(projectId)
            } else {
                store.homescreenProjectSelectionState.selections.insert(projectId)
            }
        }
        return .noChange
    }
}

struct DeleteHomescreenSelectedProjects: StitchStoreEvent {
    
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        store.homescreenProjectSelectionState.selections.forEach { (selectedProject: ProjectId) in
            if let project = store.allProjectUrls.first(where: { $0.loadedDocument?.0.id == selectedProject }),
               let (loadedDocument, _) = project.loadedDocument {
                
                store.deleteProject(document: loadedDocument)
                store.homescreenProjectSelectionState.selections.remove(selectedProject)
            }
        }
        withAnimation(.linear(duration: 0.2)) {
            store.homescreenProjectSelectionState.isSelecting = false
        }
        
        return .noChange
    }
}
