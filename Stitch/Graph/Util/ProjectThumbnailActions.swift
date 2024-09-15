//
//  ProjectThumbnailActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/10/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension StitchStore {
    @MainActor
    func createThumbnail(from documentViewModel: StitchDocumentViewModel) {
        // Note: we need to modify some views
        documentViewModel.isGeneratingProjectThumbnail = true
        
        // Recalculate the entire graph immediately, so that e.g. camera evals run with their image taking setting "off":
        documentViewModel.calculate(from: documentViewModel.allNodesToCalculate)
        
        // Note: we pass in the existing `generatedPreview: GeneratePreview` becaue we want to reuse the exact images etc. already inside PreviewImage view etc.; but that doesn't actually help.
        let generatedPreview = GeneratePreview(document: documentViewModel)
        
        let view = generatedPreview
            .frame(documentViewModel.previewWindowSize)
            .background(documentViewModel.previewWindowBackgroundColor)
            .clipped()
        
        let document = documentViewModel.createSchema()
        let rootUrl = documentViewModel.graph.rootUrl
        let filename = rootUrl.appendProjectThumbnailPath()
        
        Task { [weak self] in
            guard let store = self else {
                log("GenerateProjectThumbnailEvent: no image")
                return
            }
            
            // MARK: TECHNICALLY the renderer and .uImage should be made on the main thread, but this works and dispatching a background thread loses uiImage access
            let renderer = ImageRenderer(content: view)
            let image = renderer.uiImage
            
            guard let image = image,
                  let data = image.pngData() else {
                log("GenerateProjectThumbnailEvent: no pngData from image")
                return
            }
            
            // log("GenerateProjectThumbnailEvent: filename: \(filename)")
            do {
                try data.write(to: filename)
                
                // log("GenerateProjectThumbnailEvent: wrote thumbnail")
                
                // TODO: a better way to trigger an update of the project's icon on the homescreen? Even modifying the modifiedDate directly would cause the project to jump to the front of the homescreen grid
                
                // TODO: for some projects, `graph.encodeProject` fails because the StoreDelegate is missing / has no documentLoader
                //                 graph.encodeProjectInBackground()
                try await store.documentLoader.encodeVersionedContents(
                    document: document)
            } catch {
                log("GenerateProjectThumbnailEvent: error: \(error)")
            }
        }
    }
}
