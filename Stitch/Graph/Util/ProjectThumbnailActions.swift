//
//  ProjectThumbnailActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/10/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// Note: needs to be a StitchStore event, because called after current graph has been closed
struct GenerateProjectThumbnailEvent: StitchStoreEvent {
    
    let graph: GraphState
    
    @MainActor
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        
         // log("GenerateProjectThumbnailEvent called")
        
        // is this dying?
        Task { // .effectOnly {

             // log("GenerateProjectThumbnailEvent Task")
            
            // TODO: Will this capture cause a memory leak?
            // Note: we need to modify some views
            graph.isGeneratingProjectThumbnail = true
            
            // Recalculate the entire graph immediately, so that e.g. camera evals run with their image taking setting "off":
            graph.calculate(from: graph.allNodesToCalculate)
            
            // Note: we pass in the existing `generatedPreview: GeneratePreview` becaue we want to reuse the exact images etc. already inside PreviewImage view etc.; but that doesn't actually help.
            let generatedPreview = GeneratePreview(graph: graph)
            
            let view = generatedPreview
                .frame(graph.previewWindowSize)
                .background(graph.previewWindowBackgroundColor)
                .clipped()

            // TODO: Why does .effectOnly { ... } with these lines give us a concurrency warning?
            //            let renderer = await ImageRenderer(content: view)
            //            let image = await renderer.uiImage

            let renderer = ImageRenderer(content: view)
            
            guard let image = renderer.uiImage else {
                log("GenerateProjectThumbnailEvent: no image")
                return
            }
            
            guard let data = image.pngData() else {
                log("GenerateProjectThumbnailEvent: no pngData from image")
                return
            }
            
            let filename = graph.rootUrl.appendProjectThumbnailPath()
            
            // log("GenerateProjectThumbnailEvent: filename: \(filename)")
            do {
                try data.write(to: filename)
                
                // log("GenerateProjectThumbnailEvent: wrote thumbnail")
                
                // TODO: a better way to trigger an update of the project's icon on the homescreen? Even modifying the modifiedDate directly would cause the project to jump to the front of the homescreen grid
                
                // TODO: for some projects, `graph.encodeProject` fails because the StoreDelegate is missing / has no documentLoader
//                 graph.encodeProjectInBackground()
                
                // TODO: Does this reference to a reference-type like `GraphState` or `StitchStore` introduce memory leaks? Note that, overall, we use more memory in the homescreen now that project thumbnail images are loaded.
                try await store.documentLoader.encodeVersionedContents(
                    document: graph.createSchema())
            } catch {
                log("GenerateProjectThumbnailEvent: error: \(error)")
            }
        } // Task // .effectOnly
        
        // Not needed, since this graph is thrown away after generating the project thumbnail
        // graph.isGeneratingProjectThumbnail = false
        
        // log("GenerateProjectThumbnailEvent: leaving event handler")
        return .noChange
    }
}
