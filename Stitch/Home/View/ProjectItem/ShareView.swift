//
//  ShareView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/9/21.
//

import SwiftUI
import StitchSchemaKit

// https://dev.to/hoyelam/share-sheet-uiactivityviewcontroller-within-swiftui-1hh

struct ShareViewModifier: ViewModifier {
    @State private var isProjectLoaded = false
    @State private var sharableURL: URL?
    let document: StitchDocument?
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
            .onChange(of: document) {
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
        if let document = self.document,
           willPresent {
            Task(priority: .high) {
                let newUrl = await StitchDocument.exportDocument(document).file

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
    let document: StitchDocument

    var body: some View {
        // MARK: ShareLink broken on iPad
        #if targetEnvironment(macCatalyst)
        ShareLink(item: document,
                  preview: SharePreview(document.name)) {
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
    func copyExistingProject(_ document: StitchDocument) throws {
        let _ = try document.copyProject() { document in
            document.graph.id = .init()
            document.graph.name += " copy"
        }
    }
}

struct ProjectContextMenuModifer: ViewModifier {
    static let debugModeIcon = "wrench.and.screwdriver"
    
    @Environment(StitchStore.self) private var store
    @State var willPresentShareSheet = false

    let document: StitchDocument?
    let url: URL
    let projectOpenCallback: (StitchDocument, Bool) -> ()

    func body(content: Content) -> some View {
        return content
            .contextMenu {
                if let document = document {
                    StitchDocumentShareButton(willPresentShareSheet: $willPresentShareSheet,
                                              document: document)
                    
                    StitchButton(action: {
                        do {
                            try store.copyExistingProject(document)
                        } catch {
                            store.displayError(error: .projectDuplicationFailed)
                        }
                    }, label: {
                        Text("Duplicate")
                        Image(systemName: "doc.on.doc")
                    })
                    
                    if !StitchDocumentViewModel.isPhoneDevice {
                        StitchButton(action: {
                            // Opens project in debug mode
                            projectOpenCallback(document, true)
                        }, label: {
                            Text("Open in Debug Mode")
                            Image(systemName: Self.debugModeIcon)
                        })
                    }
                    
                    // TODO: follow the full logic in `DeleteProject` to allow for undoing a project deletion, showing 'project recently deleted' modal etc.
                    // -- see `DeleteProject` and `removeStitchProject`
                    StitchButton(role: .destructive,
                                 action: {
                        // log("ProjectContextMenuModifier: will attempt to delete URL: \(projectURL)")
                        dispatch(ProjectDeleted(document: document))
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
    func projectContextMenu(document: StitchDocument?,
                            url: URL,
                            projectOpenCallback: @escaping (StitchDocument, Bool) -> ()) -> some View {
        self.modifier(ProjectContextMenuModifer(document: document,
                                                url: url,
                                                projectOpenCallback: projectOpenCallback))
    }
}
