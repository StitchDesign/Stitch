//
//  CopyAndPasteNodesActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/20/23.
//

import Foundation
import StitchSchemaKit
import UIKit

typealias PredicateT<T> = (T) -> Bool
typealias PredicateTK<T, K> = (T, K) -> Bool

// Must be
// "Cut" = cuts both selected nodes AND selected comments

struct SelectedGraphItemsCut: GraphEvent {

    func handle(state: GraphState) {
        log("SelectedGraphNodesCut called")
        
        guard !state.llmRecording.isRecording else {
            log("Cut disabled during LLM Recording")
            return
        }

        // Copy selected graph data to clipboard
        state.copyToClipboard(selectedNodeIds: state.selectedNodeIds.compactMap(\.nodeCase).toSet)

        // Delete selected nodes
        state.selectedNodeIds.forEach {
            state.deleteCanvasItem($0)
        }

//        state.updateSidebarListStateAfterStateChange(state.sidebarExpandedItems)
        state.updateSidebarListStateAfterStateChange()
        
        // TODO: why is this necessary?
        _updateStateAfterListChange(
            updatedList: state.sidebarListState,
            expanded: state.getSidebarExpandedItems(),
            graphState: state)
        
        // TODO: delete comment boxes for cut
        //        graphSchema = deleteSelectedCommentBoxes(
        //            graphSchema: graphSchema,
        //            graphState: graphState)
    }
}

// "Copy" = copy shortcut, which copies BOTH nodes AND comments
// struct SelectedGraphNodesCopied: AppEnvironmentEvent {
struct SelectedGraphItemsCopied: GraphEvent {
    func handle(state: GraphState) {
        log("SelectedGraphNodesCopied called")
        
        guard !state.llmRecording.isRecording else {
            log("Copy disabled during LLM Recording")
            return
        }
                
        state.copyToClipboard(selectedNodeIds: state.selectedNodeIds.compactMap(\.nodeCase).toSet)
    }
}

// "Paste" = past shortcut, which pastes BOTH nodes AND comments
// struct SelectedGraphNodesPasted: AppEnvironmentEvent {
struct SelectedGraphItemsPasted: GraphEventWithResponse {

    func handle(state: GraphState) -> GraphResponse {
        
        guard !state.llmRecording.isRecording else {
            log("Paste disabled during LLM Recording")
            return .noChange
        }
        
        guard let pasteboardUrl = UIPasteboard.general.url else {
            return .noChange
        }

        do {
            let componentData = try Data(
                contentsOf: pasteboardUrl.appendingDataJsonPath()
            )
            let newComponent = try getStitchDecoder().decode(StitchClipboardContent.self, from: componentData)
            let currentDoc = state.createSchema()
            let importedFiles = ComponentEncoder.readAllImportedFiles(rootUrl: pasteboardUrl)
            
            
            state.insertNewComponent(component: newComponent,
                                     encoder: state.documentEncoderDelegate,
                                     copiedFiles: importedFiles)
            return .persistenceResponse
        } catch {
            log("SelectedGraphItemsPasted error: \(error)")
            return .noChange
        }
    }
}
