//
//  ShareView.swift
//  prototype
//
//  Created by Christian J Clampitt on 9/9/21.
//

import SwiftUI
import StitchSchemaKit

// https://dev.to/hoyelam/share-sheet-uiactivityviewcontroller-within-swiftui-1hh

struct ShareViewModifier: ViewModifier {
    @State private var isProjectLoaded = false
    @State private var sharableURL: URL?
    let data: StitchDocumentData?
    @Binding var willPresent: Bool

    func body(content: Content) -> some View {
        // Use `isPresented` rather than `if-else`,
        // so that modal pop-up-from-bottom effect is retained.
        content
            .sheet(isPresented: $isProjectLoaded) {
                ActivityViewController(
                    activityItems: [
                        sharableURL
                    ]
                )
            }
            .onChange(of: data) {
                self.updateShareSheet()
            }
            .onChange(of: willPresent) {
                self.updateShareSheet()
            }
            .onChange(of: sharableURL) {
                self.isProjectLoaded = sharableURL.isDefined
            }
    } // var body

    func updateShareSheet() {
        if let document = self.data,
           willPresent {
            Task(priority: .high) {
                let newUrl = await StitchDocumentData.exportDocument(document).file

                await MainActor.run {
                    self.sharableURL = newUrl
                }
            }
        } else {
            self.isProjectLoaded = false
            self.willPresent = false
            self.sharableURL = nil
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {

    // Should be URLs or known Swift types like `UIImage` or `String`
    var activityItems: [URL?]

    var excludedActivityTypes: [UIActivity.ActivityType]?

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {

        let controller = UIActivityViewController(activityItems: activityItems,
                                                  applicationActivities: nil)

        controller.excludedActivityTypes = excludedActivityTypes

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController,
                                context: UIViewControllerRepresentableContext<ActivityViewController>) { }
}

struct StitchDocumentShareButton: View {
    @Binding var willPresentShareSheet: Bool
    let data: StitchDocumentData

    var body: some View {
        // MARK: ShareLink broken on iPad
        #if targetEnvironment(macCatalyst)
        ShareLink(item: data,
                  preview: SharePreview(data.document.name)) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        #else
        StitchButton {
            willPresentShareSheet.toggle()
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        #endif
    }
}

extension StitchStore {
    /*
     NOTE 1: theoretically we should be able to use the copy-paste logic for duplicating a project, however:
     - copy-paste alone did not work for media in a duplicated project (but okay for copy-pasting media node into an existing project); not sure why.
     - `GraphState(from: stitchDocument)` produces a semi-empty graph-state and does a side-effect; not sure that's appropriate for our case here; we may need an async version of `GraphState(from: stitchDocument)`?

     ^^ Worst case: for now, the nodes in a duplicated project will not be unique ids; but any nodes copied and pasted will have unique ids.
     So we would need to decide how important it is for node ids to be unique *across* projects, as opposed to just *within* a given project.


     NOTE 2: attempted an implementation with StitchDocument.exportDocument and StitchDocument.importDocument, but got multiple copies of same project, including some that were not able to be deleted
     
     ```swift
     do {
        try await finalDoc.installDocument()
        try await finalDoc.encodeVersionedContents()
        let result = await StitchDocument.exportDocument(finalDoc)
        let importedDoc = try await StitchDocument.importDocument(from: result.file, isImport: true)
     
        guard let importedDoc = importedDoc else {
            log("copyExistingProject: no importedDoc")
            return .failure(.copyFileFailed)
        }
     
        return .succcess
    } // do
     ```
     */
    func copyExistingProject(_ data: StitchDocumentData) async -> StitchFileVoidResult {
        var data = data
        data.document.projectId = .init()
        data.document.name += " copy"
        
        let subfolders: [URL] = [
            data.document.getProjectThumbnailURL(),
            data.document.getImportedFilesURL(),
            data.document.componentsDirUrl
        ]

        do {
            // TODO: Encoding a versioned content fails if the project does not already exist at that url. So we "install" the "new" document, then encode it. Ideally we'd do this in one step?
            try await self.documentLoader.installDocument(document: data.document)
            try DocumentLoader.encodeDocument(data)
            
            try subfolders.forEach {
                try FileManager.default.copyItem(at: $0, to: $0)
            }

            return .success
        } catch {
            log("copyExistingProject: error: \(error)")
            return .failure(.projectDuplicationFailed)
        }
    }
}

struct ProjectContextMenuModifer: ViewModifier {
    @Environment(StitchStore.self) private var store
    @State var willPresentShareSheet = false

    let data: StitchDocumentData?
    let url: URL

    func body(content: Content) -> some View {
        return content
            .contextMenu {
                if let data = data {
                    StitchDocumentShareButton(willPresentShareSheet: $willPresentShareSheet,
                                              data: data)
                    
                    StitchButton(action: {
                        Task { [weak store] in
                            await store?.copyExistingProject(data)
                        }
                    }, label: {
                        Text("Duplicate")
                        Image(systemName: "doc.on.doc")
                    })
                    
                    // TODO: follow the full logic in `DeleteProject` to allow for undoing a project deletion, showing 'project recently deleted' modal etc.
                    // -- see `DeleteProject` and `removeStitchProject`
                    StitchButton(role: .destructive,
                                 action: {
                        // log("ProjectContextMenuModifier: will attempt to delete URL: \(projectURL)")
                        dispatch(ProjectDeleted(data: data))
                    }, label: {
                        Text("Delete")
                        Image(systemName: "trash")
                    })
                } else {
                    // No document--likely failure with loading
                    StitchButton(role: .destructive,
                                 action: {
                        try? FileManager.default.removeItem(at: url)
                    }, label: {
                        Text("Delete")
                        Image(systemName: "trash")
                    })
                }
            }
        #if !targetEnvironment(macCatalyst)
        .modifier(ShareViewModifier(document: document,
        willPresent: $willPresentShareSheet))
        #endif
    }
}

extension View {
    func projectContextMenu(data: StitchDocumentData?,
                            url: URL) -> some View {
        self.modifier(ProjectContextMenuModifer(data: data,
                                                url: url))
    }
}
