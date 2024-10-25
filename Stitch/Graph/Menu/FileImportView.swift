//
//  FileImport.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/3/21.
//

import SwiftUI
import AVFoundation

/// Displays the file picker for users to select media.
/// We use different solution on Catalyst due to both SwiftUI and UIKit bugs for their file picker APIs.
struct FileImportView: ViewModifier {
    @Environment(StitchStore.self) private var store
    let fileImportState: FileImportState

    func body(content: Content) -> some View {

        //        logInView("FileImportView: fileImportState: \(fileImportState)")

        let isImportingBinding = createBinding(fileImportState.isImporting) {
            //            logInView("FileImportView: isImportingBinding onSet: value: \($0)")
            if !$0 {
                dispatch(HideFileImportModal())
            }
        }

        return content
            .modifier(FileImportPickerView(fileImportState: fileImportState,
                                     isImporting: isImportingBinding) { (urls: [URL]) in
                                         
                guard let graph = store.currentDocument?.visibleGraph else {
                    return
                }
                
                let center = graph.graphUI.center(graph.localPosition)
                
                Task.detached { [weak store] in
                        guard let store = store else {
                            return
                        }
                        
                        // If a node import payload is set then we're supposed to set the media to an existing node
                        if let nodeImportPayload = fileImportState.nodeImportPayload {
                            //                logInView("FileImportView: existing node: nodeImportPayload: \(nodeImportPayload)")
                            await store.mediaFilesImportedToExistingNode(selectedFiles: urls,
                                                                         nodeImportPayload: nodeImportPayload)
                        } else {
                            //                logInView("FileImportView: new node: urls: \(urls)")
                            await store.mediaFilesImportedToNewNode(selectedFiles: urls,
                                                                    centerPostion: center)
                        }
                    }
                }
            )
    }
}

/// SwiftUI version of file picker.
struct FileImportPickerView: ViewModifier {
    let fileImportState: FileImportState
    @Binding var isImporting: Bool
    let selectedFilesCallback: MediaImportCallback

    func body(content: Content) -> some View {
        //        logInView("FileImportPickerView: fileImportState: \(fileImportState)")
        //        logInView("FileImportPickerView: isImporting: \(isImporting)")

        return content
            .fileImporter(
                isPresented: $isImporting,
                // .movie is video with audio
                // .video is video only
                allowedContentTypes: SUPPORTED_CONTENT_TYPES,
                allowsMultipleSelection: false // should allow multiple selection?
            ) { (result: Result<[URL], Error>) in
                switch result {
                case .success(let urls):

                    selectedFilesCallback(urls)
                case .failure(let error):
                    log("FileImportViewSwiftUI: error importing files: \(error)")
                    dispatch(ReceivedStitchFileError(error: .mediaFilesImportFailed(error)))
                }
            } // .fileImporter
    }
}
