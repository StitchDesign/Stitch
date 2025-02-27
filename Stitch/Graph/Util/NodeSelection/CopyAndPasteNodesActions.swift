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

        state.updateGraphData()
        state.encodeProjectInBackground()
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
struct SelectedGraphItemsPasted: GraphEvent {

    func handle(state: GraphState) {
        
        guard !state.llmRecording.isRecording else {
            log("Paste disabled during LLM Recording")
            return
        }
        
        let pasteboardUrl = StitchClipboardContent.rootUrl

        do {
            let componentData = try Data(contentsOf: pasteboardUrl.appendingVersionedSchemaPath())
            let newComponent = try getStitchDecoder().decode(StitchClipboardContent.self, from: componentData)
            let importedFiles = try ComponentEncoder.readAllImportedFiles(rootUrl: pasteboardUrl)
            
            Task(priority: .high) { [weak state] in
                guard let state = state else { return }
    
                await state.insertNewComponent(component: newComponent,
                                               encoder: state.documentEncoderDelegate,
                                               copiedFiles: importedFiles,
                                               isCopyPaste: true)
                state.encodeProjectInBackground()
            }
        } catch {
            log("SelectedGraphItemsPasted error: \(error)")
        }
    }
}
